import 'package:flutter/material.dart';
import 'package:myoccasio/core/localization/app_strings.dart';
import 'package:myoccasio/core/localization/formatters.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';
import 'package:myoccasio/core/widgets/confirm_action.dart';
import 'package:myoccasio/features/navigation/presentation/workspace_navigation.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';
import 'package:myoccasio/features/reminders/presentation/deadline_reminder_sheet.dart';

class DeviceRemindersScreen extends StatefulWidget {
  const DeviceRemindersScreen({required this.session, super.key});
  final ReminderSession session;
  @override
  State<DeviceRemindersScreen> createState() => _DeviceRemindersScreenState();
}

class _DeviceRemindersScreenState extends State<DeviceRemindersScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _settings() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.openSettings();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not open device settings. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(strings.text('Device reminders'))),
        bottomNavigationBar: WorkspaceBottomBar(enabled: !_busy),
        body: AnimatedBuilder(
          animation: widget.session.changes,
          builder: (context, _) {
            if (!widget.session.active) {
              return Center(
                child: Text(
                  strings.text('Your session changed. Please try again.'),
                ),
              );
            }
            if (widget.session.error != null) {
              return AppErrorView(
                title: 'Device reminders unavailable',
                message: widget.session.error!,
                onRetry: () => widget.session.initialize(force: true),
              );
            }
            if (!widget.session.ready) return const AppLoadingView();
            final items = widget.session.items
                .where((item) => item.scheduledAt.isAfter(widget.session.now))
                .toList();
            final allowed =
                widget.session.permission == ReminderPermission.allowed;
            return RefreshIndicator(
              onRefresh: () => widget.session.initialize(force: true),
              child: ListView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    strings.text('A little nudge, on your terms.'),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.text(
                      'These reminders are saved on this device. Website email preferences are separate.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.text(
                              allowed
                                  ? 'Notifications allowed on this device'
                                  : 'Notifications are off on this device',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (!allowed) ...[
                            const SizedBox(height: 8),
                            Text(
                              strings.text(
                                'Allow notifications in device settings to receive your reminders.',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _settings,
                            icon: const Icon(Icons.settings_outlined),
                            label: Text(strings.text('Open device settings')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          strings.text(_error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.notifications_none, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              strings.text('No device reminders yet'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.text(
                                'Open an opportunity and choose Remind me to set a reminder for its real deadline.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatDisplayDate(
                                  context,
                                  item.scheduledAt,
                                  time: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            setState(() => _busy = true);
                                            try {
                                              await showDeadlineReminder(
                                                context,
                                                session: widget.session,
                                                opportunityId:
                                                    item.opportunityId,
                                                title: item.title,
                                                deadline: item.deadline,
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() => _busy = false);
                                              }
                                            }
                                          },
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(
                                      strings.text('Change reminder'),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            setState(() => _busy = true);
                                            try {
                                              await confirmAction(
                                                context,
                                                title: 'Remove reminder?',
                                                message:
                                                    'This only removes the reminder on this device.',
                                                actionLabel: 'Remove reminder',
                                                action: () => widget.session
                                                    .remove(item.opportunityId),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() => _busy = false);
                                              }
                                            }
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(
                                      strings.text('Remove reminder'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    strings.text(
                      'Reminders are cleared when you sign out. Check the provider’s current deadline before applying.',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
