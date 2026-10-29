class ActivityHistoryEntry {
  final int? id;
  final String eventType; // e.g. 'time_entry_created', 'task_completed', 'backup_exported'
  final String entityType; // e.g. 'time_entry', 'task', 'template', 'backup'
  final int? entityId;
  final String? details;
  final DateTime timestamp;

  const ActivityHistoryEntry({
    this.id,
    required this.eventType,
    required this.entityType,
    this.entityId,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'event_type': eventType,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ActivityHistoryEntry(
      id: map['id'] as int?,
      eventType: map['event_type'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int?,
      details: map['details'] as String?,
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
