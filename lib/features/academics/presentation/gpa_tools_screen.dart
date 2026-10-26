import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/async_content.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/core/widgets/data_form_screen.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';
import 'package:myoccasio/features/academics/domain/grading_scale.dart';

class GpaToolsScreen extends StatefulWidget {
  const GpaToolsScreen({
    required this.repository,
    this.initialConverter = false,
    super.key,
  });
  final AcademicsRepository repository;
  final bool initialConverter;
  @override
  State<GpaToolsScreen> createState() => _GpaToolsScreenState();
}

class _GpaToolsScreenState extends State<GpaToolsScreen> {
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _credits = TextEditingController(text: '3');
  final _value = TextEditingController();
  final _courses = <({String name, String grade, double credits})>[];
  String? _scaleId, _fromId, _toId, _error;
  double? _converted;
  bool _converter = false, _saved = false;

  @override
  void initState() {
    super.initState();
    _converter = widget.initialConverter;
    for (final controller in [_name, _grade, _credits, _value]) {
      controller.addListener(_edited);
    }
  }

  void _edited() {
    if (mounted) setState(() => _saved = false);
  }

  @override
  void dispose() {
    for (final controller in [_name, _grade, _credits, _value]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave(bool didPop) async {
    if (didPop) return;
    final discard = await confirmAction(
      context,
      title: 'Discard unsaved changes?',
      message: 'Your calculation has not been saved.',
      actionLabel: 'Discard',
      action: () async {},
    );
    if (discard && mounted) Navigator.pop(context);
  }

  Future<void> _save(GradingScale scale, double gpa, double credits) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataFormScreen(
          title: 'Save calculation',
          description:
              'Saved calculations do not change your courses or profile.',
          initial: {'title': AppStrings.tr(context, 'GPA estimate')},
          fields: const [
            DataField('title', 'Title', required: true, maxLength: 180),
          ],
          save: (values) => widget.repository.saveCalculation({
            'calculationType': 'gpa',
            'title': values['title'],
            'inputs': {
              'gradingScaleId': scale.id,
              'courses': _courses
                  .map(
                    (course) => {
                      'name': course.name,
                      'grade': course.grade,
                      'credits': course.credits,
                    },
                  )
                  .toList(),
            },
            'result': {
              'gpa': gpa,
              'maximumGpa': scale.maximum,
              'totalCredits': credits,
              'summary': 'GPA: ${gpa.toStringAsFixed(2)} / ${scale.maximum}',
            },
          }),
        ),
      ),
    );
    if (changed == true && mounted) setState(() => _saved = true);
  }

  Widget _picker(
    String label,
    List<GradingScale> scales,
    GradingScale selected,
    ValueChanged<String?> change,
    String key,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$key-${selected.id}'),
    initialValue: selected.id,
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: AppStrings.tr(context, label)),
    items: [
      for (final scale in scales)
        DropdownMenuItem(
          value: scale.id,
          child: Text(
            scale.institution.isEmpty
                ? scale.name
                : '${scale.institution} · ${scale.name}',
          ),
        ),
    ],
    onChanged: change,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        _saved ||
        (_courses.isEmpty &&
            _name.text.trim().isEmpty &&
            _grade.text.trim().isEmpty &&
            _value.text.trim().isEmpty &&
            _credits.text == '3'),
    onPopInvokedWithResult: (didPop, _) => _leave(didPop),
    child: Scaffold(
      appBar: AppBar(title: const AppText('GPA calculator & converter')),
      body: AsyncContent<List<GradingScale>>(
        load: widget.repository.getGradingScales,
        builder: (context, scales, refresh) {
          if (scales.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const EmptyStateCard(
                  icon: Icons.school_outlined,
                  title: 'No grading scales available',
                  message: 'Try again when your connection is available.',
                ),
                TextButton(onPressed: refresh, child: const AppText('Retry')),
              ],
            );
          }
          final scale =
              scales.where((s) => s.id == _scaleId).firstOrNull ?? scales.first;
          final from =
              scales.where((s) => s.id == _fromId).firstOrNull ?? scales.first;
          final to =
              scales.where((s) => s.id == _toId).firstOrNull ?? scales.first;
          final percentage = _fromId == null || _fromId == '__percentage__';
          final points = _courses
              .map((course) => scale.pointsFor(course.grade))
              .toList();
          final credits = _courses.fold<double>(
            0,
            (total, course) => total + course.credits,
          );
          final gpa = credits == 0 || points.any((p) => p == null)
              ? null
              : List.generate(
                      points.length,
                      (i) => points[i]! * _courses[i].credits,
                    ).fold<double>(0, (total, p) => total + p) /
                    credits;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppText(
                _converter ? 'A clearer comparison.' : 'See what’s possible.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              AppText(
                _converter
                    ? 'Convert between grading scales.'
                    : 'Explore your next semester.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const AppText('Calculator'),
                    selected: !_converter,
                    onSelected: (_) => setState(() {
                      _converter = false;
                      _error = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const AppText('Converter'),
                    selected: _converter,
                    onSelected: (_) => setState(() {
                      _converter = true;
                      _error = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!_converter) ...[
                _picker(
                  'Grading scale',
                  scales,
                  scale,
                  (value) => setState(() {
                    _scaleId = value;
                    _saved = false;
                    _error = null;
                  }),
                  'calculator',
                ),
                const SizedBox(height: 24),
                AppText(
                  'Course grades',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  maxLength: 160,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(context, 'Course name'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _grade,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(context, 'Grade (% or letter)'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _credits,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(context, 'Course credits'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final error = _name.text.trim().isEmpty
                        ? 'Enter a course name.'
                        : scale.pointsFor(_grade.text) == null
                        ? 'Enter a percentage from 0 to 100 or a letter grade on this scale.'
                        : validateNumber(_credits.text, min: 0.01, max: 60);
                    setState(() {
                      _error = error;
                      if (error != null) return;
                      _courses.add((
                        name: _name.text.trim(),
                        grade: _grade.text.trim(),
                        credits: double.parse(
                          _credits.text.replaceAll(',', '.'),
                        ),
                      ));
                      _name.clear();
                      _grade.clear();
                      _saved = false;
                    });
                  },
                  child: const AppText('Add to calculation'),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < _courses.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(_courses[i].name),
                      subtitle: Text(
                        '${formatCredits(context, _courses[i].credits)} · ${_courses[i].grade}',
                      ),
                      trailing: IconButton(
                        tooltip: AppStrings.tr(
                          context,
                          'Remove course ${i + 1}',
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _courses.removeAt(i);
                          _saved = false;
                        }),
                      ),
                    ),
                  ),
                if (_courses.isNotEmpty && gpa == null)
                  const AppText(
                    'A course grade is unavailable on this scale. Choose another scale or remove that course.',
                  ),
                if (gpa != null) ...[
                  const SizedBox(height: 24),
                  _EstimateCard(
                    label: 'ESTIMATED GPA',
                    value:
                        '${formatDecimal(context, gpa)} / ${formatDecimal(context, scale.maximum)}',
                    detail:
                        '${formatCredits(context, credits)} · ${scale.name}',
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'Estimates only. Confirm the official scale with your institution.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saved ? null : () => _save(scale, gpa, credits),
                    child: AppText(_saved ? 'Saved' : 'Save calculation'),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {
                    _converted = null;
                    _error = null;
                  }),
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(
                      context,
                      percentage ? 'Your grade (%)' : 'Current GPA',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('from-${_fromId ?? '__percentage__'}'),
                  initialValue: percentage ? '__percentage__' : from.id,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(context, 'From scale'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '__percentage__',
                      child: AppText('Percentage · 100-point scale'),
                    ),
                    for (final item in scales)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _fromId = value;
                    _converted = null;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                _picker(
                  'To scale',
                  scales,
                  to,
                  (value) => setState(() {
                    _toId = value;
                    _converted = null;
                    _error = null;
                  }),
                  'to',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(
                      _value.text.replaceAll(',', '.'),
                    );
                    setState(() {
                      if (value == null) {
                        _converted = null;
                      } else if (percentage) {
                        _converted = to.pointsFor(_value.text);
                      } else {
                        _converted = convertGpa(value, from, to);
                      }
                      _error = _converted == null
                          ? percentage
                                ? 'Enter a percentage from 0 to 100.'
                                : 'Enter a GPA within the selected source scale.'
                          : null;
                    });
                  },
                  child: const AppText('Convert grade'),
                ),
                if (_converted != null) ...[
                  const SizedBox(height: 24),
                  _EstimateCard(
                    label: 'ESTIMATED GPA',
                    value:
                        '${formatDecimal(context, _converted!)} / ${formatDecimal(context, to.maximum)}',
                    detail: to.name,
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'Conversions vary by institution. Always confirm the official scale.',
                  ),
                ],
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: AppText(_error!)),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const AppText('Saved calculations'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CalculationHistoryScreen(repository: widget.repository),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    ),
  );
}

class CalculationHistoryScreen extends StatelessWidget {
  const CalculationHistoryScreen({required this.repository, super.key});
  final AcademicsRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const WorkspaceBottomBar(),
    appBar: AppBar(title: const AppText('Saved calculations')),
    body: AsyncContent<AcademicSnapshot>(
      load: repository.getSnapshot,
      builder: (context, snapshot, refresh) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (snapshot.calculations.isEmpty)
            const EmptyStateCard(
              icon: Icons.calculate_outlined,
              title: 'No saved calculations',
              message: 'Save an estimate from the calculator to find it here.',
            ),
          for (final entry in snapshot.calculations)
            Card(
              child: ListTile(
                title: Text(entry['title']?.toString() ?? ''),
                subtitle: Text(
                  (entry['result'] is Map ? entry['result']['summary'] : null)
                          ?.toString() ??
                      '',
                ),
                trailing: IconButton(
                  tooltip: AppStrings.tr(context, 'Delete calculation'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final changed = await confirmAction(
                      context,
                      title: 'Delete calculation?',
                      message:
                          'This removes the saved result from your account.',
                      actionLabel: 'Delete',
                      action: () =>
                          repository.deleteCalculation(entry['id'].toString()),
                    );
                    if (changed) await refresh();
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label, value, detail;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontFamily: 'InstrumentSans',
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
