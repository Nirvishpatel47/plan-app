import 'package:flutter/material.dart';

class AppSettings {
  final String startOfDay; // e.g. "08:00"
  final String trackingWindowStart; // e.g. "08:00"
  final String trackingWindowEnd; // e.g. "20:00"
  final bool hourlyRemindersEnabled;
  final int hourlyInterval; // hours e.g. 1
  final bool quietHoursEnabled;
  final String quietHoursStart; // e.g. "22:00"
  final String quietHoursEnd; // e.g. "07:00"
  final ThemeMode themeMode;
  final DateTime? lastExportTimestamp;

  const AppSettings({
    this.startOfDay = '08:00',
    this.trackingWindowStart = '08:00',
    this.trackingWindowEnd = '20:00',
    this.hourlyRemindersEnabled = false,
    this.hourlyInterval = 1,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.themeMode = ThemeMode.system,
    this.lastExportTimestamp,
  });

  AppSettings copyWith({
    String? startOfDay,
    String? trackingWindowStart,
    String? trackingWindowEnd,
    bool? hourlyRemindersEnabled,
    int? hourlyInterval,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    ThemeMode? themeMode,
    DateTime? lastExportTimestamp,
  }) {
    return AppSettings(
      startOfDay: startOfDay ?? this.startOfDay,
      trackingWindowStart: trackingWindowStart ?? this.trackingWindowStart,
      trackingWindowEnd: trackingWindowEnd ?? this.trackingWindowEnd,
      hourlyRemindersEnabled: hourlyRemindersEnabled ?? this.hourlyRemindersEnabled,
      hourlyInterval: hourlyInterval ?? this.hourlyInterval,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      themeMode: themeMode ?? this.themeMode,
      lastExportTimestamp: lastExportTimestamp ?? this.lastExportTimestamp,
    );
  }

  Map<String, String> toMap() {
    return {
      'start_of_day': startOfDay,
      'tracking_window_start': trackingWindowStart,
      'tracking_window_end': trackingWindowEnd,
      'hourly_reminders_enabled': hourlyRemindersEnabled.toString(),
      'hourly_interval': hourlyInterval.toString(),
      'quiet_hours_enabled': quietHoursEnabled.toString(),
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'theme_mode': themeMode.name,
      if (lastExportTimestamp != null)
        'last_export_timestamp': lastExportTimestamp!.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    ThemeMode parsedThemeMode = ThemeMode.system;
    final themeStr = map['theme_mode'];
    if (themeStr == 'light') {
      parsedThemeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      parsedThemeMode = ThemeMode.dark;
    }

    return AppSettings(
      startOfDay: map['start_of_day'] ?? '08:00',
      trackingWindowStart: map['tracking_window_start'] ?? '08:00',
      trackingWindowEnd: map['tracking_window_end'] ?? '20:00',
      hourlyRemindersEnabled: map['hourly_reminders_enabled'] == 'true',
      hourlyInterval: int.tryParse(map['hourly_interval'] ?? '1') ?? 1,
      quietHoursEnabled: map['quiet_hours_enabled'] == 'true',
      quietHoursStart: map['quiet_hours_start'] ?? '22:00',
      quietHoursEnd: map['quiet_hours_end'] ?? '07:00',
      themeMode: parsedThemeMode,
      lastExportTimestamp: map['last_export_timestamp'] != null
          ? DateTime.tryParse(map['last_export_timestamp']!)
          : null,
    );
  }
}
