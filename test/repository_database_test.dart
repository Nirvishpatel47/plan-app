import 'package:flutter_test/flutter_test.dart';
import 'package:plan/database/database_helper.dart';
import 'package:plan/models/recurring_task_template.dart';
import 'package:plan/models/task.dart';
import 'package:plan/models/time_entry.dart';
import 'package:plan/repositories/task_repository.dart';
import 'package:plan/repositories/time_entry_repository.dart';
import 'package:plan/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseHelper dbHelper;
  late TaskRepository taskRepo;
  late TimeEntryRepository timeRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper();
    dbHelper.setDatabaseForTesting(db);
    await dbHelper.createSchemaForTesting(db);

    taskRepo = TaskRepository(databaseHelper: dbHelper);
    timeRepo = TimeEntryRepository(databaseHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
  });

  group('Database, Tasks, and Time Blocks', () {
    test('Create task with time block and retrieve by date', () async {
      final task = Task(
        title: 'Physics Study Session',
        date: '2026-10-29',
        timeBlockStart: '11:00',
        timeBlockEnd: '12:30',
        createdAt: DateTime.now(),
      );

      final added = await taskRepo.addTask(task);
      expect(added.id, isNotNull);
      expect(added.hasTimeBlock, true);
      expect(added.formattedTimeBlock, '11:00–12:30');

      final tasks = await taskRepo.getTasksForDate('2026-10-29');
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Physics Study Session');
      expect(tasks.first.timeBlockStart, '11:00');
      expect(tasks.first.timeBlockEnd, '12:30');
    });

    test('Toggle completion and skip task', () async {
      final task = await taskRepo.addTask(Task(
        title: 'Exercise',
        date: '2026-10-29',
        createdAt: DateTime.now(),
      ));

      final completed = await taskRepo.toggleTaskCompleted(task);
      expect(completed.isCompleted, true);

      var list = await taskRepo.getTasksForDate('2026-10-29');
      expect(list.first.isCompleted, true);

      // Skip task
      await taskRepo.skipTask(completed);
      list = await taskRepo.getTasksForDate('2026-10-29');
      // Skipped tasks are excluded from active date view
      expect(list, isEmpty);
    });
  });

  group('Recurring Task Templates & Deterministic Generation', () {
    test('Custom cycle 4 active / 1 rest days calculation', () {
      final cycleStart = DateTime(2026, 10, 1);
      final template = RecurringTaskTemplate(
        id: 1,
        title: 'Exercise Habit',
        recurrenceType: RecurrenceType.customCycle,
        cycleActiveDays: 4,
        cycleRestDays: 1,
        cycleStartDate: '2026-10-01',
        startDate: '2026-10-01',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Day 1 (Oct 1) -> Active
      expect(template.isScheduledForDate(cycleStart), true);
      expect(template.isRestDay(cycleStart), false);

      // Day 4 (Oct 4) -> Active
      expect(template.isScheduledForDate(cycleStart.add(const Duration(days: 3))), true);

      // Day 5 (Oct 5) -> Rest Day!
      final day5 = cycleStart.add(const Duration(days: 4));
      expect(template.isScheduledForDate(day5), false);
      expect(template.isRestDay(day5), true);

      // Day 6 (Oct 6) -> Active (next cycle begins)
      final day6 = cycleStart.add(const Duration(days: 5));
      expect(template.isScheduledForDate(day6), true);
      expect(template.isRestDay(day6), false);
    });

    test('Deterministic occurrence generation prevents duplicate tasks', () async {
      final template = await taskRepo.addTemplate(RecurringTaskTemplate(
        title: 'Morning Japanese',
        recurrenceType: RecurrenceType.daily,
        startDate: '2026-10-25',
        preferredStartTime: '08:00',
        preferredEndTime: '08:45',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Generate for 5 days
      final count1 = await taskRepo.reconcileRecurringOccurrences(
        from: DateTime(2026, 10, 25),
        to: DateTime(2026, 10, 29),
      );
      expect(count1, 5);

      final tasks = await taskRepo.getTasksForDate('2026-10-25');
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Morning Japanese');
      expect(tasks.first.timeBlockStart, '08:00');
      expect(tasks.first.recurringTemplateId, template.id);

      // Re-running generation must be completely idempotent (0 duplicate tasks created)
      final count2 = await taskRepo.reconcileRecurringOccurrences(
        from: DateTime(2026, 10, 25),
        to: DateTime(2026, 10, 29),
      );
      expect(count2, 0);

      final tasksAfter = await taskRepo.getTasksForDate('2026-10-25');
      expect(tasksAfter.length, 1);
    });
  });

  group('Time Entries, Gaps, and Conflicts', () {
    test('Add time entries, calculate non-overlapping coverage, gaps, and detect conflicts', () async {
      await timeRepo.addTimeEntry(TimeEntry(
        date: '2026-10-29',
        startTime: '08:00',
        endTime: '09:30', // 90 mins
        activityTitle: 'Reading',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await timeRepo.addTimeEntry(TimeEntry(
        date: '2026-10-29',
        startTime: '09:00', // 30 min overlap with entry 1!
        endTime: '11:00', // 120 mins
        activityTitle: 'Programming',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await timeRepo.getTimeEntriesForDate('2026-10-29');
      expect(entries.length, 2);

      final summary = timeRepo.calculateSummary(
        entries,
        windowStart: '08:00',
        windowEnd: '20:00', // 12 hours = 720 mins total window
      );

      // Total recorded: 90 + 120 = 210 mins
      expect(summary.totalRecordedMinutes, 210);
      // Unique covered (08:00 to 11:00): 180 mins
      expect(summary.uniqueCoveredMinutes, 180);
      // Conflict detected between 09:00 and 09:30
      expect(summary.conflicts.length, 1);
      expect(summary.conflicts.first.overlapTimeRange, '09:00–09:30');
      // Gap from 11:00 to 20:00 (9 hours = 540 mins)
      expect(summary.gaps.length, 1);
      expect(summary.gaps.first.startTime, '11:00');
      expect(summary.gaps.first.endTime, '20:00');
      expect(summary.untrackedMinutes, 540);
    });
  });

  group('Backup, Export, and Import Integration', () {
    test('Full export and restoreReplace roundtrip', () async {
      await taskRepo.addTask(Task(
        title: 'Task A',
        date: '2026-10-29',
        timeBlockStart: '10:00',
        timeBlockEnd: '11:00',
        createdAt: DateTime.now(),
      ));

      await timeRepo.addTimeEntry(TimeEntry(
        date: '2026-10-29',
        startTime: '10:00',
        endTime: '11:00',
        activityTitle: 'Worked on Task A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final backupService = BackupService(databaseHelper: dbHelper);
      final jsonStr = await backupService.exportBackupJson();

      final validation = backupService.validateBackupJson(jsonStr);
      expect(validation.isValid, true);
      expect(validation.tasksCount, 1);
      expect(validation.timeEntriesCount, 1);

      // Clear database to simulate fresh install
      await db.delete('tasks');
      await db.delete('time_entries');
      expect(await taskRepo.getTasksForDate('2026-10-29'), isEmpty);

      // Restore
      await backupService.importBackup(validation, mode: ImportMode.restoreReplace);

      final restoredTasks = await taskRepo.getTasksForDate('2026-10-29');
      expect(restoredTasks.length, 1);
      expect(restoredTasks.first.title, 'Task A');
      expect(restoredTasks.first.timeBlockStart, '10:00');

      final restoredEntries = await timeRepo.getTimeEntriesForDate('2026-10-29');
      expect(restoredEntries.length, 1);
      expect(restoredEntries.first.activityTitle, 'Worked on Task A');
    });

    test('Merge mode does not create duplicate entries', () async {
      await taskRepo.addTask(Task(
        title: 'Existing Task',
        date: '2026-10-29',
        createdAt: DateTime.now(),
      ));

      final backupService = BackupService(databaseHelper: dbHelper);
      final jsonStr = await backupService.exportBackupJson();
      final validation = backupService.validateBackupJson(jsonStr);

      // Import in merge mode
      await backupService.importBackup(validation, mode: ImportMode.merge);

      final tasks = await taskRepo.getTasksForDate('2026-10-29');
      expect(tasks.length, 1); // Not duplicated
    });

    test('Rejects invalid JSON safely', () {
      final backupService = BackupService(databaseHelper: dbHelper);
      final validation = backupService.validateBackupJson('{"format": "wrong_format"}');
      expect(validation.isValid, false);
      expect(validation.errorMessage, contains('Unrecognized backup format'));
    });
  });
}
