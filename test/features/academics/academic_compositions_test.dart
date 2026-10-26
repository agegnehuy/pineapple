import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/presentation/academics_screen.dart';
import 'package:myoccasio/features/academics/presentation/course_detail_screen.dart';
import 'package:myoccasio/features/academics/presentation/gpa_tools_screen.dart';
import '../../support/recording_api.dart';

Map<String, dynamic> _snapshot() => {
  'courses': [
    {
      'id': 'bio',
      'code': 'BIO',
      'name': 'Biology',
      'term': 'Fall 2026',
      'credits': 3,
      'gradePercent': 86,
    },
    {
      'id': 'psy',
      'code': 'PSY',
      'name': 'Psychology',
      'term': 'Fall 2026',
      'credits': 1,
      'gradePercent': 74,
    },
    {
      'id': 'his',
      'code': 'HIS',
      'name': 'History',
      'term': 'Winter 2026',
      'credits': 2,
      'gradePercent': 82,
    },
  ],
  'assessments': [],
  'deadlines': [],
  'degreePlan': {
    'institution': 'Real College',
    'degreeName': 'Science',
    'totalCredits': 120,
  },
};

Future<void> _tap(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late RecordingApi api;
  late AcademicsRepository repository;
  setUp(() {
    api = RecordingApi()..responses['/api/academic'] = _snapshot();
    repository = AcademicsRepository(api);
  });
  tearDown(() => api.close());

  Future<void> open(
    WidgetTester tester, {
    Widget? page,
    bool largeFrench = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(largeFrench ? 'fr' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(largeFrench ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(body: page ?? AcademicsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'semester filters recompute actual course credits and weighted GPA without writes',
    (tester) async {
      await open(tester);
      await _tap(tester, 'Courses & grades');
      expect(find.text('3.73'), findsOneWidget);
      await _tap(tester, 'Fall 2026');
      expect(find.text('3.75'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('Term GPA'), findsOneWidget);
      await _tap(tester, 'Winter 2026');
      expect(find.text('3.70'), findsOneWidget);
      expect(find.text('2.0'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'hub opens the converter directly and exposes a story shortcut callback',
    (tester) async {
      var storyOpened = false;
      await open(
        tester,
        page: AcademicsScreen(
          repository: repository,
          onStory: () => storyOpened = true,
        ),
      );
      await _tap(tester, 'My story');
      expect(storyOpened, isTrue);
      api.responses['/api/grading-scales'] = {'gradingScales': []};
      await _tap(tester, 'GPA converter');
      expect(
        tester
            .widget<GpaToolsScreen>(find.byType(GpaToolsScreen))
            .initialConverter,
        isTrue,
      );
    },
  );

  testWidgets(
    'course details distinguish the weighted assessment estimate from the recorded grade',
    (tester) async {
      api.responses['/api/academic']['assessments'] = [
        {
          'id': 'lab',
          'courseId': 'bio',
          'name': 'Lab reports',
          'weightPercent': 30,
          'scorePercent': 90,
        },
        {
          'id': 'midterm',
          'courseId': 'bio',
          'name': 'Midterm',
          'weightPercent': 20,
          'scorePercent': 70,
        },
        {
          'id': 'exam',
          'courseId': 'bio',
          'name': 'Final exam',
          'weightPercent': 50,
          'scorePercent': null,
        },
        {
          'id': 'other',
          'courseId': 'psy',
          'name': 'Other course',
          'weightPercent': 100,
          'scorePercent': 1,
        },
      ];
      var edited = false;
      await open(
        tester,
        page: CourseDetailScreen(
          repository: repository,
          courseId: 'bio',
          editCourse: (context, refresh, [course]) async =>
              edited = course?.id == 'bio',
        ),
      );
      expect(find.text('86.0%'), findsOneWidget);
      expect(find.text('82.0%'), findsOneWidget);
      expect(find.text('Assessment estimate'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      await _tap(tester, 'Edit course');
      expect(edited, isTrue);
      await tester.scrollUntilVisible(
        find.text('Lab reports'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('30% of course'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Final exam'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('50% of course'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'assessment estimates handle pending and zero scores and reject invalid total weights',
    (tester) async {
      Future<void> show(List<Map<String, dynamic>> assessments) async {
        api.responses['/api/academic']['assessments'] = assessments;
        await open(
          tester,
          page: CourseDetailScreen(
            repository: repository,
            courseId: 'bio',
            editCourse: (_, _, [_]) async {},
          ),
        );
      }

      Map<String, dynamic> assessment(String id, num weight, num? score) => {
        'id': id,
        'courseId': 'bio',
        'name': id,
        'weightPercent': weight,
        'scorePercent': score,
      };

      await show([assessment('Pending work', 100, null)]);
      expect(
        find.text('Add assessment scores to see an estimate.'),
        findsOneWidget,
      );
      expect(find.text('86.0%'), findsOneWidget);

      await show([
        assessment('Scored work', 25, 0),
        assessment('Pending work', 75, null),
      ]);
      expect(find.text('0.0%'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);

      await show([assessment('First', 60, 90), assessment('Second', 50, 80)]);
      expect(
        find.text(
          'Check assessment weights and scores before using an estimate.',
        ),
        findsOneWidget,
      );
      expect(find.text('86.0%'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'saving an assessment refreshes the estimate without writing a recorded course grade',
    (tester) async {
      final assessments = [
        {
          'id': 'lab',
          'courseId': 'bio',
          'name': 'Lab reports',
          'weightPercent': 30,
          'scorePercent': 90,
        },
        {
          'id': 'midterm',
          'courseId': 'bio',
          'name': 'Midterm',
          'weightPercent': 20,
          'scorePercent': 70,
        },
        {
          'id': 'final',
          'courseId': 'bio',
          'name': 'Final exam',
          'weightPercent': 50,
          'scorePercent': null,
        },
      ];
      api.responses['/api/academic']['assessments'] = assessments;
      await open(
        tester,
        page: CourseDetailScreen(
          repository: repository,
          courseId: 'bio',
          editCourse: (_, _, [_]) async {},
        ),
      );
      await _tap(tester, 'Midterm');
      expect(find.byType(DataFormScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '0');
      assessments[1]['scorePercent'] = 0;
      await _tap(tester, 'Save');
      await tester.scrollUntilVisible(
        find.text('Assessment estimate'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('54.0%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recorded grade'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('86.0%'), findsOneWidget);
      final writes = api.calls.where((call) => call.method != 'GET').toList();
      expect(writes.length, 1);
      expect(writes.single.path, '/api/academic/assessments/midterm');
      expect(writes.single.body['scorePercent'], 0);
      expect(writes.single.body.containsKey('gradePercent'), isFalse);
    },
  );

  testWidgets(
    'goals filter uses saved status and retains the real progress and editor',
    (tester) async {
      api.responses['/api/academic/goals'] = {
        'goals': [
          {
            'id': 'one',
            'title': 'Unfinished work',
            'category': 'academic',
            'status': 'in-progress',
            'progress': 70,
            'targetDate': '2026-12-15',
          },
          {
            'id': 'two',
            'title': 'Completed work',
            'category': 'personal-development',
            'status': 'completed',
            'progress': 100,
            'targetDate': '2026-11-01',
          },
        ],
      };
      await open(tester, page: GoalsScreen(repository: repository));
      expect(find.text('Unfinished work'), findsOneWidget);
      expect(find.text('Academic'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Dec 15, 2026'), findsOneWidget);
      expect(find.text('70% complete'), findsOneWidget);
      expect(find.text('Completed work'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.7,
      );
      await _tap(tester, 'Completed');
      expect(find.text('Completed work'), findsOneWidget);
      expect(find.text('Unfinished work'), findsNothing);
      await _tap(tester, 'Completed work');
      expect(find.byType(DataFormScreen), findsOneWidget);
      expect(find.text('Completed work'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets('goal creation stays after the saved goal cards', (tester) async {
    api.responses['/api/academic/goals'] = {
      'goals': [
        {
          'id': 'one',
          'title': 'My real goal',
          'category': 'career',
          'status': 'not-started',
          'progress': 0,
          'targetDate': '2026-12-15T00:00:00Z',
        },
      ],
    };
    await open(tester, page: GoalsScreen(repository: repository));
    expect(find.text('Career'), findsOneWidget);
    expect(find.text('0% complete'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Create a goal')).dy,
      greaterThan(tester.getBottomLeft(find.text('My real goal')).dy),
    );
    await _tap(tester, 'Create a goal');
    expect(find.byType(DataFormScreen), findsOneWidget);
    expect(find.text('My real goal'), findsNothing);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets('missing goal details do not become invented dates or progress', (
    tester,
  ) async {
    api.responses['/api/academic/goals'] = {
      'goals': [
        {
          'id': 'one',
          'title': 'My real goal',
          'category': 'career',
          'status': 'not-started',
        },
      ],
    };
    await open(tester, page: GoalsScreen(repository: repository));
    expect(find.text('Progress not set'), findsOneWidget);
    expect(find.text('Target date not set'), findsOneWidget);
    expect(find.text('0% complete'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets(
    'study overview counts only incomplete deadlines in the next seven days',
    (tester) async {
      final now = DateTime.now();
      String day(int offset) => DateTime(
        now.year,
        now.month,
        now.day + offset,
        12,
      ).toUtc().toIso8601String();
      api.responses['/api/academic']['deadlines'] = [
        {
          'id': 'one',
          'title': 'Upcoming work',
          'dueAt': day(2),
          'completed': false,
        },
        {
          'id': 'two',
          'title': 'Finished work',
          'dueAt': day(1),
          'completed': true,
        },
        {
          'id': 'three',
          'title': 'Later work',
          'dueAt': day(8),
          'completed': false,
        },
      ];
      await open(tester);
      await _tap(tester, 'Study plan & deadlines');
      expect(find.text('Give your week a plan.'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Upcoming deadlines'), findsOneWidget);
      expect(api.calls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'academic hub, courses, goals and details fit a narrow screen with large French text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, largeFrench: true);
      expect(tester.takeException(), isNull);
      await _tap(tester, const AppStrings('fr').text('Courses & grades'));
      await tester.scrollUntilVisible(
        find.text('BIO'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      api.responses['/api/academic']['assessments'] = [
        {
          'id': 'lab',
          'courseId': 'bio',
          'name': 'A long original assessment title that wraps naturally',
          'weightPercent': 30,
          'scorePercent': 90,
        },
        {
          'id': 'exam',
          'courseId': 'bio',
          'name': 'Pending original assessment',
          'weightPercent': 70,
          'scorePercent': null,
        },
      ];
      await open(
        tester,
        page: CourseDetailScreen(
          repository: repository,
          courseId: 'bio',
          editCourse: (_, _, [_]) async {},
        ),
        largeFrench: true,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Pending original assessment'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      api.responses['/api/academic/goals'] = {
        'goals': [
          {
            'id': 'one',
            'title': 'User goal title stays original',
            'category': 'academic',
            'status': 'in-progress',
            'progress': 70,
            'targetDate': '2026-12-15',
          },
        ],
      };
      await open(
        tester,
        page: GoalsScreen(repository: repository),
        largeFrench: true,
      );
      await tester.scrollUntilVisible(
        find.text('User goal title stays original'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, const AppStrings('fr').text('Create a goal'));
      expect(find.byType(DataFormScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
