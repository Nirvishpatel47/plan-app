class Task {
  final int? id;
  final String title;
  final String date; // Stored in normalized 'YYYY-MM-DD' format
  final bool isCompleted;
  final DateTime? reminderTime; // Stored as ISO-8601 string or null
  final DateTime createdAt; // Stored as ISO-8601 string

  // Time-block scheduling and recurrence fields
  final String? timeBlockStart; // 'HH:mm' in 24-hr format e.g. "11:00"
  final String? timeBlockEnd; // 'HH:mm' in 24-hr format e.g. "11:30"
  final int? recurringTemplateId;
  final bool isSkipped;

  const Task({
    this.id,
    required this.title,
    required this.date,
    this.isCompleted = false,
    this.reminderTime,
    required this.createdAt,
    this.timeBlockStart,
    this.timeBlockEnd,
    this.recurringTemplateId,
    this.isSkipped = false,
  });

  /// Formats a DateTime into a normalized 'YYYY-MM-DD' string key.
  static String formatDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses a normalized 'YYYY-MM-DD' string into a DateTime (at local midnight).
  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return DateTime(y, m, d);
    }
    return DateTime.now();
  }

  DateTime get dateAsDateTime => parseDateKey(date);

  bool get hasTimeBlock =>
      timeBlockStart != null &&
      timeBlockEnd != null &&
      timeBlockStart!.trim().isNotEmpty &&
      timeBlockEnd!.trim().isNotEmpty;

  String? get formattedTimeBlock =>
      hasTimeBlock ? '$timeBlockStart–$timeBlockEnd' : null;

  Task copyWith({
    int? id,
    String? title,
    String? date,
    bool? isCompleted,
    DateTime? reminderTime,
    bool clearReminder = false,
    DateTime? createdAt,
    String? timeBlockStart,
    String? timeBlockEnd,
    bool clearTimeBlock = false,
    int? recurringTemplateId,
    bool? isSkipped,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      createdAt: createdAt ?? this.createdAt,
      timeBlockStart: clearTimeBlock ? null : (timeBlockStart ?? this.timeBlockStart),
      timeBlockEnd: clearTimeBlock ? null : (timeBlockEnd ?? this.timeBlockEnd),
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
      isSkipped: isSkipped ?? this.isSkipped,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'date': date,
      'completed': isCompleted ? 1 : 0,
      'reminder_time': reminderTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'time_block_start': timeBlockStart,
      'time_block_end': timeBlockEnd,
      'recurring_template_id': recurringTemplateId,
      'is_skipped': isSkipped ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      date: map['date'] as String,
      isCompleted: (map['completed'] as int? ?? 0) == 1,
      reminderTime: map['reminder_time'] != null
          ? DateTime.tryParse(map['reminder_time'] as String)?.toLocal()
          : null,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      timeBlockStart: map['time_block_start'] as String?,
      timeBlockEnd: map['time_block_end'] as String?,
      recurringTemplateId: map['recurring_template_id'] as int?,
      isSkipped: (map['is_skipped'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          date == other.date &&
          isCompleted == other.isCompleted &&
          reminderTime == other.reminderTime &&
          createdAt == other.createdAt &&
          timeBlockStart == other.timeBlockStart &&
          timeBlockEnd == other.timeBlockEnd &&
          recurringTemplateId == other.recurringTemplateId &&
          isSkipped == other.isSkipped;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      date.hashCode ^
      isCompleted.hashCode ^
      reminderTime.hashCode ^
      createdAt.hashCode ^
      timeBlockStart.hashCode ^
      timeBlockEnd.hashCode ^
      recurringTemplateId.hashCode ^
      isSkipped.hashCode;
}
