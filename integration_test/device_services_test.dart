import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myoccasio/features/auth/data/system_auth_browser.dart';
import 'package:myoccasio/features/reminders/data/reminder_platform.dart';
import 'package:myoccasio/features/reminders/domain/deadline_reminder.dart';

/// Opt-in native service checks on an isolated emulator/device. No account,
/// network API, private data or provider credentials are used. Run separately
/// from the normal app: this cancels the test installation's local reminders.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('VERIFY_NATIVE_BROWSER_CALLBACK')) {
    testWidgets(
      'system browser returns to the original pending app operation',
      (tester) async {
        const fixture = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
        final browser = SystemAuthBrowser();
        try {
          final callback = browser.authenticate(
            Uri.parse('https://example.test/auth/native?request=$fixture'),
          );
          // Test-only marker: use the owned custom-scheme fixture callback on the
          // isolated emulator. This does not contact a backend or mint a session.
          // ignore: avoid_print
          print('NATIVE_BROWSER_CALLBACK_READY');
          expect(
            await callback.timeout(const Duration(minutes: 2)),
            Uri.parse(
              'ca.occasiotech.myoccasio.auth://callback?code=$fixture&state=$fixture',
            ),
          );
        } finally {
          await browser.cancel();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  testWidgets(
    'native browser rejects unrelated URLs and cancellation is safe',
    (tester) async {
      final browser = SystemAuthBrowser();
      await expectLater(
        browser.authenticate(Uri.parse('https://example.test/unrelated')),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_url',
          ),
        ),
      );
      await browser.cancel();
      await browser.cancel();
    },
  );
  testWidgets(
    'real native notification scheduling replaces, lists and cancels',
    (tester) async {
      final plugin = FlutterLocalNotificationsPlugin();
      final platform = DeviceReminderPlatform(plugin: plugin);
      await platform.cancelAll();
      final permission = await platform.permission();
      expect(
        permission,
        isIn([ReminderPermission.allowed, ReminderPermission.denied]),
      );
      final deadline = DateTime.now()
          .toUtc()
          .add(const Duration(days: 10))
          .toIso8601String();
      final reminder = DeadlineReminder(
        notificationId: 8024,
        opportunityId: 'native-service-verification',
        title: 'Native service verification',
        deadline: deadline,
        daysBefore: 3,
        scheduledAt: DeadlineReminder.timeFor(deadline, 3)!,
      );
      try {
        await platform.schedule(reminder, french: false);
        expect(
          (await plugin.pendingNotificationRequests()).map((item) => item.id),
          [8024],
        );
        await platform.schedule(reminder, french: true);
        final pending = await plugin.pendingNotificationRequests();
        expect(pending, hasLength(1));
        expect(pending.single.title, 'Un petit rappel MyOccasio');
        expect(
          pending.single.body,
          isNot(contains('Native service verification')),
        );
        expect(pending.single.payload, anyOf(isNull, isEmpty));
        await platform.cancel(8024);
        expect(await plugin.pendingNotificationRequests(), isEmpty);
      } finally {
        await platform.cancelAll();
      }
    },
  );
}
