import 'dart:math' as math;

import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';

/// Only preferences are stored locally; course names and deadlines come from
/// the current account's academic response whenever the planner is opened.
class StudyPlanPreferences {
  StudyPlanPreferences({
    Map<int, int> availability = const {},
    Map<String, int> taskMinutes = const {},
  }) : availability = Map.unmodifiable(availability),
       taskMinutes = Map.unmodifiable(taskMinutes);

  final Map<int, int> availability;
  final Map<String, int> taskMinutes;
  int get weeklyMinutes => availability.values.fold(0, (a, b) => a + b);

  StudyPlanPreferences copyWith({
    Map<int, int>? availability,
    Map<String, int>? taskMinutes,
  }) => StudyPlanPreferences(
    availability: availability ?? this.availability,
    taskMinutes: taskMinutes ?? this.taskMinutes,
  );

  bool get isValid =>
      availability.length <= 7 &&
      availability.entries.every(
        (entry) =>
            entry.key >= 1 &&
            entry.key <= 7 &&
            entry.value >= 0 &&
            entry.value <= 480 &&
            entry.value % 30 == 0,
      ) &&
      weeklyMinutes <= 2400 &&
      taskMinutes.length <= 1000 &&
      taskMinutes.entries.every(
        (entry) =>
            entry.key.isNotEmpty &&
            entry.key.length <= 256 &&
            entry.value >= 30 &&
            entry.value <= 12000 &&
            entry.value % 30 == 0,
      );

  Map<String, Object> toJson() => {
    'version': 1,
    'availability': {
      for (final entry in availability.entries) '${entry.key}': entry.value,
    },
    'taskMinutes': taskMinutes,
  };

  factory StudyPlanPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['availability'] is! Map ||
        json['taskMinutes'] is! Map) {
      throw const FormatException('Invalid study preferences.');
    }
    final availability = <int, int>{};
    for (final entry in (json['availability'] as Map).entries) {
      final key = int.tryParse(entry.key.toString());
      if (key == null || entry.value is! int) {
        throw const FormatException('Invalid study availability.');
      }
      availability[key] = entry.value as int;
    }
    final durations = <String, int>{};
    for (final entry in (json['taskMinutes'] as Map).entries) {
      if (entry.key is! String || entry.value is! int) {
        throw const FormatException('Invalid study duration.');
      }
      durations[entry.key as String] = entry.value as int;
    }
    final preferences = StudyPlanPreferences(
      availability: availability,
      taskMinutes: durations,
    );
    if (!preferences.isValid) {
      throw const FormatException('Invalid study preferences.');
    }
    return preferences;
  }
}

class StudyPlanTask {
  const StudyPlanTask({
    required this.id,
    required this.title,
    required this.courseName,
    required this.courseCode,
    required this.category,
    required this.dueDate,
    required this.estimatedMinutes,
  });
  final String id, title, courseName, courseCode, category;
  final DateTime dueDate;
  final int estimatedMinutes;
  String get displayTitle =>
      courseCode.isEmpty ? title : '$courseCode · $title';
}

DateTime studyDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String studyIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Assessment rows do not have due dates in the existing backend. Only actual,
/// incomplete personal deadlines can become dated study tasks.
List<StudyPlanTask> studyTasksFromSnapshot(
  AcademicSnapshot snapshot,
  StudyPlanPreferences preferences, {
  required DateTime today,
  String? courseId,
}) {
  final courses = {for (final course in snapshot.courses) course.id: course};
  final ids = <String>{};
  final tasks = <StudyPlanTask>[];
  for (final row in snapshot.deadlines) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString().trim() ?? '';
    final due = DateTime.tryParse(row['dueAt']?.toString() ?? '')?.toLocal();
    if (row['completed'] == true ||
        id.isEmpty ||
        title.isEmpty ||
        due == null ||
        due.isBefore(today) ||
        !ids.add(id) ||
        (courseId != null && row['courseId'] != courseId)) {
      continue;
    }
    final course = courses[row['courseId']];
    tasks.add(
      StudyPlanTask(
        id: id,
        title: title,
        courseName: course?.name ?? '',
        courseCode: course?.code ?? '',
        category: row['category']?.toString() ?? 'other',
        dueDate: studyDate(due),
        estimatedMinutes: preferences.taskMinutes[id] ?? 60,
      ),
    );
  }
  tasks.sort((a, b) {
    final due = a.dueDate.compareTo(b.dueDate);
    return due == 0 ? a.id.compareTo(b.id) : due;
  });
  return List.unmodifiable(tasks);
}

class StudySession {
  const StudySession(this.task, this.minutes);
  final StudyPlanTask task;
  final int minutes;
}

class StudyDay {
  const StudyDay(this.date, this.sessions);
  final DateTime date;
  final List<StudySession> sessions;
  int get minutes => sessions.fold(0, (sum, task) => sum + task.minutes);
}

class StudyWeek {
  const StudyWeek(this.number, this.startDate, this.days);
  final int number;
  final DateTime startDate;
  final List<StudyDay> days;
  int get minutes => days.fold(0, (sum, day) => sum + day.minutes);
}

class LocalStudyPlan {
  const LocalStudyPlan(this.weeks, this.unscheduled);
  final List<StudyWeek> weeks;
  final Map<StudyPlanTask, int> unscheduled;
  int get unscheduledMinutes => unscheduled.values.fold(0, (a, b) => a + b);
}

int _dateDistance(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Adapts lib/study-plan.ts's rising urgency weights and half-hour sessions.
/// Integer capacities preserve the user's limits without the website's upward
/// rounding overflow. Unfinished work stays explicit instead of moving past due.
LocalStudyPlan generateLocalStudyPlan({
  required DateTime startDate,
  required DateTime notBefore,
  required List<StudyPlanTask> tasks,
  required StudyPlanPreferences preferences,
}) {
  if (!preferences.isValid) throw ArgumentError('Invalid study preferences.');
  final start = studyDate(startDate);
  final earliest = studyDate(notBefore);
  final ordered = tasks.toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  if (ordered.isEmpty) return const LocalStudyPlan([], {});
  if (ordered.any(
        (task) =>
            task.estimatedMinutes < 30 ||
            task.estimatedMinutes > 12000 ||
            task.estimatedMinutes % 30 != 0,
      ) ||
      ordered.map((task) => task.id).toSet().length != ordered.length) {
    throw ArgumentError('Invalid study tasks.');
  }
  final latest = ordered
      .map((t) => _dateDistance(start, t.dueDate))
      .reduce(math.max);
  final count = ((latest + 1) / 7).ceil().clamp(1, 24);
  final remaining = {
    for (final task in ordered) task.id: task.estimatedMinutes,
  };
  final weeks = <StudyWeek>[];
  for (var weekIndex = 0; weekIndex < count; weekIndex++) {
    final weekStart = DateTime(
      start.year,
      start.month,
      start.day + weekIndex * 7,
    );
    final dates = List.generate(
      7,
      (day) => DateTime(weekStart.year, weekStart.month, weekStart.day + day),
    );
    final capacity = [
      for (final date in dates)
        date.isBefore(earliest)
            ? 0
            : preferences.availability[date.weekday] ?? 0,
    ];
    final sessions = List.generate(7, (_) => <StudySession>[]);
    for (final task in ordered) {
      final dueWeek = (_dateDistance(start, task.dueDate) / 7).floor().clamp(
        0,
        count - 1,
      );
      if (weekIndex > dueWeek || task.dueDate.isBefore(earliest)) continue;
      final weights = List.generate(
        dueWeek + 1,
        (i) => 0.65 + 0.7 * (i + 1) / (dueWeek + 1),
      );
      final total = weights.fold(0.0, (a, b) => a + b);
      final throughNow = weights.take(weekIndex + 1).fold(0.0, (a, b) => a + b);
      final target = weekIndex == dueWeek
          ? task.estimatedMinutes
          : ((task.estimatedMinutes * throughNow / total) / 30).round() * 30;
      final already = task.estimatedMinutes - remaining[task.id]!;
      var requested = math.max(0, target - already);
      for (var day = 0; day < 7 && requested > 0; day++) {
        if (dates[day].isAfter(task.dueDate)) continue;
        final minutes = math.min(requested, capacity[day]);
        if (minutes == 0) continue;
        sessions[day].add(StudySession(task, minutes));
        capacity[day] -= minutes;
        requested -= minutes;
        remaining[task.id] = remaining[task.id]! - minutes;
      }
    }
    weeks.add(
      StudyWeek(
        weekIndex + 1,
        weekStart,
        List.unmodifiable([
          for (var day = 0; day < 7; day++)
            StudyDay(dates[day], List.unmodifiable(sessions[day])),
        ]),
      ),
    );
  }
  return LocalStudyPlan(
    List.unmodifiable(weeks),
    Map.unmodifiable({
      for (final task in ordered)
        if (remaining[task.id]! > 0) task: remaining[task.id]!,
    }),
  );
}

String studyPlanCsv(LocalStudyPlan plan, {String Function(String)? translate}) {
  String tr(String value) => translate?.call(value) ?? value;
  String escape(String value) {
    // Quoting alone does not stop spreadsheet programs evaluating formulas.
    final guarded = RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(value)
        ? "'$value"
        : value;
    return '"${guarded.replaceAll('"', '""')}"';
  }

  final rows = <List<String>>[
    [
      'Course',
      'Week',
      'Week start',
      'Day',
      'Task',
      'Category',
      'Due date',
      'Hours',
      'Status',
    ].map(tr).toList(),
    for (final week in plan.weeks)
      for (final day in week.days)
        for (final session in day.sessions)
          [
            session.task.courseCode.isEmpty
                ? session.task.courseName
                : '${session.task.courseCode} - ${session.task.courseName}',
            '${week.number}',
            studyIsoDate(week.startDate),
            studyIsoDate(day.date),
            session.task.title,
            session.task.category,
            studyIsoDate(session.task.dueDate),
            '${session.minutes / 60}',
            tr('Planned'),
          ],
    for (final entry in plan.unscheduled.entries)
      [
        entry.key.courseCode.isEmpty
            ? entry.key.courseName
            : '${entry.key.courseCode} - ${entry.key.courseName}',
        '',
        '',
        '',
        entry.key.title,
        entry.key.category,
        studyIsoDate(entry.key.dueDate),
        '${entry.value / 60}',
        tr('Unscheduled'),
      ],
  ];
  return rows.map((row) => row.map(escape).join(',')).join('\r\n');
}
