import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/app_settings.dart';
import '../models/task.dart';

enum NotificationStatus {
  enabled,
  permissionNeeded,
  disabledBySystem,
  unsupported,
}

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;
  bool _hasCheckedPermission = false;
  bool _permissionGranted = false;

  static const int testNotificationId = 999999;
  static const int hourlyBaseNotificationId = 10000;

  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  factory NotificationService({FlutterLocalNotificationsPlugin? plugin}) {
    _instance ??= NotificationService._internal(plugin: plugin);
    return _instance!;
  }

  /// Initialize plugin settings. Does NOT request notification permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (handled gracefully): $e');
    }
  }

  /// Request permissions on-demand.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_initialized) {
      await initialize();
    }

    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          _permissionGranted = granted ?? false;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosImpl != null) {
          final granted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          _permissionGranted = granted ?? false;
        }
      } else {
        _permissionGranted = true;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      _permissionGranted = false;
    }

    _hasCheckedPermission = true;
    return _permissionGranted;
  }

  /// Checks current notification permission status.
  Future<NotificationStatus> checkStatus() async {
    if (kIsWeb) return NotificationStatus.unsupported;
    if (!_hasCheckedPermission) return NotificationStatus.permissionNeeded;
    return _permissionGranted
        ? NotificationStatus.enabled
        : NotificationStatus.disabledBySystem;
  }

  /// Sends a real test notification.
  Future<bool> sendTestNotification() async {
    if (!_initialized) await initialize();

    final granted = await requestPermissionIfNeeded();
    if (!granted) return false;

    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Verifies notification delivery',
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: testNotificationId,
        title: 'Test Notification',
        body: 'Your reminders are configured.',
        notificationDetails: notificationDetails,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
      return false;
    }
  }

  /// Schedules a local notification for a task.
  Future<bool> scheduleTaskReminder(Task task) async {
    if (task.id == null || task.reminderTime == null) return false;
    if (task.isCompleted) return false;

    final reminder = task.reminderTime!;
    if (reminder.isBefore(DateTime.now())) return false;

    if (!_initialized) await initialize();

    if (!_hasCheckedPermission) {
      final granted = await requestPermissionIfNeeded();
      if (!granted) return false;
    }

    try {
      final scheduledDate = tz.TZDateTime.from(reminder, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'task_reminders_channel',
        'Task Reminders',
        channelDescription: 'Notifications for planned task reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id: task.id!,
        title: 'Task Reminder',
        body: task.title,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to schedule notification (fallback): $e');
      return false;
    }
  }

  /// Cancels a notification associated with a task ID.
  Future<void> cancelTaskReminder(int taskId) async {
    try {
      await _notificationsPlugin.cancel(id: taskId);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// Cancels and reschedules hourly reminders across the configured tracking window.
  Future<void> syncHourlyReminders(AppSettings settings) async {
    // First, cancel existing scheduled hourly reminders (range: 10000..10100)
    for (int i = 0; i <= 100; i++) {
      try {
        await _notificationsPlugin.cancel(id: hourlyBaseNotificationId + i);
      } catch (_) {}
    }

    if (!settings.hourlyRemindersEnabled) return;

    if (!_initialized) await initialize();
    if (!_hasCheckedPermission) {
      final granted = await requestPermissionIfNeeded();
      if (!granted) return;
    }

    final winStartParts = settings.trackingWindowStart.split(':');
    final winEndParts = settings.trackingWindowEnd.split(':');
    final startHour = int.tryParse(winStartParts[0]) ?? 8;
    final endHour = int.tryParse(winEndParts[0]) ?? 20;
    final interval = settings.hourlyInterval.clamp(1, 12);

    final quietStartHour = settings.quietHoursEnabled
        ? (int.tryParse(settings.quietHoursStart.split(':')[0]) ?? 22)
        : -1;
    final quietEndHour = settings.quietHoursEnabled
        ? (int.tryParse(settings.quietHoursEnd.split(':')[0]) ?? 7)
        : -1;

    final now = DateTime.now();

    const messages = [
      'Review your time log.',
      'What are you working on?',
      'Log the last hour.',
      'Check in with your daily plan.',
    ];

    int scheduleIndex = 0;

    // Schedule for the next 2 days to ensure coverage without app launch
    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final targetDay = now.add(Duration(days: dayOffset));

      for (int h = startHour; h <= endHour; h += interval) {
        // Check quiet hours
        if (settings.quietHoursEnabled) {
          if (quietStartHour > quietEndHour) {
            // Over midnight e.g. 22 to 7
            if (h >= quietStartHour || h < quietEndHour) continue;
          } else {
            if (h >= quietStartHour && h < quietEndHour) continue;
          }
        }

        final reminderTime = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          h,
          0,
        );

        if (reminderTime.isBefore(now.add(const Duration(minutes: 1)))) {
          continue; // Past interval
        }

        final notifId = hourlyBaseNotificationId + scheduleIndex;
        scheduleIndex++;
        if (scheduleIndex > 100) break;

        final message = messages[(h % messages.length)];

        try {
          final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

          const androidDetails = AndroidNotificationDetails(
            'hourly_reminders_channel',
            'Hourly Reminders',
            channelDescription: 'Hourly prompts to review and log your time',
            importance: Importance.low,
            priority: Priority.low,
          );

          const darwinDetails = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          );

          await _notificationsPlugin.zonedSchedule(
            id: notifId,
            title: '${h.toString().padLeft(2, '0')}:00 Time Tracker',
            body: message,
            scheduledDate: scheduledDate,
            notificationDetails: const NotificationDetails(
              android: androidDetails,
              iOS: darwinDetails,
              macOS: darwinDetails,
            ),
            androidScheduleMode: AndroidScheduleMode.inexact,
          );
        } catch (e) {
          debugPrint('Failed to schedule hourly reminder: $e');
        }
      }
    }
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}
