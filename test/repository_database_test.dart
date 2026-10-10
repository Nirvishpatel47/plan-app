import 'package:flutter_test/flutter_test.dart';
import 'package:plan/database/database_helper.dart';
import 'package:plan/models/task.dart';
import 'package:plan/repositories/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DatabaseHelper dbHelper;
  late TaskRepository repository;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_date ON tasks(date)');

    dbHelper = DatabaseHelper();
    dbHelper.setDatabaseForTesting(db);
    repository = TaskRepository(databaseHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
  });

  group('TaskRepository and Database Tests', () {
    test('Create, retrieve by date, and verify SQLite persistence', () async {
      final task = Task(
        title: 'Read research paper',
        date: '2026-09-30',
        createdAt: DateTime.now(),
      );

      final added = await repository.addTask(task);
      expect(added.id, isNotNull);

      final tasksToday = await repository.getTasksForDate('2026-09-30');
      expect(tasksToday.length, 1);
      expect(tasksToday.first.title, 'Read research paper');
      expect(tasksToday.first.isCompleted, false);

      final otherDateTasks = await repository.getTasksForDate('2026-10-01');
      expect(otherDateTasks, isEmpty);
    });

    test('Toggle completion persists immediately to database', () async {
      final task = await repository.addTask(Task(
        title: 'Exercise',
        date: '2026-09-30',
        createdAt: DateTime.now(),
      ));

      // Toggle to completed
      final completed = await repository.toggleTaskCompleted(task);
      expect(completed.isCompleted, true);

      var tasks = await repository.getTasksForDate('2026-09-30');
      expect(tasks.first.isCompleted, true);

      // Toggle back to incomplete
      final unchecked = await repository.toggleTaskCompleted(completed);
      expect(unchecked.isCompleted, false);

      tasks = await repository.getTasksForDate('2026-09-30');
      expect(tasks.first.isCompleted, false);
    });

    test('Edit task updates title, date, and reminder in database', () async {
      final task = await repository.addTask(Task(
        title: 'Draft letter',
        date: '2026-09-30',
        createdAt: DateTime.now(),
      ));

      final edited = task.copyWith(
        title: 'Send finalized letter',
        date: '2026-10-05',
      );
      await repository.updateTask(edited);

      // Verify no longer under old date
      final oldDateList = await repository.getTasksForDate('2026-09-30');
      expect(oldDateList, isEmpty);

      // Verify appears under new date
      final newDateList = await repository.getTasksForDate('2026-10-05');
      expect(newDateList.length, 1);
      expect(newDateList.first.title, 'Send finalized letter');
    });

    test('Delete task permanently removes it from database', () async {
      final task = await repository.addTask(Task(
        title: 'Temporary task',
        date: '2026-09-30',
        createdAt: DateTime.now(),
      ));

      expect((await repository.getTasksForDate('2026-09-30')).length, 1);

      await repository.deleteTask(task.id!);
      expect((await repository.getTasksForDate('2026-09-30')), isEmpty);
    });

    test('Month count aggregation for calendar dots', () async {
      await repository.addTask(Task(
        title: 'Task 1',
        date: '2026-10-01',
        createdAt: DateTime.now(),
      ));
      await repository.addTask(Task(
        title: 'Task 2',
        date: '2026-10-01',
        createdAt: DateTime.now(),
      ));
      await repository.addTask(Task(
        title: 'Task 3',
        date: '2026-10-15',
        createdAt: DateTime.now(),
      ));
      await repository.addTask(Task(
        title: 'Task in Nov',
        date: '2026-11-01',
        createdAt: DateTime.now(),
      ));

      final counts = await repository.getTaskCountsForMonth(2026, 10);
      expect(counts['2026-10-01'], 2);
      expect(counts['2026-10-15'], 1);
      expect(counts['2026-11-01'], isNull);
    });
  });
}
