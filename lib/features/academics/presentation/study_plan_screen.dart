import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myoccasio/core/files/document_export.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/app_text.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/features/academics/data/academics_repository.dart';
import 'package:myoccasio/features/academics/data/study_plan_preferences_store.dart';
import 'package:myoccasio/features/academics/domain/academic_snapshot.dart';
import 'package:myoccasio/features/academics/domain/study_plan.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({
    required this.repository,
    required this.accountId,
    this.preferencesStore,
    this.export = exportDocument,
    this.now = DateTime.now,
    super.key,
  });
  final AcademicsRepository repository;
  final String accountId;
  final StudyPlanPreferencesStore? preferencesStore;
  final DocumentExporter export;
  final DateTime Function() now;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  late StudyPlanPreferencesStore _store;
  AcademicSnapshot? _snapshot;
  StudyPlanPreferences _preferences = StudyPlanPreferences();
  String _saved = '', _status = '';
  String? _error, _courseId;
  bool _loading = true, _busy = false, _confirming = false;
  int _generation = 0, _weekIndex = 0;
  LocalStudyPlan? _plan;

  bool get _dirty =>
      _snapshot != null && jsonEncode(_preferences.toJson()) != _saved;
  DateTime get _today => studyDate(widget.now());
  DateTime get _start =>
      DateTime(_today.year, _today.month, _today.day - _today.weekday + 1);
  List<StudyPlanTask> get _tasks => _snapshot == null
      ? []
      : studyTasksFromSnapshot(
          _snapshot!,
          _preferences,
          today: widget.now(),
          courseId: _courseId,
        );

  @override
  void initState() {
    super.initState();
    _store = widget.preferencesStore ?? SecureStudyPlanPreferencesStore();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudyPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.repository != widget.repository ||
        oldWidget.preferencesStore != widget.preferencesStore) {
      _generation++;
      _snapshot = null;
      _preferences = StudyPlanPreferences();
      _saved = '';
      _status = '';
      _courseId = null;
      _plan = null;
      _busy = false;
      _confirming = false;
      _store = widget.preferencesStore ?? SecureStudyPlanPreferencesStore();
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Reject anonymous persistence even when a custom store is injected.
      SecureStudyPlanPreferencesStore.keyForAccount(widget.accountId);
      final loaded = await Future.wait<Object>([
        widget.repository.getSnapshot(),
        _store.read(widget.accountId),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _snapshot = loaded[0] as AcademicSnapshot;
        if (_courseId != null &&
            !_snapshot!.courses.any((course) => course.id == _courseId)) {
          _courseId = null;
        }
        _preferences = loaded[1] as StudyPlanPreferences;
        _saved = jsonEncode(_preferences.toJson());
        _regenerate();
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not load your deadlines or saved study preferences. Try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _regenerate() {
    _weekIndex = 0;
    _plan = _preferences.weeklyMinutes == 0
        ? null
        : generateLocalStudyPlan(
            startDate: _start,
            notBefore: _today,
            tasks: _tasks,
            preferences: _preferences,
          );
  }

  Future<void> _leave(bool didPop) async {
    if (didPop || _busy || _confirming || !_dirty) return;
    final generation = _generation;
    _confirming = true;
    final discard = await confirmAction(
      context,
      title: 'Discard unsaved changes?',
      message: 'Your study preferences have not been saved on this device.',
      actionLabel: 'Discard',
      action: () async {},
    );
    _confirming = false;
    if (discard && mounted && generation == _generation) {
      setState(() => _saved = jsonEncode(_preferences.toJson()));
      // PopScope must rebuild with canPop before attempting the confirmed pop.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _refresh() async {
    if (_busy || _confirming) return;
    final generation = _generation;
    if (_dirty) {
      _confirming = true;
      final discard = await confirmAction(
        context,
        title: 'Discard unsaved changes?',
        message: 'Reloading will replace your unsaved study preferences.',
        actionLabel: 'Discard',
        action: () async {},
      );
      _confirming = false;
      if (!discard || !mounted || generation != _generation) return;
    }
    await _load();
  }

  Future<void> _availability() async {
    if (_busy || _confirming) return;
    final generation = _generation;
    final availability = await showDialog<Map<int, int>>(
      context: context,
      builder: (_) => _AvailabilityDialog(initial: _preferences.availability),
    );
    if (availability != null && mounted && generation == _generation) {
      setState(() {
        _preferences = _preferences.copyWith(availability: availability);
        _plan = null;
        _status = '';
        _error = null;
      });
    }
  }

  Future<void> _durations() async {
    if (_busy || _confirming || _tasks.isEmpty) return;
    final generation = _generation;
    final values = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => _DurationDialog(tasks: _tasks),
    );
    if (values != null && mounted && generation == _generation) {
      setState(() {
        _preferences = _preferences.copyWith(
          taskMinutes: {..._preferences.taskMinutes, ...values},
        );
        _plan = null;
        _status = '';
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_busy || _confirming || _tasks.isEmpty) return;
    if (_preferences.weeklyMinutes == 0) {
      setState(
        () => _error = 'Add study availability before building your plan.',
      );
      return;
    }
    final generation = _generation;
    final preferences = _preferences;
    final accountId = widget.accountId;
    setState(() {
      _busy = true;
      _error = null;
      _status = '';
    });
    try {
      await _store.write(accountId, preferences);
      if (!mounted || generation != _generation) return;
      setState(() {
        _saved = jsonEncode(preferences.toJson());
        _regenerate();
        _status = 'Study preferences saved on this device.';
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Could not save your study preferences. Please try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final plan = _plan;
    if (_busy || _confirming || plan == null || plan.weeks.isEmpty) return;
    final generation = _generation;
    final csv = studyPlanCsv(
      plan,
      translate: (text) => AppStrings.tr(context, text),
    );
    setState(() {
      _busy = true;
      _error = null;
      _status = '';
    });
    try {
      final saved = await widget.export(
        'study-plan-${studyIsoDate(plan.weeks.first.startDate)}.csv',
        'text/csv',
        Uint8List.fromList(utf8.encode('\ufeff$csv')),
      );
      if (mounted && generation == _generation && saved) {
        setState(() => _status = 'Study plan exported.');
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not export your study plan. Please try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  String _hours(int minutes) =>
      '${formatDecimal(context, minutes / 60, digits: minutes % 60 == 0 ? 0 : 1)} ${AppStrings.tr(context, minutes == 60 ? 'hour' : 'hours')}';

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final week = plan == null || plan.weeks.isEmpty
        ? null
        : plan.weeks[_weekIndex];
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) => _leave(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('Weekly study plan'),
          actions: [
            IconButton(
              tooltip: AppStrings.tr(context, 'Refresh'),
              onPressed: _busy || _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: const WorkspaceBottomBar(),
        body: _loading
            ? const AppLoadingView()
            : _snapshot == null
            ? AppErrorView(
                title: 'Could not load your study plan',
                message: _error ?? 'Check your connection and try again.',
                onRetry: _load,
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      AppText(
                        'Give your week a plan.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppStrings.tr(context, 'Week of')} ${formatDisplayDate(context, week?.startDate ?? _start)}',
                      ),
                      const SizedBox(height: 12),
                      const AppText(
                        'Availability and time estimates stay on this device. Plans use your current saved deadlines.',
                      ),
                      const SizedBox(height: 20),
                      if (_snapshot!.courses.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey('study-course-$_courseId'),
                          initialValue: _courseId ?? '__all__',
                          isExpanded: true,
                          itemHeight: null,
                          decoration: InputDecoration(
                            labelText: AppStrings.tr(context, 'Course'),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '__all__',
                              child: AppText('All courses'),
                            ),
                            for (final course in _snapshot!.courses)
                              DropdownMenuItem(
                                value: course.id,
                                child: Text(
                                  course.code.isEmpty
                                      ? course.name
                                      : '${course.code} · ${course.name}',
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  _courseId = value == '__all__' ? null : value;
                                  if (!_dirty) {
                                    _regenerate();
                                  } else {
                                    _plan = null;
                                  }
                                }),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              _weekIndex == 0 ? 'THIS WEEK' : 'PLANNED WEEK',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_hours(week?.minutes ?? 0)}, ${AppStrings.tr(context, 'thoughtfully planned.')}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_tasks.isEmpty)
                        const EmptyStateCard(
                          icon: Icons.event_note_outlined,
                          title: 'No upcoming deadlines to plan',
                          message:
                              'Save an upcoming deadline in Study plan & deadlines, then return here. Completed and past-due deadlines are excluded.',
                        ),
                      if (_tasks.isNotEmpty && week == null)
                        const EmptyStateCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Make room for your next step.',
                          message:
                              'Choose your available time, review each estimate, then build your plan.',
                        ),
                      if (plan != null && plan.weeks.length > 1) ...[
                        Row(
                          children: [
                            IconButton(
                              tooltip: AppStrings.tr(context, 'Previous week'),
                              onPressed: _busy || _weekIndex == 0
                                  ? null
                                  : () => setState(() => _weekIndex--),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                '${AppStrings.tr(context, 'Week')} ${_weekIndex + 1} / ${plan.weeks.length}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.tr(context, 'Next week'),
                              onPressed:
                                  _busy || _weekIndex == plan.weeks.length - 1
                                  ? null
                                  : () => setState(() => _weekIndex++),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (week != null &&
                          week.minutes == 0 &&
                          _tasks.isNotEmpty)
                        const AppText(
                          'No sessions fit this week. Review availability, estimates or the next week.',
                        ),
                      if (week != null)
                        for (final day in week.days.where(
                          (day) => day.minutes > 0,
                        )) ...[
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                DateFormat.MMMMEEEEd(
                                  Localizations.localeOf(
                                    context,
                                  ).toLanguageTag(),
                                ).format(day.date),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                _hours(day.minutes),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final session in day.sessions)
                            Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                title: Text(session.task.displayTitle),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${_hours(session.minutes)} · ${AppStrings.tr(context, 'Due date')}: ${formatDisplayDate(context, session.task.dueDate)}',
                                  ),
                                ),
                                trailing: Icon(
                                  session.task.category == 'exam'
                                      ? Icons.school_outlined
                                      : Icons.description_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      if (plan != null && plan.unscheduled.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AppText(
                          'Some work does not fit before its deadline.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const AppText(
                          'Increase availability or review your time estimates. Unscheduled work is not marked complete.',
                        ),
                        const SizedBox(height: 8),
                        for (final entry in plan.unscheduled.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${entry.key.displayTitle} · ${_hours(entry.value)} ${AppStrings.tr(context, 'unscheduled')}',
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _availability,
                            icon: const Icon(Icons.schedule),
                            label: const AppText('Edit availability'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy || _tasks.isEmpty
                                ? null
                                : _durations,
                            icon: const Icon(Icons.edit_outlined),
                            label: const AppText('Time estimates'),
                          ),
                          FilledButton.icon(
                            onPressed: _busy || _tasks.isEmpty ? null : _save,
                            icon: const Icon(Icons.calendar_month),
                            label: AppText(
                              _busy ? 'Please wait…' : 'Save & build plan',
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                _busy || plan == null || plan.weeks.isEmpty
                                ? null
                                : _export,
                            icon: const Icon(Icons.download_outlined),
                            label: const AppText('Export plan'),
                          ),
                        ],
                      ),
                      if (_error != null || _status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: AppText(
                            _error ?? _status,
                            style: TextStyle(
                              color: _error == null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const AppText(
                        'Daily sessions are estimates, not timed appointments. Check the actual deadline time before you study. Plans cover up to 24 weeks.',
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AvailabilityDialog extends StatefulWidget {
  const _AvailabilityDialog({required this.initial});
  final Map<int, int> initial;
  @override
  State<_AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<_AvailabilityDialog> {
  late final _values = {
    for (var day = 1; day <= 7; day++) day: widget.initial[day] ?? 0,
  };
  String? _error;
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const AppText('Edit availability'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppText(
            'Choose up to 8 hours per day and 40 hours per week. Earlier days in the current week are not scheduled.',
          ),
          const SizedBox(height: 16),
          for (var day = 1; day <= 7; day++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<int>(
                key: ValueKey('study-availability-$day'),
                initialValue: _values[day],
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: AppStrings.tr(context, _days[day - 1]),
                ),
                items: [
                  for (var minutes = 0; minutes <= 480; minutes += 30)
                    DropdownMenuItem(
                      value: minutes,
                      child: minutes == 0
                          ? const AppText('Unavailable')
                          : Text(
                              '${formatDecimal(context, minutes / 60, digits: minutes % 60 == 0 ? 0 : 1)} ${AppStrings.tr(context, minutes == 60 ? 'hour' : 'hours')}',
                            ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _values[day] = value!;
                  _error = null;
                }),
              ),
            ),
          if (_error != null)
            Semantics(liveRegion: true, child: AppText(_error!)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_values.values.fold(0, (a, b) => a + b) > 2400) {
            setState(() => _error = 'Choose at most 40 study hours per week.');
            return;
          }
          Navigator.pop(context, _values);
        },
        child: const AppText('Apply'),
      ),
    ],
  );
}

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({required this.tasks});
  final List<StudyPlanTask> tasks;
  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final _values = {
    for (final task in widget.tasks) task.id: '${task.estimatedMinutes / 60}',
  };
  bool _validate = false;
  int? _minutes(String value) {
    final hours = double.tryParse(value.trim().replaceAll(',', '.'));
    if (hours == null ||
        !hours.isFinite ||
        hours < 0.5 ||
        hours > 200 ||
        hours * 2 != (hours * 2).roundToDouble()) {
      return null;
    }
    return (hours * 60).round();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const AppText('Time estimates'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'New tasks start with a 1-hour estimate. Review the total work needed for each deadline in half-hour steps.',
          ),
          const SizedBox(height: 16),
          for (final task in widget.tasks) ...[
            Text(
              task.displayTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${AppStrings.tr(context, 'Due date')}: ${formatDisplayDate(context, task.dueDate)}',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('study-duration-${task.id}'),
              initialValue: _values[task.id],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLength: 8,
              decoration: InputDecoration(
                labelText: AppStrings.tr(context, 'Estimated hours'),
                errorText: _validate && _minutes(_values[task.id]!) == null
                    ? AppStrings.tr(
                        context,
                        'Use 0.5 to 200 hours in half-hour steps.',
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _values[task.id] = value),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_values.values.any((value) => _minutes(value) == null)) {
            setState(() => _validate = true);
            return;
          }
          Navigator.pop(context, {
            for (final entry in _values.entries)
              entry.key: _minutes(entry.value)!,
          });
        },
        child: const AppText('Apply'),
      ),
    ],
  );
}
