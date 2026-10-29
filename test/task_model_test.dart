import 'package:flutter_test/flutter_test.dart';
import 'package:plan/models/task.dart';

void main() {
  group('Task Model Tests', () {
    test('Date key formatting and parsing roundtrip', () {
      final dt = DateTime(2026, 9, 30, 15, 30);
      final key = Task.formatDateKey(dt);
      expect(key, '2026-09-30');

      final parsed = Task.parseDateKey(key);
      expect(parsed.year, 2026);
      expect(parsed.month, 9);
      expect(parsed.day, 30);
    });

    test('toMap and fromMap preserves all fields including time blocks', () {
      final now = DateTime(2026, 9, 30, 10, 0);
      final reminder = DateTime(2026, 9, 30, 14, 0);

      final task = Task(
        id: 42,
        title: 'Complete Project Review',
        date: '2026-09-30',
        isCompleted: true,
        reminderTime: reminder,
        createdAt: now,
        timeBlockStart: '14:00',
        timeBlockEnd: '15:30',
        recurringTemplateId: 5,
        isSkipped: false,
      );

      final map = task.toMap();
      expect(map['id'], 42);
      expect(map['title'], 'Complete Project Review');
      expect(map['date'], '2026-09-30');
      expect(map['completed'], 1);
      expect(map['reminder_time'], reminder.toIso8601String());
      expect(map['created_at'], now.toIso8601String());
      expect(map['time_block_start'], '14:00');
      expect(map['time_block_end'], '15:30');
      expect(map['recurring_template_id'], 5);
      expect(map['is_skipped'], 0);

      final fromMapTask = Task.fromMap(map);
      expect(fromMapTask.id, task.id);
      expect(fromMapTask.title, task.title);
      expect(fromMapTask.date, task.date);
      expect(fromMapTask.isCompleted, true);
      expect(fromMapTask.reminderTime?.toIso8601String(), reminder.toIso8601String());
      expect(fromMapTask.timeBlockStart, '14:00');
      expect(fromMapTask.timeBlockEnd, '15:30');
      expect(fromMapTask.hasTimeBlock, true);
      expect(fromMapTask.formattedTimeBlock, '14:00–15:30');
      expect(fromMapTask.recurringTemplateId, 5);
    });

    test('copyWith works properly and allows clearing reminder and time block', () {
      final task = Task(
        id: 1,
        title: 'Original Title',
        date: '2026-09-30',
        isCompleted: false,
        reminderTime: DateTime(2026, 9, 30, 10, 0),
        createdAt: DateTime(2026, 9, 30, 8, 0),
        timeBlockStart: '10:00',
        timeBlockEnd: '11:00',
      );

      final updated = task.copyWith(
        title: 'Updated Title',
        isCompleted: true,
        clearReminder: true,
        clearTimeBlock: true,
      );

      expect(updated.id, 1);
      expect(updated.title, 'Updated Title');
      expect(updated.isCompleted, true);
      expect(updated.reminderTime, isNull);
      expect(updated.timeBlockStart, isNull);
      expect(updated.hasTimeBlock, false);
    });
  });
}
