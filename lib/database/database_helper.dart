import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

class DatabaseHelper {
  static const String _databaseName = 'plan_tasks.db';
  static const int _databaseVersion = 1;

  static const String tableTasks = 'tasks';
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDate = 'date';
  static const String columnCompleted = 'completed';
  static const String columnReminderTime = 'reminder_time';
  static const String columnCreatedAt = 'created_at';

  static DatabaseHelper? _instance;
  Database? _db;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Optional custom database injection for testing
  void setDatabaseForTesting(Database testDb) {
    _db = testDb;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTasks (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnCompleted INTEGER NOT NULL DEFAULT 0,
        $columnReminderTime TEXT,
        $columnCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tasks_date ON $tableTasks($columnDate)',
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert(
      tableTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getTasksForDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTasks,
      where: '$columnDate = ?',
      whereArgs: [date],
      orderBy: '$columnCompleted ASC, $columnId ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Returns task counts grouped by date for a given year-month prefix (e.g. '2026-09%')
  Future<Map<String, int>> getTaskCountsForMonthPrefix(String yearMonthPrefix) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT $columnDate, COUNT(*) as count 
      FROM $tableTasks 
      WHERE $columnDate LIKE ? 
      GROUP BY $columnDate
      ''',
      ['$yearMonthPrefix%'],
    );

    final map = <String, int>{};
    for (final row in results) {
      final date = row[columnDate] as String;
      final count = row['count'] as int;
      map[date] = count;
    }
    return map;
  }

  Future<int> updateTask(Task task) async {
    if (task.id == null) return 0;
    final db = await database;
    return await db.update(
      tableTasks,
      task.toMap(),
      where: '$columnId = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      tableTasks,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTasks,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
