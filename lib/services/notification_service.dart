import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;
  bool _hasCheckedPermission = false;
  bool _permissionGranted = false;

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

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

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

  /// Request permissions on-demand ONLY when the user selects a reminder time.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_initialized) {
      await initialize();
    }

    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted = await androidImpl.requestNotificationsPermission();
          _permissionGranted = granted ?? false;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
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

  /// Schedules a local notification for a task.
  /// If the reminder time is in the past, or permission is denied, it safely exits.
  Future<bool> scheduleTaskReminder(Task task) async {
    if (task.id == null || task.reminderTime == null) return false;
    if (task.isCompleted) return false; // Do not schedule for completed tasks

    final reminder = task.reminderTime!;
    if (reminder.isBefore(DateTime.now())) {
      // Past reminder time, nothing to schedule
      return false;
    }

    if (!_initialized) {
      await initialize();
    }

    // Ensure permissions were granted
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

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}
