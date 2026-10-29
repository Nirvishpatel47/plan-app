class TimeEntry {
  final int? id;
  final String date; // 'YYYY-MM-DD'
  final String startTime; // 'HH:mm' in 24-hour normalized format e.g. "08:00"
  final String endTime; // 'HH:mm' in 24-hour normalized format e.g. "09:30"
  final String activityTitle;
  final String? notes;
  final int? linkedTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimeEntry({
    this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.activityTitle,
    this.notes,
    this.linkedTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper to convert 'HH:mm' to minutes since midnight
  static int parseMinutes(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h * 60 + m;
    }
    return 0;
  }

  /// Helper to format minutes since midnight to 'HH:mm'
  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23).toString().padLeft(2, '0');
    final m = (minutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    return '$h:$m';
  }

  int get startMinutes => parseMinutes(startTime);
  int get endMinutes => parseMinutes(endTime);

  int get durationMinutes {
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  String get formattedDuration {
    final mins = durationMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get formattedTimeRange => '$startTime–$endTime';

  TimeEntry copyWith({
    int? id,
    String? date,
    String? startTime,
    String? endTime,
    String? activityTitle,
    String? notes,
    int? linkedTaskId,
    bool clearLinkedTask = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activityTitle: activityTitle ?? this.activityTitle,
      notes: notes ?? this.notes,
      linkedTaskId: clearLinkedTask ? null : (linkedTaskId ?? this.linkedTaskId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'activity_title': activityTitle,
      'notes': notes,
      'linked_task_id': linkedTaskId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      activityTitle: map['activity_title'] as String,
      notes: map['notes'] as String?,
      linkedTaskId: map['linked_task_id'] as int?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          activityTitle == other.activityTitle &&
          notes == other.notes &&
          linkedTaskId == other.linkedTaskId;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      activityTitle.hashCode ^
      notes.hashCode ^
      linkedTaskId.hashCode;
}
