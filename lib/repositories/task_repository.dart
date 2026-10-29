import '../database/database_helper.dart';
import '../models/activity_history_entry.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/recurrence_service.dart';

class TaskRepository {
  final DatabaseHelper _databaseHelper;
  final NotificationService _notificationService;

  TaskRepository({
    DatabaseHelper? databaseHelper,
    NotificationService? notificationService,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper(),
        _notificationService = notificationService ?? NotificationService();

  Future<List<Task>> getTasksForDate(String date) async {
    return await _databaseHelper.getTasksForDate(date);
  }

  Future<Map<String, int>> getTaskCountsForMonth(int year, int month) async {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return await _databaseHelper.getTaskCountsForMonthPrefix(prefix);
  }

  Future<Task> addTask(Task task) async {
    final id = await _databaseHelper.insertTask(task);
    final insertedTask = task.copyWith(id: id);

    if (insertedTask.reminderTime != null && !insertedTask.isCompleted) {
      await _notificationService.scheduleTaskReminder(insertedTask);
    }

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'task_created',
        entityType: 'task',
        entityId: id,
        details: '${task.date}: ${task.title}',
        timestamp: DateTime.now(),
      ),
    );

    return insertedTask;
  }

  Future<void> updateTask(Task task, {DateTime? previousReminderTime}) async {
    if (task.id == null) return;
    await _databaseHelper.updateTask(task);

    final taskId = task.id!;
    // If completed or reminder removed, cancel existing reminder
    if (task.isCompleted || task.reminderTime == null) {
      await _notificationService.cancelTaskReminder(taskId);
    } else {
      // If reminder changed or retained, update notification
      if (previousReminderTime != null) {
        await _notificationService.cancelTaskReminder(taskId);
      }
      await _notificationService.scheduleTaskReminder(task);
    }

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'task_updated',
        entityType: 'task',
        entityId: taskId,
        details: '${task.date}: ${task.title}',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> deleteTask(int taskId) async {
    final task = await _databaseHelper.getTaskById(taskId);
    await _databaseHelper.deleteTask(taskId);
    await _notificationService.cancelTaskReminder(taskId);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'task_deleted',
        entityType: 'task',
        entityId: taskId,
        details: task != null ? '${task.date}: ${task.title}' : null,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<Task> toggleTaskCompleted(Task task) async {
    final newStatus = !task.isCompleted;
    final updated = task.copyWith(isCompleted: newStatus);

    await _databaseHelper.updateTask(updated);

    if (task.id != null) {
      if (newStatus) {
        // Marked completed: cancel future notification
        await _notificationService.cancelTaskReminder(task.id!);
      } else {
        // Marked uncompleted: if reminder is still in the future, reschedule it
        if (updated.reminderTime != null &&
            updated.reminderTime!.isAfter(DateTime.now())) {
          await _notificationService.scheduleTaskReminder(updated);
        }
      }
    }

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: newStatus ? 'task_completed' : 'task_uncompleted',
        entityType: 'task',
        entityId: task.id,
        details: '${task.date}: ${task.title}',
        timestamp: DateTime.now(),
      ),
    );

    return updated;
  }

  Future<void> skipTask(Task task) async {
    if (task.id == null) return;
    final updated = task.copyWith(isSkipped: true);
    await _databaseHelper.updateTask(updated);
    await _notificationService.cancelTaskReminder(task.id!);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'task_skipped',
        entityType: 'task',
        entityId: task.id,
        details: '${task.date}: ${task.title}',
        timestamp: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECURRING TEMPLATES
  // ---------------------------------------------------------------------------

  Future<List<RecurringTaskTemplate>> getAllTemplates() async {
    return await _databaseHelper.getAllRecurringTemplates();
  }

  Future<RecurringTaskTemplate> addTemplate(
      RecurringTaskTemplate template) async {
    final id = await _databaseHelper.insertRecurringTemplate(template);
    final inserted = template.copyWith(id: id);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'template_created',
        entityType: 'template',
        entityId: id,
        details: template.title,
        timestamp: DateTime.now(),
      ),
    );

    return inserted;
  }

  Future<void> updateTemplate(RecurringTaskTemplate template) async {
    if (template.id == null) return;
    await _databaseHelper.updateRecurringTemplate(template);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'template_updated',
        entityType: 'template',
        entityId: template.id,
        details: template.title,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> deleteTemplate(int id) async {
    await _databaseHelper.deleteRecurringTemplate(id);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'template_deleted',
        entityType: 'template',
        entityId: id,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<int> reconcileRecurringOccurrences({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _databaseHelper.database;
    final recurrenceService = RecurrenceService(db);
    return await recurrenceService.generateOccurrences(from: from, to: to);
  }
}
