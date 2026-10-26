import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';

final checkedAt = DateTime.utc(2026, 10, 22, 12, 30);

TrackedApplication cachedApplication([String id = 'one']) => TrackedApplication(
  id: id,
  opportunityId: 'cat:$id',
  title: 'Original opportunity $id',
  organization: 'Original provider',
  amount: r'$5,000',
  deadlineLabel: 'November 1',
  status: 'saved',
  match: 85,
  kindLabel: 'Scholarship',
  deadline: '2026-11-01',
);

class MemoryApplicationCacheStorage implements ApplicationCacheStorage {
  final values = <String, String>{};
  final operations = <String>[];
  Completer<void>? pendingWrite;
  Completer<void>? pendingRead;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async {
    operations.add('read');
    await pendingRead?.future;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    operations.add('write');
    await pendingWrite?.future;
    if (failWrite) throw StateError('Storage write unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    operations.add('delete');
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryApplicationCacheStorage storage;
  ApplicationCache cache({
    String account = 'student-1',
    String namespace = 'https://myoccasio.ca',
  }) => ApplicationCache(
    accountId: account,
    namespace: namespace,
    storage: storage,
    now: () => checkedAt,
  );

  setUp(() => storage = MemoryApplicationCacheStorage());

  test(
    'access denial blocks queued reads and older authorization results',
    () async {
      final subject = cache();
      await subject.write([cachedApplication()], fetchedAt: checkedAt);
      final oldEpoch = subject.accessEpoch;
      storage.pendingRead = Completer<void>();
      final pending = subject.read();
      await Future<void>.delayed(Duration.zero);
      subject.denyAccess();
      expect(subject.allowsOffline, isFalse);
      expect(subject.confirmAccess(oldEpoch), isFalse);
      storage.pendingRead!.complete();
      expect(await pending, isNull);
      expect(await subject.read(), isNull);
      expect(subject.confirmAccess(subject.accessEpoch), isTrue);
      expect((await subject.read())!.applications.single.id, 'one');
    },
  );

  test(
    'denial suppresses queued writes even after fresh authorization',
    () async {
      final subject = cache();
      storage.pendingWrite = Completer<void>();
      final running = subject.write([cachedApplication('first')]);
      await Future<void>.delayed(Duration.zero);
      final queued = subject.write([cachedApplication('stale')]);
      subject.denyAccess();
      expect(subject.confirmAccess(subject.accessEpoch), isTrue);
      storage.pendingWrite!.complete();
      await Future.wait([running, queued]);
      expect((await subject.read())!.applications.single.id, 'first');
    },
  );

  test(
    'production default persists through the platform secure-storage boundary',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      await ApplicationCache(
        accountId: 'secure-student',
        now: () => checkedAt,
      ).write([cachedApplication()], fetchedAt: checkedAt);
      final persisted = await ApplicationCache(
        accountId: 'secure-student',
        now: () => checkedAt,
      ).read();
      expect(persisted!.applications.single.id, 'one');
      await ApplicationCache(
        accountId: 'secure-student',
        now: () => checkedAt,
      ).clear();
      expect(
        await ApplicationCache(
          accountId: 'secure-student',
          now: () => checkedAt,
        ).read(),
        isNull,
      );
    },
  );

  test(
    'confirmed metadata persists across account-session cache instances',
    () async {
      await cache().write([cachedApplication()], fetchedAt: checkedAt);
      final snapshot = await cache().read();
      expect(snapshot!.fetchedAt, checkedAt);
      expect(snapshot.complete, isTrue);
      expect(snapshot.applications.single.title, 'Original opportunity one');
      expect(snapshot.applications.single.amount, r'$5,000');
      final payload =
          jsonDecode(storage.values.values.single) as Map<String, dynamic>;
      expect(payload.keys.toSet(), {
        'version',
        'accountId',
        'namespace',
        'fetchedAt',
        'complete',
        'applications',
      });
      expect((payload['applications'] as List).single.keys.toSet(), {
        'id',
        'opportunityId',
        'title',
        'org',
        'amount',
        'deadlineLabel',
        'status',
        'match',
        'kindLabel',
        'deadline',
      });
      expect(await cache(account: 'student-2').read(), isNull);
      expect(
        await cache(namespace: 'https://staging.myoccasio.ca').read(),
        isNull,
      );
      expect(
        (await cache(
          namespace: 'https://myoccasio.ca/',
        ).read())!.applications.length,
        1,
      );
    },
  );

  test(
    'corrupt, foreign, future and invalid schema payloads are removed',
    () async {
      await cache().write([cachedApplication()]);
      final key = storage.values.keys.single;
      final valid = storage.values[key]!;
      final variants = <String>[
        '{broken json',
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'accountId': 'another-account',
        }),
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'namespace': 'https://other.test',
        }),
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'version': 999,
        }),
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'privateDocument': 'must not be accepted',
        }),
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'fetchedAt': checkedAt.add(const Duration(days: 1)).toIso8601String(),
        }),
        jsonEncode({
          ...jsonDecode(valid) as Map<String, dynamic>,
          'applications': [
            {'id': 'incomplete'},
          ],
        }),
        List.filled(ApplicationCache.maxBytes + 1, 'x').join(),
      ];
      for (final value in variants) {
        storage.values[key] = value;
        expect(await cache().read(), isNull);
        expect(storage.values.containsKey(key), isFalse);
      }
    },
  );

  test(
    'record and byte caps mark a partial snapshot without oversized storage',
    () async {
      final service = cache();
      await service.write(
        List.generate(250, (index) => cachedApplication('$index')),
      );
      final snapshot = await service.read();
      expect(snapshot!.applications.length, ApplicationCache.maxEntries);
      expect(snapshot.complete, isFalse);
      expect(
        utf8.encode(storage.values.values.single).length,
        lessThanOrEqualTo(ApplicationCache.maxBytes),
      );
    },
  );

  test(
    'a confirmed empty response replaces the previous nonempty snapshot',
    () async {
      final service = cache();
      await service.write([cachedApplication()]);
      await service.write([]);
      expect((await cache().read())!.applications, isEmpty);
      // Old copies remain explicitly dated and read-only until sign-out clears them.
      await service.write([
        cachedApplication(),
      ], fetchedAt: DateTime.utc(2025, 1, 1));
      expect((await service.read())!.fetchedAt, DateTime.utc(2025, 1, 1));
    },
  );

  test(
    'clear deactivates immediately and deletes after late or queued writes',
    () async {
      final service = cache();
      storage.pendingWrite = Completer<void>();
      final first = service.write([cachedApplication('first')]);
      await Future<void>.delayed(Duration.zero);
      final queued = service.write([cachedApplication('queued')]);
      final cleared = service.clear();
      expect(service.isActive, isFalse);
      expect(await service.read(), isNull);
      await service.write([cachedApplication('after-clear')]);
      storage.pendingWrite!.complete();
      await Future.wait([first, queued, cleared]);
      expect(storage.operations, ['write', 'delete']);
      expect(storage.values, isEmpty);
    },
  );

  test('a failed write cannot prevent queued deletion', () async {
    final service = cache();
    storage.pendingWrite = Completer<void>();
    storage.failWrite = true;
    final first = service.write([cachedApplication()]);
    final failure = expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final cleared = service.clear();
    storage.pendingWrite!.complete();
    await failure;
    await cleared;
    expect(storage.operations.last, 'delete');
    expect(storage.values, isEmpty);
  });

  test(
    'clear suppresses an in-flight read and preserves a different account',
    () async {
      final first = cache();
      await first.write([cachedApplication()]);
      final other = cache(account: 'student-2');
      await other.write([cachedApplication('other')]);
      storage.pendingRead = Completer<void>();
      final reading = first.read();
      await Future<void>.delayed(Duration.zero);
      final cleared = first.clear();
      storage.pendingRead!.complete();
      expect(await reading, isNull);
      await cleared;
      expect((await other.read())!.applications.single.id, 'other');
    },
  );
}
