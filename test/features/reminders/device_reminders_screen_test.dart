import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/core/theme/app_theme.dart';
import 'package:myoccasio/features/reminders/data/deadline_reminders.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';
import 'package:myoccasio/features/reminders/presentation/deadline_reminder_sheet.dart';
import 'package:myoccasio/features/reminders/presentation/device_reminders_screen.dart';
import '../../core/localization/app_localization_test.dart' show showFrench;
import 'deadline_reminders_test.dart'
    show MemoryReminderStorage, RecordingReminderPlatform;

void main() {
  late RecordingReminderPlatform platform;
  late DeadlineReminders controller;
  late ReminderSession session;
  setUp(() {
    platform = RecordingReminderPlatform();
  });
  Future<void> initialize() async {
    controller = DeadlineReminders(
      platform: platform,
      storage: MemoryReminderStorage(),
      namespace: 'https://myoccasio.ca',
      now: () => DateTime(2026, 10, 24, 12),
    );
    session = controller.beginSession('student');
    await session.initialize();
  }

  Future<void> show(
    WidgetTester tester, {
    String deadline = '2026-11-05',
  }) async {
    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final saved = await showDeadlineReminder(
                  context,
                  session: session,
                  opportunityId: 'cat:real',
                  title: 'Actual opportunity',
                  deadline: deadline,
                );
                if (saved && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Confirmed saved')),
                  );
                }
              },
              child: const Text('Open reminder'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reminder'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('selected reminder is saved only after native confirmation', (
    tester,
  ) async {
    await show(tester);
    expect(platform.pending, isEmpty);
    await tester.tap(find.text('1 day before'));
    await reveal(tester, find.text('Save reminder'));
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed saved'), findsOneWidget);
    expect(session.items.single.daysBefore, 1);
    expect(platform.pending.values.single.opportunityId, 'cat:real');
  });

  testWidgets('pending native scheduling blocks duplicate save and Back', (
    tester,
  ) async {
    await show(tester);
    platform.scheduleGate = Completer<void>();
    platform.scheduleStarted = Completer<void>();
    await reveal(tester, find.text('Save reminder'));
    await tester.tap(find.text('Save reminder'));
    await tester.pump();
    await platform.scheduleStarted!.future;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('A helpful heads-up.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Close',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      platform.events.where((event) => event.startsWith('schedule:')).length,
      1,
    );
    platform.scheduleGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Confirmed saved'), findsOneWidget);
  });

  testWidgets(
    'denied notification permission retains the sheet and no false success',
    (tester) async {
      platform.status = ReminderPermission.denied;
      platform.requested = ReminderPermission.denied;
      await show(tester);
      await reveal(tester, find.text('Save reminder'));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();
      expect(
        find.text('Allow notifications in device settings to save a reminder.'),
        findsOneWidget,
      );
      expect(find.text('Confirmed saved'), findsNothing);
      expect(platform.pending, isEmpty);
      expect(session.items, isEmpty);
    },
  );

  testWidgets(
    'past or unknown deadlines disable save without inventing a time',
    (tester) async {
      await show(tester, deadline: 'No published deadline');
      expect(
        find.text('No reminder time is available before this deadline.'),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Save reminder');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(platform.pending, isEmpty);
    },
  );

  testWidgets(
    'device management reflects permission changes and confirmed removal',
    (tester) async {
      await initialize();
      await session.save(
        opportunityId: 'cat:real',
        title: 'Actual opportunity',
        deadline: '2026-11-05',
        daysBefore: 3,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DeviceRemindersScreen(session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications allowed on this device'), findsOneWidget);
      platform.status = ReminderPermission.denied;
      await session.refreshPermission();
      await tester.pumpAndSettle();
      expect(find.text('Notifications are off on this device'), findsOneWidget);
      await reveal(tester, find.text('Remove reminder'));
      await tester.tap(find.text('Remove reminder'));
      await tester.pumpAndSettle();
      expect(platform.pending, isNotEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove reminder'),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.items, isEmpty);
      expect(platform.pending, isEmpty);
      expect(find.text('No device reminders yet'), findsOneWidget);
    },
  );

  testWidgets(
    'reminder sheet scrolls with French 200% text in a short landscape viewport',
    (tester) async {
      await initialize();
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showFrench(
        tester,
        Scaffold(
          body: DeadlineReminderSheet(
            session: session,
            opportunityId: 'cat:real',
            title: 'Une possibilité réelle avec un nom long',
            deadline: '2026-11-05',
          ),
        ),
        scale: 2,
      );
      await reveal(tester, find.text('Enregistrer le rappel'));
      expect(tester.takeException(), isNull);
      expect(platform.pending, isEmpty);
    },
  );

  testWidgets(
    'account end removes reminders from an already open management screen',
    (tester) async {
      await initialize();
      await session.save(
        opportunityId: 'cat:real',
        title: 'Actual opportunity',
        deadline: '2026-11-05',
        daysBefore: 3,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DeviceRemindersScreen(session: session),
        ),
      );
      await tester.pumpAndSettle();
      await session.end();
      await tester.pumpAndSettle();
      expect(find.text('Actual opportunity'), findsNothing);
      expect(
        find.text('Your session changed. Please try again.'),
        findsOneWidget,
      );
      expect(platform.pending, isEmpty);
    },
  );
}
