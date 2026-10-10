class Task {
  final int? id;
  final String title;
  final String date; // Stored in normalized 'YYYY-MM-DD' format
  final bool isCompleted;
  final DateTime? reminderTime; // Stored as ISO-8601 string or null
  final DateTime createdAt; // Stored as ISO-8601 string

  const Task({
    this.id,
    required this.title,
    required this.date,
    this.isCompleted = false,
    this.reminderTime,
    required this.createdAt,
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

  Task copyWith({
    int? id,
    String? title,
    String? date,
    bool? isCompleted,
    DateTime? reminderTime,
    bool clearReminder = false,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      createdAt: createdAt ?? this.createdAt,
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
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      date: map['date'] as String,
      isCompleted: (map['completed'] as int) == 1,
      reminderTime: map['reminder_time'] != null
          ? DateTime.tryParse(map['reminder_time'] as String)?.toLocal()
          : null,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
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
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      date.hashCode ^
      isCompleted.hashCode ^
      reminderTime.hashCode ^
      createdAt.hashCode;
}
