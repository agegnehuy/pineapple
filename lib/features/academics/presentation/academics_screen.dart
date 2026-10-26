import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/academics/presentation/gpa_tools_screen.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';
import 'package:myoccasio/features/academics/presentation/course_detail_screen.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';

class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({
    required this.repository,
    this.onStory,
    this.onStudyPlan,
    super.key,
  });
  final AcademicsRepository repository;
  final VoidCallback? onStory;
  final VoidCallback? onStudyPlan;

  Future<void> _course(
    BuildContext context,
    Future<void> Function() refresh, [
    AcademicCourse? course,
  ]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: course == null ? 'Add course' : 'Edit course',
          description: 'Build a picture of your semester.',
          submitLabel: 'Save course',
          initial: {
            'name': course?.name ?? '',
            'code': course?.code ?? '',
            'term': course?.term ?? '',
            'credits': course?.credits.toString() ?? '',
            'gradePercent': course?.grade?.toString() ?? '',
            'status': course?.status ?? 'in_progress',
          },
          fields: [
            const DataField(
              'name',
              'Course name',
              required: true,
              maxLength: 160,
            ),
            const DataField('code', 'Course code'),
            const DataField('term', 'Term'),
            DataField(
              'credits',
              'Credits',
              required: true,
              numeric: true,
              validate: (v) => validateNumber(v, min: 0.01, max: 60),
            ),
            DataField(
              'gradePercent',
              'Grade (%)',
              numeric: true,
              validate: (v) =>
                  validateNumber(v, min: 0, max: 100, optional: true),
            ),
            const DataField(
              'status',
              'Status',
              required: true,
              options: {
                'planned': 'Planned',
                'in_progress': 'In progress',
                'completed': 'Completed',
              },
            ),
          ],
          save: (v) => repository.saveCourse({
            ...v,
            'credits': double.parse(v['credits']!),
            'gradePercent': double.tryParse(v['gradePercent']!),
          }, id: course?.id),
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => AsyncContent<AcademicSnapshot>(
    load: repository.getSnapshot,
    builder: (context, snapshot, refresh) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        AppText(
          'Make your effort count.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        const AppText('Your academic life, in one place.'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'CURRENT GPA',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                snapshot.gpa == null
                    ? '—'
                    : formatDecimal(context, snapshot.gpa!),
                style: const TextStyle(
                  fontSize: 48,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppText(
                '${snapshot.courses.length} courses · Default 4.0 scale',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppText(
          'Your toolkit',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        for (final tool in [
          (
            title: 'Courses & grades',
            subtitle: 'Track your term, one course at a time.',
            icon: Icons.school_outlined,
            page: _CoursesScreen(repository: repository, edit: _course),
          ),
          (
            title: 'GPA calculator',
            subtitle: 'Explore what your next grade changes.',
            icon: Icons.add,
            page: GpaToolsScreen(repository: repository),
          ),
          (
            title: 'GPA converter',
            subtitle: 'Understand a different grading scale.',
            icon: Icons.arrow_forward,
            page: GpaToolsScreen(
              repository: repository,
              initialConverter: true,
            ),
          ),
        ]) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              title: AppText(tool.title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(tool.subtitle),
              ),
              trailing: Icon(
                tool.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => tool.page),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onStudyPlan != null)
              TextButton(
                onPressed: onStudyPlan,
                child: const AppText('Weekly study plan'),
              ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _StudyPlanScreen(repository: repository),
                ),
              ),
              child: const AppText('Study plan & deadlines'),
            ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalsScreen(repository: repository),
                ),
              ),
              child: const AppText('Personal goals'),
            ),
            if (onStory != null)
              TextButton(onPressed: onStory, child: const AppText('My story')),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _course(context, refresh),
          icon: const Icon(Icons.add),
          label: const AppText('Add course'),
        ),
        const SizedBox(height: 80),
      ],
    ),
  );
}

class _CoursesScreen extends StatefulWidget {
  const _CoursesScreen({required this.repository, required this.edit});
  final AcademicsRepository repository;
  final Future<void> Function(
    BuildContext,
    Future<void> Function(), [
    AcademicCourse?,
  ])
  edit;
  @override
  State<_CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<_CoursesScreen> {
  String? _term;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Courses & grades')),
    body: AsyncContent<AcademicSnapshot>(
      load: widget.repository.getSnapshot,
      builder: (context, snapshot, refresh) {
        final terms = snapshot.courses
            .map((course) => course.term)
            .where((term) => term.trim().isNotEmpty)
            .toSet()
            .toList();
        final selectedTerm = terms.contains(_term) ? _term : null;
        final courses = snapshot.courses
            .where(
              (course) => selectedTerm == null || course.term == selectedTerm,
            )
            .toList();
        final graded = courses.where(
          (course) => course.grade != null && course.credits > 0,
        );
        final gradedCredits = graded.fold<double>(
          0,
          (sum, course) => sum + course.credits,
        );
        final gpa = gradedCredits == 0
            ? null
            : graded.fold<double>(
                    0,
                    (sum, course) =>
                        sum + gradeToGpa(course.grade!) * course.credits,
                  ) /
                  gradedCredits;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'Your semester, clearly.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 10),
            Text(
              [
                ?selectedTerm,
                if ((snapshot.degreePlan?['institution']?.toString() ?? '')
                    .isNotEmpty)
                  snapshot.degreePlan!['institution'].toString(),
              ].join(' · '),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const AppText('All terms'),
                  selected: selectedTerm == null,
                  onSelected: (_) => setState(() => _term = null),
                ),
                for (final term in terms)
                  ChoiceChip(
                    label: Text(term),
                    selected: selectedTerm == term,
                    onSelected: (_) => setState(() => _term = term),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20
                    ? 1
                    : 3;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _AcademicMetric(
                        value: courses.length.toString(),
                        label: 'Courses',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _AcademicMetric(
                        value: formatDecimal(
                          context,
                          courses.fold<double>(
                            0,
                            (sum, course) => sum + course.credits,
                          ),
                          digits: 1,
                        ),
                        label: 'Credits',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _AcademicMetric(
                        value: gpa == null ? '—' : formatDecimal(context, gpa),
                        label: selectedTerm == null
                            ? 'Current GPA'
                            : 'Term GPA',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const AppText('Default 4.0 scale'),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                AppText(
                  'My courses',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton.icon(
                  onPressed: () => widget.edit(context, refresh),
                  icon: const Icon(Icons.add),
                  label: const AppText('Add course'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.courses.isEmpty)
              const EmptyStateCard(
                icon: Icons.school_outlined,
                title: 'Your next chapter starts here',
                message: 'Add a course to track your grades and credits.',
              ),
            for (final course in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    title: Text(
                      course.code.isEmpty ? course.name : course.code,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      [
                        if (course.code.isNotEmpty) course.name,
                        course.term,
                        formatCredits(context, course.credits),
                        if (course.grade == null)
                          AppStrings.tr(context, 'Not graded'),
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                    trailing: course.grade == null
                        ? const Icon(Icons.chevron_right)
                        : Text(
                            '${formatDecimal(context, course.grade!, digits: 1)}%',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                    onTap: () async {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(
                            repository: widget.repository,
                            courseId: course.id,
                            editCourse: widget.edit,
                          ),
                        ),
                      );
                      await refresh();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _AcademicMetric extends StatelessWidget {
  const _AcademicMetric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontFamily: 'InstrumentSans',
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AppText(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({required this.repository, super.key});
  final AcademicsRepository repository;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _completed = false;
  AcademicsRepository get repository => widget.repository;
  Future<void> _edit(
    BuildContext context,
    Future<void> Function() refresh, [
    Map<String, dynamic>? goal,
  ]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: goal == null ? 'Set a goal' : 'Edit goal',
          description: 'Make your next step a meaningful one.',
          submitLabel: 'Save goal',
          initial: {
            for (final e in (goal ?? {}).entries)
              e.key.toString(): e.value?.toString() ?? '',
            'targetDate': (goal?['targetDate']?.toString() ?? '')
                .split('T')
                .first,
            'category': goal?['category']?.toString() ?? 'academic',
            'status': goal?['status']?.toString() ?? 'not-started',
            'progress': goal?['progress']?.toString() ?? '0',
          },
          fields: [
            const DataField(
              'title',
              'Goal title',
              required: true,
              maxLength: 120,
            ),
            const DataField(
              'description',
              'Description',
              lines: 3,
              maxLength: 2000,
            ),
            const DataField(
              'category',
              'Category',
              required: true,
              options: {
                'academic': 'Academic',
                'scholarship': 'Scholarship',
                'career': 'Career',
                'personal-development': 'Personal development',
              },
            ),
            const DataField(
              'targetDate',
              'Target date (YYYY-MM-DD)',
              required: true,
              validate: validateCalendarDate,
            ),
            DataField(
              'progress',
              'Progress (%)',
              required: true,
              numeric: true,
              validate: (v) => int.tryParse(v) == null
                  ? 'Enter a whole number.'
                  : validateNumber(v, min: 0, max: 100),
            ),
            const DataField(
              'status',
              'Status',
              required: true,
              options: {
                'not-started': 'Not started',
                'in-progress': 'In progress',
                'completed': 'Completed',
              },
            ),
          ],
          save: (v) => repository.saveGoal({
            ...v,
            'progress': int.parse(v['progress']!),
          }, id: goal?['id']?.toString()),
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Personal goals')),
    body: AsyncContent<List<Map<String, dynamic>>>(
      load: repository.getGoals,
      builder: (context, goals, refresh) {
        final shown = goals
            .where((goal) => (goal['status'] == 'completed') == _completed)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppText(
              'Small steps. Real growth.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            const AppText('Choose a direction. Build your momentum.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const AppText('Active'),
                  selected: !_completed,
                  onSelected: (_) => setState(() => _completed = false),
                ),
                ChoiceChip(
                  label: const AppText('Completed'),
                  selected: _completed,
                  onSelected: (_) => setState(() => _completed = true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (goals.isEmpty)
              const EmptyStateCard(
                icon: Icons.flag_outlined,
                title: 'What’s your next step?',
                message: 'Set a goal and track your progress.',
              ),
            if (goals.isNotEmpty && shown.isEmpty)
              const EmptyStateCard(
                icon: Icons.flag_outlined,
                title: 'Nothing here yet',
                message: 'Goals in this stage will appear here.',
              ),
            for (final goal in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GoalCard(
                  goal: goal,
                  onTap: () => _edit(context, refresh, goal),
                  actions: PopupMenuButton<String>(
                    tooltip: AppStrings.tr(context, 'Goal actions'),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: AppText('Edit')),
                      PopupMenuItem(value: 'delete', child: AppText('Delete')),
                    ],
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _edit(context, refresh, goal);
                      } else if (await confirmAction(
                        context,
                        title: 'Delete goal?',
                        message: 'This goal and its progress will be removed.',
                        actionLabel: 'Delete',
                        action: () =>
                            repository.deleteGoal(goal['id'].toString()),
                      )) {
                        await refresh();
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _edit(context, refresh),
              icon: const Icon(Icons.add),
              label: const AppText('Create a goal'),
            ),
          ],
        );
      },
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.actions,
  });
  final Map<String, dynamic> goal;
  final VoidCallback onTap;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final category =
        const {
          'academic': 'Academic',
          'scholarship': 'Scholarship',
          'career': 'Career',
          'personal-development': 'Personal development',
        }[goal['category']] ??
        'Personal goals';
    final rawProgress = goal['progress'];
    final progress = rawProgress is num && rawProgress.isFinite
        ? rawProgress.toDouble().clamp(0, 100)
        : null;
    // Target dates are calendar days; do not shift them across time zones.
    final date = DateTime.tryParse(
      (goal['targetDate']?.toString() ?? '').split('T').first,
    );
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: AppText(
                          category,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
                  ),
                  actions,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                goal['title']?.toString() ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  if (date == null)
                    const AppText('Target date not set')
                  else ...[
                    const AppText('Target'),
                    Text(formatDisplayDate(context, date)),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (progress == null)
                const AppText('Progress not set')
              else ...[
                LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(6),
                  semanticsLabel:
                      '${goal['title']} · ${AppStrings.tr(context, 'Progress (%)')}',
                ),
                const SizedBox(height: 10),
                Text(
                  '${formatDecimal(context, progress, digits: 0)}% ${AppStrings.tr(context, 'complete')}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyPlanScreen extends StatelessWidget {
  const _StudyPlanScreen({required this.repository});
  final AcademicsRepository repository;
  Future<void> _degree(
    BuildContext context,
    Future<void> Function() refresh,
    Map<String, dynamic>? plan,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: 'Degree plan',
          initial: {
            for (final e in (plan ?? {}).entries)
              e.key.toString(): e.value?.toString() ?? '',
          },
          fields: [
            const DataField('degreeName', 'Degree name', required: true),
            const DataField('institution', 'Institution'),
            DataField(
              'totalCredits',
              'Total credits',
              required: true,
              numeric: true,
              validate: (v) => validateNumber(v, min: 0.01, max: 500),
            ),
            DataField(
              'creditsPerTerm',
              'Credits per term',
              required: true,
              numeric: true,
              validate: (v) => validateNumber(v, min: 0.01, max: 50),
            ),
            DataField(
              'targetGpa',
              'Target GPA (4.0 scale)',
              numeric: true,
              validate: (v) =>
                  validateNumber(v, min: 0, max: 4, optional: true),
            ),
            const DataField('expectedGraduation', 'Expected graduation'),
          ],
          save: (v) => repository.saveDegreePlan({
            ...v,
            'totalCredits': double.parse(v['totalCredits']!),
            'creditsPerTerm': double.parse(v['creditsPerTerm']!),
            'targetGpa': double.tryParse(v['targetGpa']!),
          }),
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  Future<void> _add(
    BuildContext context,
    Future<void> Function() refresh,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: 'Add deadline',
          fields: const [
            DataField('title', 'Title', required: true),
            DataField(
              'dueAt',
              'Due date (YYYY-MM-DD)',
              required: true,
              validate: validateCalendarDate,
            ),
            DataField(
              'category',
              'Category',
              required: true,
              options: {
                'assignment': 'Assignment',
                'exam': 'Exam',
                'application': 'Application',
                'other': 'Other',
              },
            ),
            DataField('notes', 'Notes', lines: 3, maxLength: 2000),
          ],
          initial: const {'category': 'assignment'},
          save: (v) => repository.saveDeadline({
            ...v,
            'dueAt': '${v['dueAt']}T12:00:00Z',
          }),
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Study plan & deadlines')),
    body: AsyncContent<AcademicSnapshot>(
      load: repository.getSnapshot,
      builder: (context, snapshot, refresh) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day + 7);
        final upcoming = snapshot.deadlines.where((deadline) {
          final due = DateTime.tryParse(
            deadline['dueAt']?.toString() ?? '',
          )?.toLocal();
          return deadline['completed'] != true &&
              due != null &&
              !due.isBefore(today) &&
              due.isBefore(end);
        }).length;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppText(
              'Give your week a plan.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            const AppText('Your saved deadlines and degree plan.'),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Next 7 days'),
                    const SizedBox(height: 8),
                    Text(
                      '$upcoming',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const AppText('Upcoming deadlines'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _degree(context, refresh, snapshot.degreePlan),
              icon: const Icon(Icons.school_outlined),
              label: AppText(
                snapshot.degreePlan == null
                    ? 'Set up degree plan'
                    : 'Edit degree plan',
              ),
            ),
            if (snapshot.degreePlan != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '${snapshot.degreePlan!['degreeName']} · ${snapshot.degreePlan!['totalCredits']} ${AppStrings.tr(context, 'Credits planned').toLowerCase()}',
                ),
              ),
            FilledButton.icon(
              onPressed: () => _add(context, refresh),
              icon: const Icon(Icons.add),
              label: const AppText('Add deadline'),
            ),
            const SizedBox(height: 20),
            if (snapshot.deadlines.isEmpty)
              const EmptyStateCard(
                icon: Icons.event_note_outlined,
                title: 'Make room for what matters',
                message: 'Add your next deadline to plan ahead.',
              ),
            for (final deadline in snapshot.deadlines)
              Card(
                child: ListTile(
                  leading: Icon(
                    deadline['completed'] == true
                        ? Icons.check_circle
                        : Icons.event_outlined,
                    color: deadline['completed'] == true
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    deadline['title'].toString(),
                    style: TextStyle(
                      decoration: deadline['completed'] == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${deadline['dueAt'].toString().split('T').first}\n${deadline['notes'] ?? ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: AppStrings.tr(context, 'Deadline actions'),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: AppText(
                          deadline['completed'] == true
                              ? 'Mark incomplete'
                              : 'Mark complete',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: AppText('Delete'),
                      ),
                    ],
                    onSelected: (action) async {
                      final changed = await confirmAction(
                        context,
                        title: action == 'delete'
                            ? 'Delete deadline?'
                            : 'Update deadline?',
                        message: action == 'delete'
                            ? 'This deadline will be removed.'
                            : 'Change this deadline’s completion status?',
                        actionLabel: action == 'delete' ? 'Delete' : 'Update',
                        action: () => action == 'delete'
                            ? repository.deleteDeadline(
                                deadline['id'].toString(),
                              )
                            : repository.updateDeadline(
                                deadline['id'].toString(),
                                {'completed': deadline['completed'] != true},
                              ),
                      );
                      if (changed) await refresh();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
