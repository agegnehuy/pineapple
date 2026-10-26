import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/domain/grading_scale.dart';
import 'package:myoccasio/features/academics/presentation/gpa_tools_screen.dart';
import '../../support/recording_api.dart';

// Contract examples from the website scale response; never production data.
const scaleResponse = {
  'gradingScales': [
    {
      'id': '4',
      'name': '4.0',
      'maximumGpa': 4,
      'bands': [
        {'letterGrade': 'F', 'gradePoints': 0, 'minimumPercentage': 0},
        {'letterGrade': 'A', 'gradePoints': 4, 'minimumPercentage': 85},
        {'letterGrade': 'B', 'gradePoints': 3, 'minimumPercentage': 73},
      ],
    },
    {
      'id': '9',
      'name': 'York 9',
      'maximumGpa': 9,
      'bands': [
        {'letterGrade': 'A+', 'gradePoints': 9, 'minimumPercentage': 90},
        {'letterGrade': 'A', 'gradePoints': 8, 'minimumPercentage': 80},
        {'letterGrade': 'B', 'gradePoints': 6, 'minimumPercentage': 70},
        {'letterGrade': 'F', 'gradePoints': 0, 'minimumPercentage': 0},
      ],
    },
  ],
};

void main() {
  test(
    'percent boundaries, letters and decimal commas follow the selected CMS scale',
    () {
      final scales = GradingScale.parseList(scaleResponse);
      expect(scales[0].pointsFor('84,99'), 3);
      expect(scales[0].pointsFor('85'), 4);
      expect(scales[0].pointsFor(' a '), 4);
      expect(scales[1].pointsFor('85'), 8);
      expect(scales[1].pointsFor('A+'), 9);
      for (final invalid in ['NaN', 'Infinity', '-1', '100.1', 'P', '']) {
        expect(scales[0].pointsFor(invalid), isNull);
      }
    },
  );
  test(
    'malformed or duplicate scales do not become selectable fake defaults',
    () {
      expect(GradingScale.parseList({}), isEmpty);
      final rows = scaleResponse['gradingScales']!;
      final parsed = GradingScale.parseList({
        'gradingScales': [
          null,
          {'id': 'bad', 'name': 'Bad', 'maximumGpa': 'four'},
          {'id': 'empty', 'name': 'Empty', 'maximumGpa': 4, 'bands': []},
          rows.first,
          rows.first,
        ],
      });
      expect(parsed.single.id, '4');
    },
  );
  test(
    'conversion matches website proportions and rejects out-of-range values',
    () {
      final scales = GradingScale.parseList(scaleResponse);
      expect(convertGpa(7.2, scales[1], scales[0]), 3.2);
      expect(convertGpa(4, scales[0], scales[1]), 9);
      expect(convertGpa(4.01, scales[0], scales[1]), isNull);
      expect(convertGpa(double.nan, scales[0], scales[1]), isNull);
    },
  );

  late RecordingApi api;
  late AcademicsRepository repository;
  setUp(() {
    api = RecordingApi()..responses['/api/grading-scales'] = scaleResponse;
    repository = AcademicsRepository(api);
  });
  tearDown(() => api.close());
  Future<void> open(WidgetTester tester, {bool history = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: history
            ? CalculationHistoryScreen(repository: repository)
            : GpaToolsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> course(
    WidgetTester tester,
    String name,
    String grade,
    String credits,
  ) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), name);
    await tester.enterText(find.byType(TextField).at(1), grade);
    await tester.enterText(find.byType(TextField).at(2), credits);
    await tap(tester, 'Add to calculation');
  }

  testWidgets(
    'weighted calculation saves only after explicit review and keeps draft on failure',
    (tester) async {
      await open(tester);
      await course(tester, 'Biology', 'A', '3');
      await course(tester, 'History', 'B', '1,5');
      expect(find.text('3.67 / 4.00'), findsOneWidget);
      expect(api.calls.where((call) => call.method == 'POST'), isEmpty);
      await tap(tester, 'Save calculation');
      api.failure = const ApiException('Save failed');
      await tap(tester, 'Save');
      expect(find.text('GPA estimate'), findsOneWidget);
      expect(find.text('Save failed'), findsWidgets);
      api.failure = null;
      await tap(tester, 'Save');
      final request = api.calls.last;
      expect(request.path, '/api/academic/calculations');
      expect(request.body['calculationType'], 'gpa');
      expect(request.body['inputs']['courses'][1]['credits'], 1.5);
      expect(request.body['result']['gpa'], closeTo(3.666666, 0.00001));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Biology'), findsOneWidget);
    },
  );
  testWidgets('invalid grades cannot enter the calculation or make a request', (
    tester,
  ) async {
    await open(tester);
    await course(tester, 'Biology', 'Infinity', '3');
    expect(
      find.text(
        'Enter a percentage from 0 to 100 or a letter grade on this scale.',
      ),
      findsOneWidget,
    );
    expect(find.text('ESTIMATED GPA'), findsNothing);
    expect(api.calls.where((call) => call.method == 'POST'), isEmpty);
  });
  testWidgets(
    'percentage converter uses live grade bands rather than a proportional guess',
    (tester) async {
      await open(tester);
      await tap(tester, 'Converter');
      await tester.enterText(find.byType(TextField), '86');
      await tap(tester, 'Convert grade');
      expect(find.text('4.00 / 4.00'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '100.1');
      await tap(tester, 'Convert grade');
      expect(find.text('Enter a percentage from 0 to 100.'), findsOneWidget);
      expect(find.text('4.00 / 4.00'), findsNothing);
    },
  );
  testWidgets('converter validates range and recomputes decimal-comma GPA', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Converter');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4.0').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('York 9').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4.1');
    await tap(tester, 'Convert grade');
    expect(
      find.text('Enter a GPA within the selected source scale.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '3,2');
    await tap(tester, 'Convert grade');
    expect(find.text('7.20 / 9.00'), findsOneWidget);
    expect(api.calls.where((call) => call.method == 'POST'), isEmpty);
  });
  testWidgets(
    'history uses actual snapshot and deletion retains retry after failure',
    (tester) async {
      api.responses['/api/academic'] = {
        'courses': [],
        'assessments': [],
        'deadlines': [],
        'degreePlan': null,
        'calculations': [
          {
            'id': 'calc/1',
            'title': 'My estimate',
            'result': {'summary': 'GPA 3.5'},
          },
        ],
      };
      await open(tester, history: true);
      expect(find.text('My estimate'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete calculation'));
      await tester.pumpAndSettle();
      api.failure = const ApiException('Delete failed');
      await tap(tester, 'Delete');
      expect(find.text('Delete failed'), findsOneWidget);
      expect(find.text('My estimate'), findsOneWidget);
      api.failure = null;
      api.responses['/api/academic']['calculations'] = [];
      await tap(tester, 'Delete');
      expect(
        api.calls.any(
          (call) =>
              call.method == 'DELETE' &&
              call.path == '/api/academic/calculations/calc%2F1',
        ),
        isTrue,
      );
      expect(find.text('No saved calculations'), findsOneWidget);
    },
  );
  testWidgets(
    'missing scale data is explicit and can retry without fake estimates',
    (tester) async {
      api.responses['/api/grading-scales'] = {'gradingScales': []};
      await open(tester);
      expect(find.text('No grading scales available'), findsOneWidget);
      expect(find.text('ESTIMATED GPA'), findsNothing);
      api.responses['/api/grading-scales'] = scaleResponse;
      await tap(tester, 'Retry');
      expect(find.text('Grading scale'), findsOneWidget);
    },
  );
  testWidgets(
    'back protects a typed calculation and discard makes no mutation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GpaToolsScreen(repository: repository),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Open');
      await tester.enterText(find.byType(TextField).first, 'Unsaved course');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(find.text('Unsaved course'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Discard');
      expect(find.text('Open'), findsOneWidget);
      expect(api.calls.where((call) => call.method == 'POST'), isEmpty);
    },
  );
  testWidgets(
    'French calculator and converter fit 320 pixels at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: GpaToolsScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, 'Convertisseur');
      await tester.scrollUntilVisible(
        find.text('Convertir la note'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typed converter input is protected when leaving without saving',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Root')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) =>
              GpaToolsScreen(repository: repository, initialConverter: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A clearer comparison.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '86');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(find.text('86'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );
}
