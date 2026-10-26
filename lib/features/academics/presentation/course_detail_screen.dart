import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    required this.repository,
    required this.courseId,
    required this.editCourse,
    super.key,
  });
  final AcademicsRepository repository;
  final String courseId;
  final Future<void> Function(
    BuildContext,
    Future<void> Function(), [
    AcademicCourse?,
  ])
  editCourse;
  Future<void> _assessment(
    BuildContext context,
    Future<void> Function() refresh, [
    Map<String, dynamic>? item,
  ]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: item == null ? 'Add assessment' : 'Edit assessment',
          initial: {
            'name': item?['name']?.toString() ?? '',
            'weightPercent': item?['weightPercent']?.toString() ?? '',
            'scorePercent': item?['scorePercent']?.toString() ?? '',
          },
          fields: [
            const DataField('name', 'Assessment name', required: true),
            DataField(
              'weightPercent',
              'Weight (%)',
              required: true,
              numeric: true,
              validate: (v) => validateNumber(v, min: 0.01, max: 100),
            ),
            DataField(
              'scorePercent',
              'Score (%)',
              numeric: true,
              validate: (v) =>
                  validateNumber(v, min: 0, max: 100, optional: true),
            ),
          ],
          save: (v) => repository.saveAssessment({
            'courseId': courseId,
            'name': v['name'],
            'weightPercent': double.parse(v['weightPercent']!),
            'scorePercent': double.tryParse(v['scorePercent']!),
          }, id: item?['id']?.toString()),
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Course detail')),
    body: AsyncContent<AcademicSnapshot>(
      load: repository.getSnapshot,
      builder: (context, snapshot, refresh) {
        final course = snapshot.courses
            .where((c) => c.id == courseId)
            .firstOrNull;
        if (course == null) {
          return ListView(
            children: const [
              EmptyStateCard(
                icon: Icons.school_outlined,
                title: 'Course unavailable',
                message: 'This course may have been removed.',
              ),
            ],
          );
        }
        final assessments = snapshot.assessments
            .where((a) => a['courseId'] == courseId)
            .toList();
        final estimate = _AssessmentEstimate.from(assessments);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(course.name, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(
              '${course.code} · ${course.term} · ${formatCredits(context, course.credits)}',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Recorded grade',
                    style: TextStyle(
                      color: AppColors.mint,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course.grade == null
                        ? '—'
                        : '${formatDecimal(context, course.grade!, digits: 1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCredits(context, course.credits),
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (course.grade == null)
                    const AppText(
                      'No final grade recorded',
                      style: TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _AssessmentEstimateCard(estimate: estimate),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => editCourse(context, refresh, course),
              child: const AppText('Edit course'),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                AppText(
                  'Assessments',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton.icon(
                  onPressed: () => _assessment(context, refresh),
                  icon: const Icon(Icons.add),
                  label: const AppText('Add assessment'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (assessments.isEmpty)
              const AppText(
                'Add assessments to track the work behind your grade.',
              ),
            for (final assessment in assessments)
              _AssessmentCard(
                assessment: assessment,
                edit: () => _assessment(context, refresh, assessment),
                remove: () async {
                  if (await confirmAction(
                    context,
                    title: 'Delete assessment?',
                    message: 'This removes the assessment from your course.',
                    actionLabel: 'Delete',
                    action: () => repository.deleteAssessment(
                      assessment['id'].toString(),
                    ),
                  )) {
                    await refresh();
                  }
                },
              ),
            const SizedBox(height: 16),
            const AppText('Edit course to update your recorded grade.'),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () async {
                final deleted = await confirmAction(
                  context,
                  title: 'Delete this course?',
                  message:
                      'Its assessments will also be removed. This cannot be undone.',
                  actionLabel: 'Delete course',
                  action: () => repository.deleteCourse(courseId),
                );
                if (deleted && context.mounted) Navigator.pop(context, true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const AppText('Delete course'),
            ),
          ],
        );
      },
    ),
  );
}

double? _percent(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 100
    ? value.toDouble()
    : null;

class _AssessmentEstimate {
  const _AssessmentEstimate(this.percent, this.scoredWeight, this.valid);

  factory _AssessmentEstimate.from(List<Map<String, dynamic>> assessments) {
    var totalWeight = 0.0;
    var scoredWeight = 0.0;
    var weightedScores = 0.0;
    var valid = true;
    for (final assessment in assessments) {
      final weight = _percent(assessment['weightPercent']);
      final score = _percent(assessment['scorePercent']);
      if (weight == null ||
          weight == 0 ||
          (assessment['scorePercent'] != null && score == null)) {
        valid = false;
        continue;
      }
      totalWeight += weight;
      if (score != null) {
        scoredWeight += weight;
        weightedScores += score * weight;
      }
    }
    valid = valid && totalWeight <= 100.000001;
    return _AssessmentEstimate(
      valid && scoredWeight > 0 ? weightedScores / scoredWeight : null,
      scoredWeight,
      valid,
    );
  }

  final double? percent;
  final double scoredWeight;
  final bool valid;
}

class _AssessmentEstimateCard extends StatelessWidget {
  const _AssessmentEstimateCard({required this.estimate});
  final _AssessmentEstimate estimate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Assessment estimate'),
          const SizedBox(height: 8),
          Text(
            estimate.percent == null
                ? '—'
                : '${formatDecimal(context, estimate.percent!, digits: 1)}%',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (estimate.percent != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                const AppText('Scored course weight'),
                Text(
                  '${formatDecimal(context, estimate.scoredWeight, digits: 1)}%',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          AppText(
            !estimate.valid
                ? 'Check assessment weights and scores before using an estimate.'
                : estimate.percent == null
                ? 'Add assessment scores to see an estimate.'
                : 'Weighted average of scored assessments. Pending work is excluded. This does not change your recorded grade.',
          ),
        ],
      ),
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.edit,
    required this.remove,
  });
  final Map<String, dynamic> assessment;
  final VoidCallback edit;
  final VoidCallback remove;

  @override
  Widget build(BuildContext context) {
    final weight = _percent(assessment['weightPercent']);
    final score = _percent(assessment['scorePercent']);
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          assessment['name'].toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        if (weight != null)
          Text(
            '${formatDecimal(context, weight, digits: weight % 1 == 0 ? 0 : 1)}% ${AppStrings.tr(context, 'of course')}',
          ),
      ],
    );
    final result = score == null
        ? const AppText('Pending')
        : Text(
            '${formatDecimal(context, score, digits: score % 1 == 0 ? 0 : 1)}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
    final delete = IconButton(
      tooltip: AppStrings.tr(context, 'Delete assessment'),
      icon: const Icon(Icons.delete_outline),
      onPressed: remove,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: edit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: labels),
                          delete,
                        ],
                      ),
                      const SizedBox(height: 8),
                      result,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: labels),
                      const SizedBox(width: 12),
                      result,
                      delete,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
