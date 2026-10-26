import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';
import 'package:myoccasio/features/reminders/domain/deadline_reminder.dart';

class MemoryReminderStorage implements ReminderStorage {
  final values = <String, String>{};
  bool failWrite = false;
  Completer<void>? readGate;
  @override
  Future<String?> read(String key) async {
    await readGate?.future;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class RecordingReminderPlatform implements ReminderPlatform {
  ReminderPermission status = ReminderPermission.allowed;
  ReminderPermission requested = ReminderPermission.allowed;
  final pending = <int, DeadlineReminder>{};
  final events = <String>[];
  Completer<void>? scheduleGate;
  Completer<void>? scheduleStarted;
  bool failSchedule = false;
  bool failCancel = false;
  bool failCancelAll = false;
  @override
  Future<ReminderPermission> permission() async {
    events.add('permission');
    return status;
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    events.add('request');
    return status = requested;
  }

  @override
  Future<void> schedule(
    DeadlineReminder reminder, {
    required bool french,
  }) async {
    events.add('schedule:${reminder.notificationId}:${french ? 'fr' : 'en'}');
    if (scheduleStarted?.isCompleted == false) scheduleStarted!.complete();
    await scheduleGate?.future;
    if (failSchedule) throw StateError('Native schedule unavailable');
    pending[reminder.notificationId] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    events.add('cancel:$id');
    if (failCancel) throw StateError('Native cancel unavailable');
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    events.add('cancelAll');
    if (failCancelAll) throw StateError('Native unavailable');
    pending.clear();
  }

  @override
  Future<void> openSettings() async => events.add('settings');
}

void main() {
  late RecordingReminderPlatform platform;
  late MemoryReminderStorage storage;
  late DeadlineReminders coordinator;
  final now = DateTime(2026, 10, 24, 12);
  setUp(() {
    platform = RecordingReminderPlatform();
    storage = MemoryReminderStorage();
    coordinator = DeadlineReminders(
      platform: platform,
      storage: storage,
      namespace: 'https://myoccasio.ca',
      now: () => now,
    );
  });
  Future<void> save(
    ReminderSession session, {
    String id = 'cat:one',
    int days = 3,
  }) => session.save(
    opportunityId: id,
    title: 'Actual saved opportunity $id',
    deadline: '2026-11-05',
    daysBefore: days,
  );

  test(
    'date-only reminders use 9am calendar days; timestamps keep their instant',
    () {
      expect(
        DeadlineReminder.timeFor('2026-11-05', 3),
        DateTime(2026, 11, 2, 9),
      );
      expect(
        DeadlineReminder.timeFor('2026-11-05T18:30:00Z', 1),
        DateTime.utc(2026, 11, 4, 18, 30),
      );
      expect(DeadlineReminder.timeFor('2026-02-31', 1), isNull);
      expect(DeadlineReminder.timeFor('2026-02-31T18:30:00Z', 1), isNull);
      expect(DeadlineReminder.timeFor('2026-11-05T24:30:00Z', 1), isNull);
      expect(DeadlineReminder.timeFor('2300-11-05', 1), isNull);
      expect(DeadlineReminder.timeFor('2026-11-05T18:30:00', 1), isNull);
      expect(DeadlineReminder.timeFor('No deadline', 3), isNull);
      expect(DeadlineReminder.timeFor('2026-11-05', 2), isNull);
    },
  );

  test(
    'startup does not request permission; explicit save persists the native result',
    () async {
      final session = coordinator.beginSession('student-a');
      await session.initialize();
      expect(platform.events, ['cancelAll', 'permission']);
      await save(session);
      expect(
        session.items.single.scheduledAt,
        DateTime(2026, 11, 2, 9).toUtc(),
      );
      expect(platform.pending.values.single.opportunityId, 'cat:one');
      expect(
        (jsonDecode(storage.values.values.single) as Map)['accountId'],
        'student-a',
      );
      expect(platform.events, isNot(contains('request')));
    },
  );

  test(
    'denied permission preserves preferences without claiming a schedule',
    () async {
      platform.status = ReminderPermission.denied;
      platform.requested = ReminderPermission.denied;
      final session = coordinator.beginSession('student-a');
      await session.initialize();
      final previous = Map.of(storage.values);
      await expectLater(save(session), throwsA(isA<ApiException>()));
      expect(session.items, isEmpty);
      expect(platform.pending, isEmpty);
      expect(storage.values, previous);
      expect(platform.events.where((event) => event == 'request').length, 1);
    },
  );

  test('replacement keeps one native ID and actual selected timing', () async {
    final session = coordinator.beginSession('student-a');
    await save(session);
    final id = session.items.single.notificationId;
    await save(session, days: 1);
    expect(session.items.single.notificationId, id);
    expect(platform.pending.length, 1);
    expect(session.items.single.daysBefore, 1);
    expect(platform.pending[id]!.scheduledAt, DateTime(2026, 11, 4, 9).toUtc());
  });

  test('storage failure cancels an unrecorded new native reminder', () async {
    final session = coordinator.beginSession('student-a');
    await session.initialize();
    storage.failWrite = true;
    await expectLater(save(session), throwsStateError);
    expect(session.items, isEmpty);
    expect(platform.pending, isEmpty);
  });

  test(
    'replacement and removal restore the previous reminder after failed storage',
    () async {
      final session = coordinator.beginSession('student-a');
      await save(session);
      final original = session.items.single;
      storage.failWrite = true;
      await expectLater(save(session, days: 1), throwsStateError);
      expect(platform.pending.values.single.scheduledAt, original.scheduledAt);
      expect(session.ready, isFalse);
      storage.failWrite = false;
      await session.initialize(force: true);
      expect(session.ready, isTrue);
      storage.failWrite = true;
      await expectLater(session.remove('cat:one'), throwsStateError);
      expect(platform.pending.values.single.scheduledAt, original.scheduledAt);
      expect(session.items.single.daysBefore, 3);
    },
  );

  test('native failure does not change persisted or visible records', () async {
    final session = coordinator.beginSession('student-a');
    await session.initialize();
    final original = Map.of(storage.values);
    platform.failSchedule = true;
    await expectLater(save(session), throwsStateError);
    expect(session.items, isEmpty);
    expect(storage.values, original);
  });

  for (final queuedAction in ['save', 'remove']) {
    test(
      'queued $queuedAction cannot bypass required native reconciliation',
      () async {
        final session = coordinator.beginSession('student-a');
        await save(session);
        platform.events.clear();
        platform.scheduleGate = Completer<void>();
        platform.scheduleStarted = Completer<void>();
        platform.failSchedule = true;
        final failing = save(session, id: 'cat:failure');
        final failed = expectLater(failing, throwsStateError);
        await platform.scheduleStarted!.future;
        final queued = queuedAction == 'save'
            ? save(session, id: 'cat:queued')
            : session.remove('cat:one');
        final blocked = expectLater(queued, throwsA(isA<ApiException>()));
        await Future<void>.delayed(Duration.zero);
        platform.scheduleGate!.complete();
        await Future.wait([failed, blocked]);
        expect(session.ready, isFalse);
        expect(
          platform.events
              .where((event) => event.startsWith('schedule:'))
              .length,
          1,
        );
        expect(
          platform.events.where((event) => event.startsWith('cancel:')),
          isEmpty,
        );
        expect(session.items.single.opportunityId, 'cat:one');
        platform.failSchedule = false;
        platform.scheduleGate = null;
        await session.initialize(force: true);
        expect(session.ready, isTrue);
        if (queuedAction == 'save') {
          await save(session, id: 'cat:queued');
          expect(
            session.items.any((item) => item.opportunityId == 'cat:queued'),
            isTrue,
          );
        } else {
          await session.remove('cat:one');
          expect(session.items, isEmpty);
        }
      },
    );
  }

  test(
    'allowing notifications in device settings restores retained schedules',
    () async {
      final session = coordinator.beginSession('student-a');
      await save(session);
      final saved = session.items.single;
      platform.status = ReminderPermission.denied;
      await session.initialize(force: true);
      expect(session.items.single.opportunityId, saved.opportunityId);
      expect(platform.pending, isEmpty);
      platform.events.clear();
      platform.status = ReminderPermission.allowed;
      await session.refreshPermission();
      expect(session.permission, ReminderPermission.allowed);
      expect(session.ready, isTrue);
      expect(platform.pending.values.single.opportunityId, saved.opportunityId);
      expect(platform.pending.values.single.scheduledAt, saved.scheduledAt);
      expect(platform.events, contains('cancelAll'));
      expect(
        platform.events.any((event) => event.startsWith('schedule:')),
        isTrue,
      );
      expect(platform.events, isNot(contains('request')));
    },
  );

  test(
    'account/backend isolation restores only actual matching account preferences',
    () async {
      final first = coordinator.beginSession('student-a');
      await save(first);
      final second = coordinator.beginSession('student-b');
      await second.initialize();
      expect(second.items, isEmpty);
      expect(platform.pending, isEmpty);
      final restored = coordinator.beginSession('student-a');
      await restored.initialize();
      expect(restored.items.single.opportunityId, 'cat:one');
      final otherBackend = DeadlineReminders(
        platform: platform,
        storage: storage,
        namespace: 'https://staging.example.test',
        now: () => now,
      );
      final other = otherBackend.beginSession('student-a');
      await other.initialize();
      expect(other.items, isEmpty);
    },
  );

  test(
    'ended account cannot write and late native completion cannot survive a new account',
    () async {
      final first = coordinator.beginSession('student-a');
      await first.initialize();
      platform.scheduleGate = Completer<void>();
      platform.scheduleStarted = Completer<void>();
      final writing = save(first);
      final assertion = expectLater(writing, throwsA(isA<ApiException>()));
      await platform.scheduleStarted!.future;
      final ending = first.end();
      expect(first.active, isFalse);
      final second = coordinator.beginSession('student-b');
      platform.scheduleGate!.complete();
      await assertion;
      await ending;
      await second.initialize();
      expect(platform.pending, isEmpty);
      expect(second.items, isEmpty);
      expect(
        storage.values.values.any(
          (raw) => (jsonDecode(raw) as Map)['accountId'] == 'student-a',
        ),
        isFalse,
      );
      await expectLater(save(first), throwsA(isA<ApiException>()));
      platform.scheduleGate = null;
      await save(second, id: 'cat:second');
      await first.end();
      expect(platform.pending.values.single.opportunityId, 'cat:second');
    },
  );

  test(
    'sign-out waits behind an in-flight read and cannot restore old reminders',
    () async {
      storage.readGate = Completer<void>();
      final session = coordinator.beginSession('student-a');
      await Future<void>.delayed(Duration.zero);
      final clearing = session.end();
      storage.readGate!.complete();
      await clearing;
      await session.initialize();
      expect(session.items, isEmpty);
      expect(storage.values, isEmpty);
      expect(platform.pending, isEmpty);
    },
  );

  test(
    'corrupt or foreign stored records are rejected and retry recovers honestly',
    () async {
      final session = coordinator.beginSession('student-a');
      await save(session);
      final key = storage.values.keys.single;
      final raw = jsonDecode(storage.values[key]!) as Map<String, dynamic>;
      raw['accountId'] = 'someone-else';
      storage.values[key] = jsonEncode(raw);
      await session.initialize(force: true);
      expect(session.ready, isFalse);
      expect(session.error, isNotNull);
      expect(platform.pending, isEmpty);
      expect(storage.values, isEmpty);
      await session.initialize(force: true);
      expect(session.ready, isTrue);
      expect(session.items, isEmpty);
    },
  );

  test('past reminders and invalid dates never reach the platform', () async {
    final session = coordinator.beginSession('student-a');
    await session.initialize();
    for (final deadline in ['2026-10-24', '2026-02-31', 'No deadline']) {
      await expectLater(
        session.save(
          opportunityId: 'one',
          title: 'One',
          deadline: deadline,
          daysBefore: 1,
        ),
        throwsA(isA<ApiException>()),
      );
    }
    expect(platform.pending, isEmpty);
    expect(session.items, isEmpty);
  });

  test(
    'native initialization failure retains retry instead of a false empty state',
    () async {
      platform.failCancelAll = true;
      final session = coordinator.beginSession('student-a');
      await session.initialize();
      expect(session.ready, isFalse);
      expect(session.error, isNotNull);
      platform.failCancelAll = false;
      await session.initialize(force: true);
      expect(session.ready, isTrue);
      expect(session.error, isNull);
    },
  );

  test(
    'failed native rollback requires reconciliation before further editing',
    () async {
      final session = coordinator.beginSession('student-a');
      await session.initialize();
      storage.failWrite = true;
      platform.failCancel = true;
      await expectLater(save(session), throwsStateError);
      expect(session.ready, isFalse);
      expect(session.error, isNotNull);
      expect(session.items, isEmpty);
      expect(platform.pending, isNotEmpty);
      storage.failWrite = false;
      platform.failCancel = false;
      await session.initialize(force: true);
      expect(session.ready, isTrue);
      expect(platform.pending, isEmpty);
      expect(session.items, isEmpty);
    },
  );

  test(
    'sign-out deletes encrypted records even when native cancellation fails',
    () async {
      final session = coordinator.beginSession('student-a');
      await save(session);
      platform.failCancelAll = true;
      await expectLater(session.end(), throwsStateError);
      expect(session.active, isFalse);
      expect(session.items, isEmpty);
      expect(storage.values, isEmpty);
      platform.failCancelAll = false;
      final next = coordinator.beginSession('student-a');
      await next.initialize();
      expect(platform.pending, isEmpty);
      expect(next.items, isEmpty);
    },
  );

  test(
    'a synchronous account-change listener cannot outrun sign-out cleanup',
    () async {
      final old = coordinator.beginSession('student-a');
      await save(old);
      ReminderSession? next;
      void listener() {
        if (!old.active && next == null) {
          next = coordinator.beginSession('student-a');
        }
      }

      coordinator.addListener(listener);
      await old.end();
      await next!.initialize();
      expect(next!.items, isEmpty);
      await save(next!, id: 'cat:new');
      await old.end();
      expect(next!.items.single.opportunityId, 'cat:new');
      expect(platform.pending.values.single.opportunityId, 'cat:new');
      expect(storage.values.values.single, contains('cat:new'));
      coordinator.removeListener(listener);
    },
  );
}
