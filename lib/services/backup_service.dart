import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/activity_history_entry.dart';
import '../models/app_settings.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';
import '../models/time_entry.dart';

enum ImportMode {
  restoreReplace,
  merge,
}

class ImportValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int tasksCount;
  final int templatesCount;
  final int timeEntriesCount;
  final int historyCount;
  final Map<String, dynamic>? parsedPayload;

  const ImportValidationResult({
    required this.isValid,
    this.errorMessage,
    this.tasksCount = 0,
    this.templatesCount = 0,
    this.timeEntriesCount = 0,
    this.historyCount = 0,
    this.parsedPayload,
  });

  String get summaryText =>
      '$tasksCount tasks, $templatesCount habit templates, $timeEntriesCount time entries';
}

class BackupService {
  final DatabaseHelper _databaseHelper;

  static const String backupFormat = 'my_task_app_backup';
  static const int currentSchemaVersion = 1;

  BackupService({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper();

  /// Exports all application data to a clean, deterministic, versioned JSON string.
  Future<String> exportBackupJson() async {
    final tasks = await _databaseHelper.getAllTasks();
    final templates = await _databaseHelper.getAllRecurringTemplates();
    final timeEntries = await _databaseHelper.getAllTimeEntries();
    final settings = await _databaseHelper.getAppSettings();
    final history = await _databaseHelper.getAllActivityHistory();

    final exportMap = {
      'format': backupFormat,
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'data': {
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'recurringTemplates': templates.map((t) => t.toMap()).toList(),
        'timeEntries': timeEntries.map((e) => e.toMap()).toList(),
        'settings': settings.toMap(),
        'history': history.map((h) => h.toMap()).toList(),
      },
    };

    // Update last export timestamp
    await _databaseHelper.saveAppSettings(
      settings.copyWith(lastExportTimestamp: DateTime.now()),
    );

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'backup_exported',
        entityType: 'backup',
        details:
            'Exported ${tasks.length} tasks, ${timeEntries.length} time entries',
        timestamp: DateTime.now(),
      ),
    );

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  /// Validates a raw JSON string without mutating the database.
  ImportValidationResult validateBackupJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const ImportValidationResult(
          isValid: false,
          errorMessage: 'Invalid JSON format: expected a JSON object root.',
        );
      }

      final format = decoded['format'];
      if (format != backupFormat) {
        return const ImportValidationResult(
          isValid: false,
          errorMessage: 'Unrecognized backup format. Expected "$backupFormat".',
        );
      }

      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion is! int || schemaVersion > currentSchemaVersion) {
        return ImportValidationResult(
          isValid: false,
          errorMessage:
              'Unsupported backup schema version ($schemaVersion). Please update the app.',
        );
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return const ImportValidationResult(
          isValid: false,
          errorMessage: 'Backup file is missing the "data" section.',
        );
      }

      final tasksList = data['tasks'] as List? ?? [];
      final templatesList = data['recurringTemplates'] as List? ?? [];
      final timeEntriesList = data['timeEntries'] as List? ?? [];
      final historyList = data['history'] as List? ?? [];

      return ImportValidationResult(
        isValid: true,
        tasksCount: tasksList.length,
        templatesCount: templatesList.length,
        timeEntriesCount: timeEntriesList.length,
        historyCount: historyList.length,
        parsedPayload: data,
      );
    } catch (e) {
      return ImportValidationResult(
        isValid: false,
        errorMessage: 'JSON parse error: $e',
      );
    }
  }

  /// Transactionally imports backup data according to the selected mode.
  Future<void> importBackup(
    ImportValidationResult validation, {
    required ImportMode mode,
  }) async {
    if (!validation.isValid || validation.parsedPayload == null) {
      throw ArgumentError('Cannot import invalid backup: ${validation.errorMessage}');
    }

    final data = validation.parsedPayload!;
    final db = await _databaseHelper.database;

    final rawTasks = (data['tasks'] as List? ?? [])
        .map((m) => Task.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final rawTemplates = (data['recurringTemplates'] as List? ?? [])
        .map((m) =>
            RecurringTaskTemplate.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final rawTimeEntries = (data['timeEntries'] as List? ?? [])
        .map((m) => TimeEntry.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final rawHistory = (data['history'] as List? ?? [])
        .map((m) =>
            ActivityHistoryEntry.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final rawSettings = data['settings'] is Map
        ? AppSettings.fromMap(Map<String, String>.from(
            (data['settings'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
        : null;

    if (mode == ImportMode.restoreReplace) {
      // Transactional full replace
      await db.transaction((txn) async {
        await txn.delete('tasks');
        await txn.delete('recurring_task_templates');
        await txn.delete('time_entries');
        await txn.delete('activity_history');

        for (final t in rawTemplates) {
          await txn.insert('recurring_task_templates', t.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final t in rawTasks) {
          await txn.insert('tasks', t.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final e in rawTimeEntries) {
          await txn.insert('time_entries', e.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final h in rawHistory) {
          await txn.insert('activity_history', h.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        if (rawSettings != null) {
          for (final entry in rawSettings.toMap().entries) {
            await txn.insert(
              'app_settings',
              {'key': entry.key, 'value': entry.value},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await txn.insert('activity_history', {
          'event_type': 'backup_restored',
          'entity_type': 'backup',
          'details': 'Restored ${rawTasks.length} tasks and ${rawTimeEntries.length} time entries',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
    } else {
      // Merge mode: Add missing records without overwriting existing data
      await db.transaction((txn) async {
        // Merge Templates
        for (final template in rawTemplates) {
          final existing = await txn.query(
            'recurring_task_templates',
            where: 'title = ?',
            whereArgs: [template.title],
            limit: 1,
          );
          if (existing.isEmpty) {
            final map = template.toMap()..remove('id');
            await txn.insert('recurring_task_templates', map);
          }
        }

        // Merge Tasks
        for (final task in rawTasks) {
          final existing = await txn.query(
            'tasks',
            where: 'date = ? AND title = ?',
            whereArgs: [task.date, task.title],
            limit: 1,
          );
          if (existing.isEmpty) {
            final map = task.toMap()..remove('id');
            await txn.insert('tasks', map);
          }
        }

        // Merge Time Entries
        for (final entry in rawTimeEntries) {
          final existing = await txn.query(
            'time_entries',
            where: 'date = ? AND start_time = ? AND end_time = ? AND activity_title = ?',
            whereArgs: [entry.date, entry.startTime, entry.endTime, entry.activityTitle],
            limit: 1,
          );
          if (existing.isEmpty) {
            final map = entry.toMap()..remove('id');
            await txn.insert('time_entries', map);
          }
        }

        await txn.insert('activity_history', {
          'event_type': 'backup_merged',
          'entity_type': 'backup',
          'details': 'Merged backup records',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
    }
  }
}
