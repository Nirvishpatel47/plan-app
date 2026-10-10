import '../database/database_helper.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

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
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return await _databaseHelper.getTaskCountsForMonthPrefix(prefix);
  }

  Future<Task> addTask(Task task) async {
    final id = await _databaseHelper.insertTask(task);
    final insertedTask = task.copyWith(id: id);

    if (insertedTask.reminderTime != null && !insertedTask.isCompleted) {
      await _notificationService.scheduleTaskReminder(insertedTask);
    }

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
  }

  Future<void> deleteTask(int taskId) async {
    await _databaseHelper.deleteTask(taskId);
    await _notificationService.cancelTaskReminder(taskId);
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

    return updated;
  }
}
