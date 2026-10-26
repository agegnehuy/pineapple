import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/application_cache.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/domain/tracked_application.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';

import '../../core/localization/app_localization_test.dart' show showFrench;
import '../../support/recording_api.dart';
import 'application_cache_test.dart'
    show MemoryApplicationCacheStorage, cachedApplication, checkedAt;

const offline = ApiException(
  'Could not connect. Check your connection and try again.',
);

Finder get statusButton => find.byWidgetPredicate(
  (widget) =>
      widget is IconButton && widget.tooltip == 'Change application status',
);

class OfflineApplications extends ApplicationsRepository {
  OfflineApplications(super.api);
  Object? failure;
  List<TrackedApplication> items = [];
  Future<List<TrackedApplication>> Function()? load;
  int writes = 0;
  void refresh() => notifyListeners();

  @override
  Future<List<TrackedApplication>> getTrackedApplications() async {
    if (load != null) return load!();
    if (failure != null) throw failure!;
    return List.of(items);
  }

  @override
  Future<void> saveTrackedApplication({
    required String opportunityId,
    String status = 'saved',
  }) async => writes++;

  @override
  Future<void> removeSaved(String id) async => writes++;
}

void main() {
  late RecordingApi api;
  late OfflineApplications repository;
  late MemoryApplicationCacheStorage storage;
  late ApplicationCache cache;
  setUp(() {
    api = RecordingApi();
    repository = OfflineApplications(api);
    storage = MemoryApplicationCacheStorage();
    cache = ApplicationCache(accountId: 'student-1', storage: storage);
  });
  tearDown(() => api.close());

  Widget page({
    ApplicationCache? overrideCache,
    String account = 'student-1',
    OfflineApplications? overrideRepository,
  }) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ApplicationsScreen(
        repository: overrideRepository ?? repository,
        cache: overrideCache ?? cache,
        accountId: account,
      ),
    ),
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final code in [401, 403]) {
    testWidgets(
      'shared cache denial $code invalidates covered and new routes',
      (tester) async {
        await cache.write([cachedApplication()], fetchedAt: checkedAt);
        repository.failure = offline;
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(
          find.text('Connection unavailable. Showing a read-only saved copy.'),
          findsOneWidget,
        );
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final denied = OfflineApplications(api)
          ..failure = ApiException('Access denied', statusCode: code);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ApplicationsScreen(
                  repository: denied,
                  cache: cache,
                  accountId: 'student-1',
                  savedOnly: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cache.allowsOffline, isFalse);
        expect(find.text('Applications unavailable'), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('Applications unavailable'), findsOneWidget);
        expect(
          find.text('Connection unavailable. Showing a read-only saved copy.'),
          findsNothing,
        );
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Applications unavailable'), findsOneWidget);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ApplicationsScreen(
                  repository: repository,
                  cache: cache,
                  accountId: 'student-1',
                  savedOnly: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Applications unavailable'), findsOneWidget);
        expect(find.text('Original opportunity one'), findsNothing);
        navigator.pop();
        await tester.pumpAndSettle();
        repository.failure = null;
        repository.items = [cachedApplication('fresh')];
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(cache.allowsOffline, isTrue);
        await reveal(tester, find.text('Original opportunity fresh'));
        expect(find.text('Original opportunity fresh'), findsOneWidget);
        expect(repository.writes, 0);
      },
    );
  }

  testWidgets('a superseded access denial hides a newer cached result', (
    tester,
  ) async {
    await cache.write([cachedApplication()], fetchedAt: checkedAt);
    final older = Completer<List<TrackedApplication>>();
    repository.load = () => older.future;
    await tester.pumpWidget(page());
    await tester.pump();
    repository.load = () => Future.error(offline);
    repository.refresh();
    await tester.pumpAndSettle();
    expect(
      find.text('Connection unavailable. Showing a read-only saved copy.'),
      findsOneWidget,
    );
    older.completeError(const ApiException('Unauthorized', statusCode: 401));
    await tester.pumpAndSettle();
    expect(cache.allowsOffline, isFalse);
    expect(find.text('Applications unavailable'), findsOneWidget);
    expect(
      find.text('Connection unavailable. Showing a read-only saved copy.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a covered older live response cannot undo a shared denial', (
    tester,
  ) async {
    final pending = Completer<List<TrackedApplication>>();
    repository.load = () => pending.future;
    await tester.pumpWidget(page());
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final denied = OfflineApplications(api)
      ..failure = const ApiException('Unauthorized', statusCode: 401);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: ApplicationsScreen(
              repository: denied,
              cache: cache,
              accountId: 'student-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete([cachedApplication('stale')]);
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(cache.allowsOffline, isFalse);
    expect(find.text('Applications unavailable'), findsOneWidget);
    expect(find.text('Original opportunity stale'), findsNothing);
    expect(storage.values, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'network failure shows dated read-only saved metadata and retry restores live actions',
    (tester) async {
      await cache.write([cachedApplication()], fetchedAt: checkedAt);
      repository.failure = offline;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        find.text('Connection unavailable. Showing a read-only saved copy.'),
        findsOneWidget,
      );
      expect(find.textContaining('2026'), findsOneWidget);
      await reveal(tester, find.text('Original opportunity one'));
      expect(find.text('Saved offline'), findsOneWidget);
      expect(tester.widget<IconButton>(statusButton).onPressed, isNull);
      expect(find.text('Remove from saved'), findsNothing);
      expect(find.text('Open application'), findsNothing);
      expect(repository.writes, 0);
      repository.failure = null;
      repository.items = [cachedApplication('fresh')];
      await reveal(tester, find.text('Try connecting again'));
      await tester.tap(find.text('Try connecting again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connection unavailable. Showing a read-only saved copy.'),
        findsNothing,
      );
      await reveal(tester, find.text('Original opportunity fresh'));
      expect(tester.widget<IconButton>(statusButton).onPressed, isNotNull);
      expect((await cache.read())!.applications.single.id, 'fresh');
      expect((await cache.read())!.fetchedAt.isAfter(checkedAt), isTrue);
    },
  );

  for (final failure in <Object>[
    const ApiException('Unauthorized', statusCode: 401),
    const ApiException('Forbidden', statusCode: 403),
    const ApiException('Service unavailable', statusCode: 503),
    const ApiException('Unrecognized response'),
    const FormatException('Invalid schema'),
  ]) {
    testWidgets('non-network $failure cannot expose the cached list', (
      tester,
    ) async {
      await cache.write([cachedApplication()], fetchedAt: checkedAt);
      storage.operations.clear();
      repository.failure = failure;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Applications unavailable'), findsOneWidget);
      expect(find.text('Original opportunity one'), findsNothing);
      expect(storage.operations, isEmpty);
      if (failure is ApiException &&
          (failure.statusCode == 401 || failure.statusCode == 403)) {
        repository.failure = offline;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Applications unavailable'), findsOneWidget);
        expect(storage.operations, isEmpty);
      }
    });
  }

  testWidgets(
    'cache miss and mismatched account retain an honest retry error',
    (tester) async {
      repository.failure = offline;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Applications unavailable'), findsOneWidget);
      await cache.write([cachedApplication()], fetchedAt: checkedAt);
      await tester.pumpWidget(page(account: 'different-account'));
      await tester.pumpAndSettle();
      expect(find.text('Applications unavailable'), findsOneWidget);
      expect(find.text('Original opportunity one'), findsNothing);
    },
  );

  testWidgets(
    'clear immediately removes an already displayed account snapshot',
    (tester) async {
      await cache.write([cachedApplication()], fetchedAt: checkedAt);
      repository.failure = offline;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Original opportunity one'));
      final clearing = cache.clear();
      expect(cache.isActive, isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Original opportunity one'), findsNothing);
      expect(
        find.text('Your session changed. Please sign in again.'),
        findsOneWidget,
      );
      await clearing;
    },
  );

  testWidgets(
    'callbacks captured before a failed refresh cannot mutate or open stale data',
    (tester) async {
      repository.items = [cachedApplication()];
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await reveal(tester, statusButton);
      final oldStatus = tester.widget<IconButton>(statusButton).onPressed!;
      final open = find.widgetWithText(OutlinedButton, 'Open application');
      await reveal(tester, open);
      final oldOpen = tester.widget<OutlinedButton>(open).onPressed!;
      repository.failure = offline;
      repository.refresh();
      await tester.pumpAndSettle();
      oldStatus();
      oldOpen();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Application workspace'), findsNothing);
      expect(repository.writes, 0);
    },
  );

  testWidgets(
    'an old account response cannot appear or populate a new account cache',
    (tester) async {
      final pending = Completer<List<TrackedApplication>>();
      repository.load = () => pending.future;
      await tester.pumpWidget(page());
      await tester.pump();
      final secondRepository = OfflineApplications(api)
        ..items = [cachedApplication('new-account')];
      final secondCache = ApplicationCache(
        accountId: 'student-2',
        storage: storage,
      );
      await tester.pumpWidget(
        page(
          overrideRepository: secondRepository,
          overrideCache: secondCache,
          account: 'student-2',
        ),
      );
      await tester.pumpAndSettle();
      pending.complete([cachedApplication('old-account')]);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Original opportunity new-account'));
      expect(find.text('Original opportunity old-account'), findsNothing);
      expect(await cache.read(), isNull);
      expect((await secondCache.read())!.applications.single.id, 'new-account');
    },
  );

  testWidgets(
    'a delayed older read cannot replace a newer confirmed empty list',
    (tester) async {
      repository.items = [cachedApplication()];
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final older = Completer<List<TrackedApplication>>();
      final newer = Completer<List<TrackedApplication>>();
      final reads = [older, newer];
      repository.load = () => reads.removeAt(0).future;
      repository.refresh();
      await tester.pump();
      repository.refresh();
      await tester.pump();
      newer.complete([]);
      await tester.pumpAndSettle();
      older.complete([cachedApplication('stale')]);
      await tester.pumpAndSettle();
      expect(find.text('No applications yet'), findsOneWidget);
      expect((await cache.read())!.applications, isEmpty);
    },
  );

  testWidgets(
    'slow secure-storage writes do not delay live data and clear still wins',
    (tester) async {
      storage.pendingWrite = Completer<void>();
      repository.items = [cachedApplication('live')];
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Original opportunity live'));
      expect(find.text('Original opportunity live'), findsOneWidget);
      expect(storage.operations, ['write']);
      final cleared = cache.clear();
      expect(cache.isActive, isFalse);
      storage.pendingWrite!.complete();
      await cleared;
      await tester.pumpAndSettle();
      expect(storage.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stalled platform reads fall back to an honest bounded error', (
    tester,
  ) async {
    await cache.write([cachedApplication()], fetchedAt: checkedAt);
    storage.pendingRead = Completer<void>();
    repository.failure = offline;
    await tester.pumpWidget(page());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Applications unavailable'), findsOneWidget);
    expect(find.text('Original opportunity one'), findsNothing);
    final cleared = cache.clear();
    storage.pendingRead!.complete();
    await cleared;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a status editor opened before a connection failure cannot write stale data',
    (tester) async {
      repository.items = [cachedApplication()];
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await reveal(tester, statusButton);
      await tester.tap(statusButton);
      await tester.pumpAndSettle();
      repository.failure = offline;
      repository.refresh();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('In progress'),
        ),
      );
      await tester.ensureVisible(find.text('Save status'));
      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();
      expect(find.text('Reconnect to update your saved list.'), findsOneWidget);
      expect(repository.writes, 0);
    },
  );

  testWidgets(
    'partial offline copy is explicit and scrollable with French 200% text',
    (tester) async {
      await cache.write(
        List.generate(201, (index) => cachedApplication('$index')),
        fetchedAt: checkedAt,
      );
      repository.failure = offline;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showFrench(
        tester,
        Scaffold(
          body: ApplicationsScreen(
            repository: repository,
            cache: cache,
            accountId: 'student-1',
          ),
        ),
        scale: 2,
      );
      final notice = find.text(
        const AppStrings(
          'fr',
        ).text('Only part of this account’s list is available offline.'),
      );
      await reveal(tester, notice);
      expect(notice, findsOneWidget);
      await reveal(tester, find.text('Original opportunity 0'));
      expect(find.text('Original opportunity 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(repository.writes, 0);
    },
  );
}
