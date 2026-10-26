import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/applications/data/applications_repository.dart';
import 'package:myoccasio/features/applications/presentation/applications_screen.dart';

import '../../support/recording_api.dart';

void main() {
  late RecordingApi api;
  setUp(() => api = RecordingApi());
  tearDown(() => api.close());

  Map<String, dynamic> record(
    String id, {
    String status = 'saved',
    DateTime? deadline,
  }) => {
    'id': id,
    'opportunityId': 'cat:$id',
    'title': id,
    'org': 'Settings',
    'kindLabel': 'Scholarship',
    'amount': 'CAD 100,000',
    'deadline': deadline?.toIso8601String() ?? '',
    'deadlineLabel': 'Closes November 30, 2026',
    'status': status,
    'match': 96,
  };

  Future<void> open(WidgetTester tester, {bool savedOnly = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ApplicationsScreen(
            repository: ApplicationsRepository(api),
            savedOnly: savedOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saved shortlist only filters real deadlines within seven days', (
    tester,
  ) async {
    api.responses['/api/tracking'] = [
      record(
        'Near deadline',
        deadline: DateTime.now().add(const Duration(days: 3)),
      ),
      record(
        'Later deadline',
        deadline: DateTime.now().add(const Duration(days: 30)),
      ),
      record('Unknown deadline'),
      record(
        'Already drafting',
        status: 'drafting',
        deadline: DateTime.now().add(const Duration(days: 3)),
      ),
    ];
    await open(tester, savedOnly: true);
    expect(find.text('All saved · 3'), findsOneWidget);
    expect(find.text('Near deadline'), findsOneWidget);
    expect(find.text('Later deadline'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Unknown deadline'), 300);
    expect(find.text('Unknown deadline'), findsOneWidget);
    expect(find.text('Already drafting'), findsNothing);
    expect(find.text('Active'), findsNothing);
    await tester.scrollUntilVisible(find.text('Closing soon'), -300);
    await tester.tap(find.text('Closing soon'));
    await tester.pumpAndSettle();
    expect(find.text('Near deadline'), findsOneWidget);
    expect(find.text('Later deadline'), findsNothing);
    expect(find.text('Unknown deadline'), findsNothing);
    expect(find.text('Already drafting'), findsNothing);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tracker summary uses separate saved, drafting and submitted totals',
    (tester) async {
      api.responses['/api/tracking'] = [
        record('Saved first'),
        record('Saved second'),
        record('Draft', status: 'drafting'),
        record('Sent', status: 'submitted'),
      ];
      await open(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('Draft'), 300);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Sent'), findsNothing);
      final submitted = find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Submitted'),
      );
      await tester.scrollUntilVisible(submitted, -300);
      await tester.tap(submitted);
      await tester.pumpAndSettle();
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Draft'), findsNothing);
      expect(find.textContaining('preparation steps'), findsNothing);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets('French status sheet scrolls at 320 pixels and 200% text', (
    tester,
  ) async {
    api.responses['/api/tracking'] = [record('Save\n\nSettings')];
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ApplicationsScreen(repository: ApplicationsRepository(api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    const strings = AppStrings('fr');
    final status = find.byTooltip(strings.text('Change application status'));
    await tester.scrollUntilVisible(status, 300);
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.text('Save\n\nSettings'), findsWidgets);
    final awarded = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(strings.text('Awarded')),
    );
    await tester.ensureVisible(awarded);
    await tester.tap(awarded);
    final save = find.text(strings.text('Save status'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });
}
