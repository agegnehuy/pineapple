import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';
import 'package:myoccasio/features/academics/domain/study_plan.dart';

StudyPlanTask _task(
  String id,
  int minutes,
  DateTime due, {
  String? title,
  String code = 'BIO',
}) => StudyPlanTask(
  id: id,
  title: title ?? id,
  courseName: 'Écologie',
  courseCode: code,
  category: 'assignment',
  dueDate: due,
  estimatedMinutes: minutes,
);

class _DelayedStorage extends FlutterSecureStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(key: key, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final monday = DateTime(2026, 10, 19);

  test(
    'only actual incomplete upcoming deadlines become tasks with course metadata',
    () {
      final snapshot = AcademicSnapshot.fromJson({
        'courses': [
          {'id': 'bio', 'name': 'Biology', 'code': 'BIO'},
        ],
        'assessments': [
          {'id': 'assessment', 'name': 'No due date'},
        ],
        'deadlines': [
          {
            'id': 'real',
            'title': 'Lab report',
            'dueAt': '2026-10-20T18:00:00Z',
            'courseId': 'bio',
          },
          {
            'id': 'done',
            'title': 'Done',
            'dueAt': '2026-10-21T18:00:00Z',
            'completed': true,
          },
          {'id': 'past', 'title': 'Past', 'dueAt': '2026-10-01T18:00:00Z'},
          {'id': 'bad', 'title': 'Invalid', 'dueAt': 'not a date'},
          {'id': 'blank', 'title': ' ', 'dueAt': '2026-10-21T18:00:00Z'},
          {'id': 'real', 'title': 'Duplicate', 'dueAt': '2026-10-20T18:00:00Z'},
        ],
      });
      final tasks = studyTasksFromSnapshot(
        snapshot,
        StudyPlanPreferences(taskMinutes: {'real': 90}),
        today: monday,
      );
      expect(tasks, hasLength(1));
      expect(tasks.single.displayTitle, 'BIO · Lab report');
      expect(tasks.single.estimatedMinutes, 90);
      expect(
        studyTasksFromSnapshot(
          snapshot,
          StudyPlanPreferences(),
          today: monday,
          courseId: 'other',
        ),
        isEmpty,
      );
    },
  );

  test(
    'date capacities exclude past days and never move work after its due date',
    () {
      final prefs = StudyPlanPreferences(
        availability: {for (var i = 1; i <= 7; i++) i: 60},
      );
      final plan = generateLocalStudyPlan(
        startDate: monday,
        notBefore: DateTime(2026, 10, 21),
        tasks: [_task('due-wednesday', 180, DateTime(2026, 10, 21))],
        preferences: prefs,
      );
      expect(plan.weeks.single.minutes, 60);
      expect(plan.unscheduledMinutes, 120);
      for (final day in plan.weeks.single.days) {
        expect(day.minutes, lessThanOrEqualTo(60));
        if (day.minutes > 0) expect(day.date, DateTime(2026, 10, 21));
      }
    },
  );

  test(
    'an actual deadline that expired earlier today is excluded by current instant',
    () {
      final now = DateTime(2026, 10, 19, 12);
      final snapshot = AcademicSnapshot.fromJson({
        'courses': [],
        'assessments': [],
        'deadlines': [
          {
            'id': 'expired',
            'title': 'Expired today',
            'dueAt': DateTime(2026, 10, 19, 11).toUtc().toIso8601String(),
          },
          {
            'id': 'upcoming',
            'title': 'Later today',
            'dueAt': DateTime(2026, 10, 19, 18).toUtc().toIso8601String(),
          },
        ],
      });
      expect(
        studyTasksFromSnapshot(
          snapshot,
          StudyPlanPreferences(),
          today: now,
        ).map((task) => task.id),
        ['upcoming'],
      );
    },
  );

  test('earlier deadlines take limited capacity before later work', () {
    final urgent = _task('urgent', 60, monday);
    final later = _task('later', 60, DateTime(2026, 10, 20));
    final plan = generateLocalStudyPlan(
      startDate: monday,
      notBefore: monday,
      tasks: [later, urgent],
      preferences: StudyPlanPreferences(availability: {1: 30, 2: 30}),
    );
    expect(plan.weeks.single.days[0].sessions.single.task.id, 'urgent');
    expect(plan.weeks.single.days[1].sessions.single.task.id, 'later');
    expect(plan.weeks.single.minutes, 60);
    expect(plan.unscheduled[urgent], 30);
    expect(plan.unscheduled[later], 30);
  });

  test(
    'rising website urgency allocates exact half-hour work across weeks',
    () {
      final plan = generateLocalStudyPlan(
        startDate: monday,
        notBefore: monday,
        tasks: [_task('exam', 720, DateTime(2026, 11, 8))],
        preferences: StudyPlanPreferences(
          availability: {1: 480, 2: 480, 3: 480, 4: 480, 5: 480},
        ),
      );
      expect(plan.weeks.map((w) => w.minutes), [180, 240, 300]);
      expect(plan.unscheduled, isEmpty);
      expect(
        plan.weeks
            .expand((w) => w.days)
            .expand((d) => d.sessions)
            .every((session) => session.minutes % 30 == 0),
        isTrue,
      );
    },
  );

  test('many small tasks cannot overflow capacity through upward rounding', () {
    final plan = generateLocalStudyPlan(
      startDate: monday,
      notBefore: monday,
      tasks: List.generate(10, (i) => _task('$i', 30, monday)),
      preferences: StudyPlanPreferences(availability: {1: 30}),
    );
    expect(plan.weeks.single.minutes, 30);
    expect(plan.unscheduledMinutes, 270);
  });

  test('no tasks or no availability produces no invented scheduled work', () {
    expect(
      generateLocalStudyPlan(
        startDate: monday,
        notBefore: monday,
        tasks: [],
        preferences: StudyPlanPreferences(),
      ).weeks,
      isEmpty,
    );
    final plan = generateLocalStudyPlan(
      startDate: monday,
      notBefore: monday,
      tasks: [_task('one', 60, monday)],
      preferences: StudyPlanPreferences(),
    );
    expect(plan.weeks.single.minutes, 0);
    expect(plan.unscheduledMinutes, 60);
  });

  test(
    'calendar dates survive daylight-saving boundaries and horizon stays bounded',
    () {
      final start = DateTime(2026, 10, 26);
      final plan = generateLocalStudyPlan(
        startDate: start,
        notBefore: start,
        tasks: [_task('long', 12000, DateTime(2027, 8, 1))],
        preferences: StudyPlanPreferences(availability: {1: 30}),
      );
      expect(plan.weeks, hasLength(24));
      expect(plan.weeks[1].startDate, DateTime(2026, 11, 2));
      expect(plan.weeks.every((w) => w.minutes <= 30), isTrue);
      expect(plan.unscheduledMinutes, greaterThan(0));
    },
  );

  test(
    'invalid availability, duplicate tasks and invalid durations are rejected',
    () {
      for (final prefs in [
        StudyPlanPreferences(availability: {0: 60}),
        StudyPlanPreferences(availability: {1: 481}),
        StudyPlanPreferences(
          availability: {for (var i = 1; i <= 7; i++) i: 480},
        ),
        StudyPlanPreferences(taskMinutes: {'bad': 31}),
      ]) {
        expect(
          () => generateLocalStudyPlan(
            startDate: monday,
            notBefore: monday,
            tasks: [],
            preferences: prefs,
          ),
          throwsArgumentError,
        );
      }
      final task = _task('same', 60, monday);
      expect(
        () => generateLocalStudyPlan(
          startDate: monday,
          notBefore: monday,
          tasks: [task, task],
          preferences: StudyPlanPreferences(),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'CSV preserves Unicode and quoting, neutralizes formulas and discloses unfinished work',
    () {
      final plan = generateLocalStudyPlan(
        startDate: monday,
        notBefore: monday,
        tasks: [
          _task(
            'a',
            120,
            monday,
            title: '=Écrire "résumé",\nnotes',
            code: '@BIO',
          ),
        ],
        preferences: StudyPlanPreferences(availability: {1: 30}),
      );
      final csv = studyPlanCsv(plan);
      expect(csv, contains('"\'@BIO - Écologie"'));
      expect(csv, contains('"\'=Écrire ""résumé"",\nnotes"'));
      expect(csv, contains('"Unscheduled"'));
      expect(csv, contains('"1.5"'));
      final tab = generateLocalStudyPlan(
        startDate: monday,
        notBefore: monday,
        tasks: [_task('tab', 30, monday, title: '\tSUM(A1:A2)')],
        preferences: StudyPlanPreferences(availability: {1: 30}),
      );
      expect(studyPlanCsv(tab), contains('"\'\tSUM(A1:A2)"'));
    },
  );

  group('secure preferences', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));
    test(
      'persists only account-scoped preferences and no course/deadline content',
      () async {
        final store = SecureStudyPlanPreferencesStore();
        await store.write(
          'account/a',
          StudyPlanPreferences(
            availability: {1: 90},
            taskMinutes: {'deadline-id': 120},
          ),
        );
        expect((await store.read('account/a')).availability, {1: 90});
        expect((await store.read('account-b')).availability, isEmpty);
        final saved = await const FlutterSecureStorage().readAll();
        expect(saved.keys.single, contains('account%2Fa'));
        expect(jsonDecode(saved.values.single), {
          'version': 1,
          'availability': {'1': 90},
          'taskMinutes': {'deadline-id': 120},
        });
      },
    );
    test(
      'empty account IDs never fall back to shared anonymous storage',
      () async {
        final store = SecureStudyPlanPreferencesStore();
        await expectLater(store.read(' '), throwsArgumentError);
        await expectLater(
          store.write('', StudyPlanPreferences()),
          throwsArgumentError,
        );
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );
    test(
      'the same account ID on another backend has separate preferences',
      () async {
        final production = SecureStudyPlanPreferencesStore();
        final staging = SecureStudyPlanPreferencesStore(
          namespace: 'https://staging.example.test/base/',
        );
        await production.write(
          'same-id',
          StudyPlanPreferences(availability: {1: 60}),
        );
        expect((await staging.read('same-id')).availability, isEmpty);
        await staging.write(
          'same-id',
          StudyPlanPreferences(availability: {2: 90}),
        );
        await production.clear('same-id');
        expect((await staging.read('same-id')).availability, {2: 90});
      },
    );
    test(
      'corrupt stored preferences are reported and preserved for explicit recovery',
      () async {
        final key = SecureStudyPlanPreferencesStore.keyForAccount('a');
        FlutterSecureStorage.setMockInitialValues({key: '{invalid'});
        await expectLater(
          SecureStudyPlanPreferencesStore().read('a'),
          throwsFormatException,
        );
        expect(await const FlutterSecureStorage().read(key: key), '{invalid');
        expect(
          () => StudyPlanPreferences.fromJson({
            'version': 1,
            'availability': {'1': 61},
            'taskMinutes': {},
          }),
          throwsFormatException,
        );
      },
    );
    test(
      'clear removes only this account and a delayed write cannot recreate it',
      () async {
        final storage = _DelayedStorage();
        final store = SecureStudyPlanPreferencesStore(storage: storage);
        FlutterSecureStorage.setMockInitialValues({
          SecureStudyPlanPreferencesStore.keyForAccount('b'): jsonEncode(
            StudyPlanPreferences(availability: {2: 60}).toJson(),
          ),
        });
        final active = store.write(
          'a',
          StudyPlanPreferences(availability: {1: 60}),
        );
        await storage.started.future;
        final queued = store.write(
          'a',
          StudyPlanPreferences(availability: {1: 90}),
        );
        final queuedFailure = expectLater(queued, throwsStateError);
        final clear = store.clear('a');
        storage.release.complete();
        await active;
        await queuedFailure;
        await clear;
        await expectLater(store.read('a'), throwsStateError);
        expect(
          await const FlutterSecureStorage().read(
            key: SecureStudyPlanPreferencesStore.keyForAccount('a'),
          ),
          isNull,
        );
        expect((await store.read('b')).availability, {2: 60});
      },
    );
    test(
      'an ended session rejects new reads and writes until a fresh store is created',
      () async {
        final store = SecureStudyPlanPreferencesStore();
        await store.write('a', StudyPlanPreferences(availability: {1: 60}));
        await store.clear('a');
        await expectLater(
          store.write('a', StudyPlanPreferences(availability: {1: 90})),
          throwsStateError,
        );
        await expectLater(store.read('a'), throwsStateError);
        final nextSession = SecureStudyPlanPreferencesStore();
        expect((await nextSession.read('a')).availability, isEmpty);
        await nextSession.write(
          'a',
          StudyPlanPreferences(availability: {2: 30}),
        );
        expect((await nextSession.read('a')).availability, {2: 30});
      },
    );
  });
}
