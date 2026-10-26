import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/domain/deadline_reminder.dart';

Future<bool> showDeadlineReminder(
  BuildContext context, {
  required ReminderSession session,
  required String opportunityId,
  required String title,
  required String deadline,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => DeadlineReminderSheet(
        session: session,
        opportunityId: opportunityId,
        title: title,
        deadline: deadline,
      ),
    ) ??
    false;

class DeadlineReminderSheet extends StatefulWidget {
  const DeadlineReminderSheet({
    required this.session,
    required this.opportunityId,
    required this.title,
    required this.deadline,
    super.key,
  });
  final ReminderSession session;
  final String opportunityId;
  final String title;
  final String deadline;
  @override
  State<DeadlineReminderSheet> createState() => _DeadlineReminderSheetState();
}

class _DeadlineReminderSheetState extends State<DeadlineReminderSheet> {
  int? _days;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = widget.session.items.where(
      (item) => item.opportunityId == widget.opportunityId,
    );
    final available = DeadlineReminder.choices.where(
      (days) =>
          DeadlineReminder.timeFor(
            widget.deadline,
            days,
          )?.isAfter(widget.session.now) ==
          true,
    );
    _days = saved.isNotEmpty && available.contains(saved.first.daysBefore)
        ? saved.first.daysBefore
        : available.contains(3)
        ? 3
        : available.firstOrNull;
  }

  Future<void> _save() async {
    if (_busy || _days == null || !widget.session.active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.save(
        opportunityId: widget.opportunityId,
        title: widget.title,
        deadline: widget.deadline,
        daysBefore: _days!,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is ApiException
              ? error.message
              : 'Could not save your reminder. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final time = _days == null
        ? null
        : DeadlineReminder.timeFor(widget.deadline, _days!);
    return PopScope(
      canPop: !_busy,
      child: AnimatedBuilder(
        animation: widget.session.changes,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      strings.text('A helpful heads-up.'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: strings.text('Close'),
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.title),
              const SizedBox(height: 20),
              Text(
                strings.text('Remind me'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: _days,
                onChanged: (value) {
                  if (!_busy) setState(() => _days = value);
                },
                child: Column(
                  children: [
                    for (final days in DeadlineReminder.choices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: RadioListTile<int>(
                            value: days,
                            enabled:
                                !_busy &&
                                widget.session.active &&
                                DeadlineReminder.timeFor(
                                      widget.deadline,
                                      days,
                                    )?.isAfter(widget.session.now) ==
                                    true,
                            title: Text(
                              strings.text(switch (days) {
                                1 => '1 day before',
                                3 => '3 days before',
                                _ => '1 week before',
                              }),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${strings.text('Reminder time')}: ${formatDisplayDate(context, time, time: true)}',
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    strings.text(
                      'Reminders stay on this device and are cleared when you sign out. For dates without a time, we use 9 AM on this device. Delivery may be delayed by your phone.',
                    ),
                  ),
                ),
              ),
              if (_days == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    strings.text(
                      'No reminder time is available before this deadline.',
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      strings.text(_error!),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ),
              if (!widget.session.active)
                Text(strings.text('Your session changed. Please try again.')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy || _days == null || !widget.session.active
                    ? null
                    : _save,
                child: _busy
                    ? AppBusyIndicator(color: scheme.onPrimary)
                    : Text(strings.text('Save reminder')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
