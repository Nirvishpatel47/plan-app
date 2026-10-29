import 'package:sqflite/sqflite.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';

class RecurrenceService {
  final Database _db;

  RecurrenceService(this._db);

  /// Generates missing task occurrences for all active templates within a date range [from, to].
  /// This operation is completely idempotent and runs in a database transaction.
  Future<int> generateOccurrences({
    required DateTime from,
    required DateTime to,
  }) async {
    int generatedCount = 0;

    final normalizedFrom = DateTime(from.year, from.month, from.day);
    final normalizedTo = DateTime(to.year, to.month, to.day);

    if (normalizedTo.isBefore(normalizedFrom)) return 0;

    // Fetch all active, unpaused templates
    final templateMaps = await _db.query(
      'recurring_task_templates',
      where: 'is_active = 1 AND is_paused = 0',
    );
    final templates =
        templateMaps.map((m) => RecurringTaskTemplate.fromMap(m)).toList();

    if (templates.isEmpty) return 0;

    await _db.transaction((txn) async {
      final daysCount = normalizedTo.difference(normalizedFrom).inDays + 1;

      for (int i = 0; i < daysCount; i++) {
        final currentDate = normalizedFrom.add(Duration(days: i));
        final dateKey = Task.formatDateKey(currentDate);

        for (final template in templates) {
          if (!template.isScheduledForDate(currentDate)) {
            continue;
          }

          // Check if an occurrence already exists for this template and date
          final existing = await txn.query(
            'tasks',
            where: 'recurring_template_id = ? AND date = ?',
            whereArgs: [template.id, dateKey],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            // Task already exists for this date, do NOT duplicate or overwrite!
            continue;
          }

          DateTime? reminderDateTime;
          if (template.reminderTimeOfDay != null) {
            final parts = template.reminderTimeOfDay!.split(':');
            if (parts.length == 2) {
              final h = int.tryParse(parts[0]) ?? 9;
              final m = int.tryParse(parts[1]) ?? 0;
              reminderDateTime = DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                h,
                m,
              );
            }
          }

          final newTask = Task(
            title: template.title,
            date: dateKey,
            isCompleted: false,
            reminderTime: reminderDateTime,
            createdAt: DateTime.now(),
            timeBlockStart: template.preferredStartTime,
            timeBlockEnd: template.preferredEndTime,
            recurringTemplateId: template.id,
            isSkipped: false,
          );

          await txn.insert('tasks', newTask.toMap());
          generatedCount++;
        }
      }
    });

    return generatedCount;
  }
}
