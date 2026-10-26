import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:myoccasio/features/reminders/domain/deadline_reminder.dart';

enum ReminderPermission { allowed, denied, unavailable }

abstract interface class ReminderPlatform {
  Future<ReminderPermission> permission();
  Future<ReminderPermission> requestPermission();
  Future<void> schedule(DeadlineReminder reminder, {required bool french});
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<void> openSettings();
}

class DeviceReminderPlatform implements ReminderPlatform {
  DeviceReminderPlatform({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  Future<void> _initialize() => _initialization ??= _initializePlugin()
      .catchError((Object error, StackTrace stack) {
        _initialization = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _initializePlugin() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<ReminderPermission> permission() async {
    await _initialize();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await android?.areNotificationsEnabled() != true) {
        return ReminderPermission.denied;
      }
      final channels = await android?.getNotificationChannels();
      final blocked =
          channels?.any(
            (channel) =>
                channel.id == 'myoccasio_deadline_reminders' &&
                channel.importance == Importance.none,
          ) ??
          false;
      return blocked ? ReminderPermission.denied : ReminderPermission.allowed;
    }
    if (Platform.isIOS) {
      final status = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return status?.isEnabled == true
          ? ReminderPermission.allowed
          : ReminderPermission.denied;
    }
    return ReminderPermission.unavailable;
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    await _initialize();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
    return permission();
  }

  @override
  Future<void> schedule(
    DeadlineReminder reminder, {
    required bool french,
  }) async {
    await _initialize();
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      title: french ? 'Un petit rappel MyOccasio' : 'A MyOccasio heads-up',
      body: french
          ? 'Une échéance approche. Ouvrez MyOccasio pour consulter vos rappels.'
          : 'A deadline is coming up. Open MyOccasio to review your reminders.',
      scheduledDate: tz.TZDateTime.from(reminder.scheduledAt.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'myoccasio_deadline_reminders',
          french ? 'Rappels d’échéances' : 'Deadline reminders',
          channelDescription: french
              ? 'Rappels demandés sur cet appareil.'
              : 'Reminders you requested on this device.',
          icon: 'ic_notification',
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _initialize();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> openSettings() async {
    await _initialize();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }
}
