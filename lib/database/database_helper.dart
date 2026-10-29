import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/activity_history_entry.dart';
import '../models/app_settings.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';
import '../models/time_entry.dart';

class DatabaseHelper {
  static const String _databaseName = 'plan_tasks.db';
  static const int _databaseVersion = 2;

  // Tasks table
  static const String tableTasks = 'tasks';
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDate = 'date';
  static const String columnCompleted = 'completed';
  static const String columnReminderTime = 'reminder_time';
  static const String columnCreatedAt = 'created_at';
  static const String columnTimeBlockStart = 'time_block_start';
  static const String columnTimeBlockEnd = 'time_block_end';
  static const String columnRecurringTemplateId = 'recurring_template_id';
  static const String columnIsSkipped = 'is_skipped';

  // Recurring templates table
  static const String tableRecurringTemplates = 'recurring_task_templates';

  // Time entries table
  static const String tableTimeEntries = 'time_entries';

  // Settings table
  static const String tableAppSettings = 'app_settings';

  // History table
  static const String tableActivityHistory = 'activity_history';

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
    if (_db != null && _db!.isOpen) return _db!;
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
      onUpgrade: _onUpgrade,
    );
  }

  /// Public helper to initialize full schema on test databases
  Future<void> createSchemaForTesting(Database testDb) => _onCreate(testDb, _databaseVersion);

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTasks (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnCompleted INTEGER NOT NULL DEFAULT 0,
        $columnReminderTime TEXT,
        $columnCreatedAt TEXT NOT NULL,
        $columnTimeBlockStart TEXT,
        $columnTimeBlockEnd TEXT,
        $columnRecurringTemplateId INTEGER,
        $columnIsSkipped INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableRecurringTemplates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        recurrence_type TEXT NOT NULL,
        weekdays TEXT,
        every_n_days INTEGER,
        cycle_active_days INTEGER,
        cycle_rest_days INTEGER,
        cycle_start_date TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        default_duration_minutes INTEGER,
        preferred_start_time TEXT,
        preferred_end_time TEXT,
        reminder_time_of_day TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_paused INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableTimeEntries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        activity_title TEXT NOT NULL,
        notes TEXT,
        linked_task_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAppSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableActivityHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tasks_date ON $tableTasks($columnDate)');
    await db.execute(
        'CREATE INDEX idx_tasks_template ON $tableTasks($columnRecurringTemplateId, $columnDate)');
    await db.execute(
        'CREATE INDEX idx_time_entries_date ON $tableTimeEntries(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Safely alter existing tasks table
      await db.execute(
          'ALTER TABLE $tableTasks ADD COLUMN $columnTimeBlockStart TEXT');
      await db.execute(
          'ALTER TABLE $tableTasks ADD COLUMN $columnTimeBlockEnd TEXT');
      await db.execute(
          'ALTER TABLE $tableTasks ADD COLUMN $columnRecurringTemplateId INTEGER');
      await db.execute(
          'ALTER TABLE $tableTasks ADD COLUMN $columnIsSkipped INTEGER NOT NULL DEFAULT 0');

      // Create new tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableRecurringTemplates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          recurrence_type TEXT NOT NULL,
          weekdays TEXT,
          every_n_days INTEGER,
          cycle_active_days INTEGER,
          cycle_rest_days INTEGER,
          cycle_start_date TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT,
          default_duration_minutes INTEGER,
          preferred_start_time TEXT,
          preferred_end_time TEXT,
          reminder_time_of_day TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_paused INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableTimeEntries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          activity_title TEXT NOT NULL,
          notes TEXT,
          linked_task_id INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableAppSettings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableActivityHistory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_type TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id INTEGER,
          details TEXT,
          timestamp TEXT NOT NULL
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_date ON $tableTasks($columnDate)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_template ON $tableTasks($columnRecurringTemplateId, $columnDate)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_time_entries_date ON $tableTimeEntries(date)');
    }
  }

  // ---------------------------------------------------------------------------
  // TASK CRUD
  // ---------------------------------------------------------------------------

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
      where: '$columnDate = ? AND $columnIsSkipped = 0',
      whereArgs: [date],
      orderBy: '$columnCompleted ASC, $columnTimeBlockStart ASC, $columnId ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<Map<String, int>> getTaskCountsForMonthPrefix(
      String yearMonthPrefix) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT $columnDate, COUNT(*) as count 
      FROM $tableTasks 
      WHERE $columnDate LIKE ? AND $columnIsSkipped = 0
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

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTasks,
      orderBy: '$columnDate ASC, $columnId ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  // ---------------------------------------------------------------------------
  // RECURRING TEMPLATES CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertRecurringTemplate(RecurringTaskTemplate template) async {
    final db = await database;
    return await db.insert(
      tableRecurringTemplates,
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateRecurringTemplate(RecurringTaskTemplate template) async {
    if (template.id == null) return 0;
    final db = await database;
    return await db.update(
      tableRecurringTemplates,
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteRecurringTemplate(int id) async {
    final db = await database;
    return await db.delete(
      tableRecurringTemplates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecurringTaskTemplate>> getAllRecurringTemplates() async {
    final db = await database;
    final maps = await db.query(
      tableRecurringTemplates,
      orderBy: 'is_active DESC, is_paused ASC, id ASC',
    );
    return maps.map((m) => RecurringTaskTemplate.fromMap(m)).toList();
  }

  Future<RecurringTaskTemplate?> getRecurringTemplateById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableRecurringTemplates,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RecurringTaskTemplate.fromMap(maps.first);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // TIME ENTRIES CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertTimeEntry(TimeEntry entry) async {
    final db = await database;
    return await db.insert(
      tableTimeEntries,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTimeEntry(TimeEntry entry) async {
    if (entry.id == null) return 0;
    final db = await database;
    return await db.update(
      tableTimeEntries,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteTimeEntry(int id) async {
    final db = await database;
    return await db.delete(
      tableTimeEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TimeEntry>> getTimeEntriesForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      tableTimeEntries,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_time ASC, id ASC',
    );
    return maps.map((m) => TimeEntry.fromMap(m)).toList();
  }

  Future<List<TimeEntry>> getAllTimeEntries() async {
    final db = await database;
    final maps = await db.query(
      tableTimeEntries,
      orderBy: 'date ASC, start_time ASC, id ASC',
    );
    return maps.map((m) => TimeEntry.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // APP SETTINGS CRUD
  // ---------------------------------------------------------------------------

  Future<AppSettings> getAppSettings() async {
    final db = await database;
    final maps = await db.query(tableAppSettings);
    final map = <String, String>{};
    for (final row in maps) {
      map[row['key'] as String] = row['value'] as String;
    }
    return AppSettings.fromMap(map);
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in settings.toMap().entries) {
      batch.insert(
        tableAppSettings,
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY HISTORY
  // ---------------------------------------------------------------------------

  Future<int> insertActivityHistory(ActivityHistoryEntry entry) async {
    final db = await database;
    return await db.insert(
      tableActivityHistory,
      entry.toMap(),
    );
  }

  Future<List<ActivityHistoryEntry>> getRecentActivityHistory(
      {int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      tableActivityHistory,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => ActivityHistoryEntry.fromMap(m)).toList();
  }

  Future<List<ActivityHistoryEntry>> getAllActivityHistory() async {
    final db = await database;
    final maps = await db.query(
      tableActivityHistory,
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ActivityHistoryEntry.fromMap(m)).toList();
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
