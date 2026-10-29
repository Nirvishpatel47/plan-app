import 'dart:convert';
import 'task.dart';

enum RecurrenceType {
  daily,
  weekdays,
  everyNDays,
  customCycle;

  static RecurrenceType fromString(String value) {
    switch (value) {
      case 'weekdays':
        return RecurrenceType.weekdays;
      case 'every_n_days':
        return RecurrenceType.everyNDays;
      case 'custom_cycle':
        return RecurrenceType.customCycle;
      case 'daily':
      default:
        return RecurrenceType.daily;
    }
  }

  String toDbString() {
    switch (this) {
      case RecurrenceType.daily:
        return 'daily';
      case RecurrenceType.weekdays:
        return 'weekdays';
      case RecurrenceType.everyNDays:
        return 'every_n_days';
      case RecurrenceType.customCycle:
        return 'custom_cycle';
    }
  }

  String get displayName {
    switch (this) {
      case RecurrenceType.daily:
        return 'Every day';
      case RecurrenceType.weekdays:
        return 'Selected weekdays';
      case RecurrenceType.everyNDays:
        return 'Every N days';
      case RecurrenceType.customCycle:
        return 'Custom cycle (Active/Rest)';
    }
  }
}

class RecurringTaskTemplate {
  final int? id;
  final String title;
  final String? description;
  final RecurrenceType recurrenceType;
  final List<int> weekdays; // 1 = Monday, 7 = Sunday
  final int? everyNDays;
  final int? cycleActiveDays;
  final int? cycleRestDays;
  final String? cycleStartDate; // 'YYYY-MM-DD'
  final String startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD' or null
  final int? defaultDurationMinutes;
  final String? preferredStartTime; // 'HH:mm'
  final String? preferredEndTime; // 'HH:mm'
  final String? reminderTimeOfDay; // 'HH:mm'
  final bool isActive;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTaskTemplate({
    this.id,
    required this.title,
    this.description,
    this.recurrenceType = RecurrenceType.daily,
    this.weekdays = const [],
    this.everyNDays,
    this.cycleActiveDays,
    this.cycleRestDays,
    this.cycleStartDate,
    required this.startDate,
    this.endDate,
    this.defaultDurationMinutes,
    this.preferredStartTime,
    this.preferredEndTime,
    this.reminderTimeOfDay,
    this.isActive = true,
    this.isPaused = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Evaluates whether this template is scheduled for a specific calendar date.
  bool isScheduledForDate(DateTime date) {
    if (!isActive || isPaused) return false;

    final targetMidnight = DateTime(date.year, date.month, date.day);
    final startMidnight = Task.parseDateKey(startDate);
    if (targetMidnight.isBefore(startMidnight)) return false;

    if (endDate != null) {
      final endMidnight = Task.parseDateKey(endDate!);
      if (targetMidnight.isAfter(endMidnight)) return false;
    }

    switch (recurrenceType) {
      case RecurrenceType.daily:
        return true;

      case RecurrenceType.weekdays:
        return weekdays.contains(date.weekday);

      case RecurrenceType.everyNDays:
        final interval = everyNDays ?? 1;
        if (interval <= 0) return true;
        final diffDays = targetMidnight.difference(startMidnight).inDays;
        return diffDays >= 0 && (diffDays % interval == 0);

      case RecurrenceType.customCycle:
        final active = cycleActiveDays ?? 1;
        final rest = cycleRestDays ?? 0;
        final totalCycle = active + rest;
        if (totalCycle <= 0) return true;

        final cycleStart = cycleStartDate != null
            ? Task.parseDateKey(cycleStartDate!)
            : startMidnight;

        final diffDays = targetMidnight.difference(cycleStart).inDays;
        if (diffDays < 0) return false;

        final position = diffDays % totalCycle;
        return position < active;
    }
  }

  /// Identifies if the date is explicitly a rest day in a custom cycle.
  bool isRestDay(DateTime date) {
    if (!isActive || isPaused) return false;
    if (recurrenceType != RecurrenceType.customCycle) return false;

    final targetMidnight = DateTime(date.year, date.month, date.day);
    final startMidnight = Task.parseDateKey(startDate);
    if (targetMidnight.isBefore(startMidnight)) return false;

    if (endDate != null) {
      final endMidnight = Task.parseDateKey(endDate!);
      if (targetMidnight.isAfter(endMidnight)) return false;
    }

    final active = cycleActiveDays ?? 1;
    final rest = cycleRestDays ?? 0;
    final totalCycle = active + rest;
    if (totalCycle <= 0 || rest <= 0) return false;

    final cycleStart = cycleStartDate != null
        ? Task.parseDateKey(cycleStartDate!)
        : startMidnight;

    final diffDays = targetMidnight.difference(cycleStart).inDays;
    if (diffDays < 0) return false;

    final position = diffDays % totalCycle;
    return position >= active;
  }

  RecurringTaskTemplate copyWith({
    int? id,
    String? title,
    String? description,
    RecurrenceType? recurrenceType,
    List<int>? weekdays,
    int? everyNDays,
    int? cycleActiveDays,
    int? cycleRestDays,
    String? cycleStartDate,
    String? startDate,
    String? endDate,
    bool clearEndDate = false,
    int? defaultDurationMinutes,
    String? preferredStartTime,
    String? preferredEndTime,
    String? reminderTimeOfDay,
    bool clearReminder = false,
    bool? isActive,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTaskTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      weekdays: weekdays ?? this.weekdays,
      everyNDays: everyNDays ?? this.everyNDays,
      cycleActiveDays: cycleActiveDays ?? this.cycleActiveDays,
      cycleRestDays: cycleRestDays ?? this.cycleRestDays,
      cycleStartDate: cycleStartDate ?? this.cycleStartDate,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
      preferredStartTime: preferredStartTime ?? this.preferredStartTime,
      preferredEndTime: preferredEndTime ?? this.preferredEndTime,
      reminderTimeOfDay: clearReminder ? null : (reminderTimeOfDay ?? this.reminderTimeOfDay),
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'recurrence_type': recurrenceType.toDbString(),
      'weekdays': jsonEncode(weekdays),
      'every_n_days': everyNDays,
      'cycle_active_days': cycleActiveDays,
      'cycle_rest_days': cycleRestDays,
      'cycle_start_date': cycleStartDate,
      'start_date': startDate,
      'end_date': endDate,
      'default_duration_minutes': defaultDurationMinutes,
      'preferred_start_time': preferredStartTime,
      'preferred_end_time': preferredEndTime,
      'reminder_time_of_day': reminderTimeOfDay,
      'is_active': isActive ? 1 : 0,
      'is_paused': isPaused ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RecurringTaskTemplate.fromMap(Map<String, dynamic> map) {
    List<int> parsedWeekdays = [];
    if (map['weekdays'] != null) {
      try {
        final decoded = jsonDecode(map['weekdays'] as String);
        if (decoded is List) {
          parsedWeekdays = decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    return RecurringTaskTemplate(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      recurrenceType: RecurrenceType.fromString(map['recurrence_type'] as String? ?? 'daily'),
      weekdays: parsedWeekdays,
      everyNDays: map['every_n_days'] as int?,
      cycleActiveDays: map['cycle_active_days'] as int?,
      cycleRestDays: map['cycle_rest_days'] as int?,
      cycleStartDate: map['cycle_start_date'] as String?,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      defaultDurationMinutes: map['default_duration_minutes'] as int?,
      preferredStartTime: map['preferred_start_time'] as String?,
      preferredEndTime: map['preferred_end_time'] as String?,
      reminderTimeOfDay: map['reminder_time_of_day'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isPaused: (map['is_paused'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
