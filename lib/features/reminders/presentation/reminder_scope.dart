import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';

class ReminderScope extends InheritedNotifier<DeadlineReminders> {
  const ReminderScope({
    required DeadlineReminders? controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ReminderSession? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReminderScope>()
      ?.notifier
      ?.session;
}

/// Permission can change in system settings without a server preference write.
class ReminderLifecycle extends StatefulWidget {
  const ReminderLifecycle({
    required this.session,
    required this.child,
    super.key,
  });
  final ReminderSession? session;
  final Widget child;
  @override
  State<ReminderLifecycle> createState() => _ReminderLifecycleState();
}

class _ReminderLifecycleState extends State<ReminderLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = widget.session;
    if (state == AppLifecycleState.resumed && session?.active == true) {
      unawaited(session!.refreshPermission().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
