import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/academics/domain/study_plan.dart';
import 'package:myoccasio/features/academics/presentation/study_plan_screen.dart';

import '../../support/recording_api.dart';

class _Store implements StudyPlanPreferencesStore {
  final values = <String, StudyPlanPreferences>{};
  bool failRead = false, failWrite = false;
  Completer<void>? saveWait;
  final writes = <String>[];
  @override
  Future<StudyPlanPreferences> read(String accountId) async {
    if (failRead) throw StateError('Storage unavailable');
    return values[accountId] ?? StudyPlanPreferences();
  }

  @override
  Future<void> write(String accountId, StudyPlanPreferences preferences) async {
    writes.add(accountId);
    if (saveWait != null) await saveWait!.future;
    if (failWrite) throw StateError('Storage unavailable');
    values[accountId] = preferences;
  }

  @override
  Future<void> clear(String accountId) async => values.remove(accountId);
}

Map<String, dynamic> _snapshot({bool empty = false}) => {
  'courses': [
    {'id': 'bio', 'name': 'Biology', 'code': 'BIO', 'credits': 3},
  ],
  'assessments': [],
  'deadlines': empty
      ? []
      : [
          {
            'id': 'lab',
            'courseId': 'bio',
            'title': 'Lab report',
            'category': 'assignment',
            'dueAt': '2026-10-20T18:00:00Z',
            'completed': false,
          },
        ],
};

void main() {
  late RecordingApi api;
  late AcademicsRepository repository;
  late _Store store;
  setUp(() {
    api = RecordingApi()..responses['/api/academic'] = _snapshot();
    repository = AcademicsRepository(api);
    store = _Store();
  });
  tearDown(() => api.close());

  Widget screen({String account = 'account-a', DocumentExporter? exporter}) =>
      StudyPlanScreen(
        repository: repository,
        accountId: account,
        preferencesStore: store,
        export: exporter ?? (_, _, _) async => true,
        now: () => DateTime(2026, 10, 19),
      );
  Future<void> open(WidgetTester tester, {DocumentExporter? exporter}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: screen(exporter: exporter),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseAvailability(WidgetTester tester) async {
    await tap(tester, 'Edit availability');
    await tester.tap(find.byKey(const ValueKey('study-availability-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour').last);
    await tester.pumpAndSettle();
    await tap(tester, 'Apply');
  }

  testWidgets('an empty account shows no invented plan or export', (
    tester,
  ) async {
    api.responses['/api/academic'] = _snapshot(empty: true);
    await open(tester);
    await tap(tester, 'Time estimates');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('No upcoming deadlines to plan'), findsOneWidget);
    expect(store.writes, isEmpty);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Export plan'),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'saved preferences generate actual course/day cards and export CSV',
    (tester) async {
      store.values['account-a'] = StudyPlanPreferences(
        availability: {1: 60, 2: 60},
        taskMinutes: {'lab': 120},
      );
      String? name, mime, csv;
      await open(
        tester,
        exporter: (n, m, bytes) async {
          name = n;
          mime = m;
          csv = utf8.decode(bytes);
          return true;
        },
      );
      await tester.scrollUntilVisible(
        find.text('BIO · Lab report').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('BIO · Lab report'), findsWidgets);
      expect(find.text('Monday, October 19'), findsOneWidget);
      await tap(tester, 'Export plan');
      expect(name, 'study-plan-2026-10-19.csv');
      expect(mime, 'text/csv');
      expect(csv, contains('Lab report'));
      expect(csv, contains('"2026-10-20"'));
      expect(find.text('Study plan exported.'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'availability and explicit estimates save locally and disclose unscheduled work',
    (tester) async {
      await open(tester);
      await chooseAvailability(tester);
      await tap(tester, 'Time estimates');
      await tester.enterText(
        find.byKey(const ValueKey('study-duration-lab')),
        '2.5',
      );
      await tap(tester, 'Apply');
      await tap(tester, 'Save & build plan');
      expect(store.values['account-a']!.taskMinutes, {'lab': 150});
      expect(store.values['account-a']!.availability[1], 60);
      await tester.scrollUntilVisible(
        find.text('Some work does not fit before its deadline.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('BIO · Lab report · 1.5 hours unscheduled'),
        findsOneWidget,
      );
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'half-hour validation rejects invalid or nonfinite time estimates',
    (tester) async {
      await open(tester);
      await tap(tester, 'Time estimates');
      for (final value in ['NaN', 'Infinity', '0', '0.7', '201']) {
        await tester.enterText(
          find.byKey(const ValueKey('study-duration-lab')),
          value,
        );
        await tap(tester, 'Apply');
        expect(
          find.text('Use 0.5 to 200 hours in half-hour steps.'),
          findsOneWidget,
        );
      }
      await tap(tester, 'Cancel');
      expect(store.writes, isEmpty);
    },
  );

  testWidgets('future week navigation uses an honest planned-week heading', (
    tester,
  ) async {
    final response = _snapshot();
    (response['deadlines'] as List).first['dueAt'] = '2026-11-08T18:00:00Z';
    api.responses['/api/academic'] = response;
    store.values['account-a'] = StudyPlanPreferences(
      availability: {1: 120},
      taskMinutes: {'lab': 240},
    );
    await open(tester);
    final next = find.byTooltip('Next week');
    await tester.scrollUntilVisible(
      next,
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PLANNED WEEK'),
      -140,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PLANNED WEEK'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
  });

  testWidgets(
    'refresh resets a course filter when the course has been removed',
    (tester) async {
      store.values['account-a'] = StudyPlanPreferences(availability: {1: 60});
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('study-course-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIO · Biology').last);
      await tester.pumpAndSettle();
      api.responses['/api/academic'] = {
        ..._snapshot(),
        'courses': [
          {'id': 'psy', 'name': 'Psychology', 'code': 'PSY'},
        ],
      };
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('study-course-null')), findsOneWidget);
    },
  );

  testWidgets('storage failure is retryable without claiming a saved plan', (
    tester,
  ) async {
    store.failWrite = true;
    await open(tester);
    await chooseAvailability(tester);
    await tap(tester, 'Save & build plan');
    expect(
      find.text('Could not save your study preferences. Please try again.'),
      findsOneWidget,
    );
    expect(store.values, isEmpty);
    store.failWrite = false;
    await tap(tester, 'Save & build plan');
    expect(store.values['account-a'], isNotNull);
    expect(
      find.text('Study preferences saved on this device.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'unsaved preferences require discard and cancellation keeps edits',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Root')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => screen()),
      );
      await tester.pumpAndSettle();
      await chooseAvailability(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(find.byType(StudyPlanScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Discard');
      expect(find.text('Root'), findsOneWidget);
      expect(store.writes, isEmpty);
    },
  );

  testWidgets(
    'load failures have retry and recovered data uses current account',
    (tester) async {
      api.failure = const ApiException('Offline');
      await open(tester);
      expect(find.text('Offline'), findsOneWidget);
      api.failure = null;
      await tap(tester, 'Try again');
      expect(find.text('Give your week a plan.'), findsOneWidget);
      store.values['account-a'] = StudyPlanPreferences(availability: {1: 60});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: screen(account: 'account-b'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Make room for your next step.'), findsOneWidget);
      expect(find.text('BIO · Lab report'), findsNothing);
    },
  );

  testWidgets(
    'saving blocks navigation and double save until storage finishes',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      store.values['account-a'] = StudyPlanPreferences(availability: {1: 60});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Root')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => screen()),
      );
      await tester.pumpAndSettle();
      store.saveWait = Completer<void>();
      await tap(tester, 'Save & build plan');
      await tester.pageBack();
      await tester.pump();
      expect(find.byType(StudyPlanScreen), findsOneWidget);
      expect(store.writes, ['account-a']);
      store.saveWait!.complete();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Root'), findsOneWidget);
    },
  );

  testWidgets('export cancellation is quiet and failure can be retried', (
    tester,
  ) async {
    store.values['account-a'] = StudyPlanPreferences(availability: {1: 60});
    var attempts = 0;
    await open(
      tester,
      exporter: (_, _, _) async {
        attempts++;
        if (attempts == 2) throw const ApiException('Export failed');
        return attempts > 2;
      },
    );
    await tap(tester, 'Export plan');
    expect(find.text('Study plan exported.'), findsNothing);
    await tap(tester, 'Export plan');
    expect(find.text('Export failed'), findsOneWidget);
    await tap(tester, 'Export plan');
    expect(find.text('Study plan exported.'), findsOneWidget);
  });

  testWidgets(
    '320-pixel French layout supports doubled text and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.values['account-a'] = StudyPlanPreferences(
        availability: {1: 60},
        taskMinutes: {'lab': 120},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: screen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final editLabel = const AppStrings('fr').text('Edit availability');
      await tap(tester, editLabel);
      expect(tester.takeException(), isNull);
      await tap(tester, const AppStrings('fr').text('Cancel'));
      await tap(tester, const AppStrings('fr').text('Time estimates'));
      expect(tester.takeException(), isNull);
      await tap(tester, const AppStrings('fr').text('Cancel'));
    },
  );
}
