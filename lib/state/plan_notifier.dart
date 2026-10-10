import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

class PlanNotifier extends ChangeNotifier {
  final TaskRepository _repository;

  PlanNotifier({TaskRepository? repository})
      : _repository = repository ?? TaskRepository();

  DateTime _today = DateTime.now();
  late DateTime _selectedCalendarDate;
  late DateTime _currentCalendarMonth;

  List<Task> _todayTasks = [];
  List<Task> _selectedDateTasks = [];
  Map<String, int> _monthTaskCounts = {};

  bool _isLoadingToday = true;
  bool _isLoadingCalendar = true;

  DateTime get today => _today;
  DateTime get selectedCalendarDate => _selectedCalendarDate;
  DateTime get currentCalendarMonth => _currentCalendarMonth;

  List<Task> get todayTasks => List.unmodifiable(_todayTasks);
  List<Task> get selectedDateTasks => List.unmodifiable(_selectedDateTasks);
  Map<String, int> get monthTaskCounts => Map.unmodifiable(_monthTaskCounts);

  bool get isLoadingToday => _isLoadingToday;
  bool get isLoadingCalendar => _isLoadingCalendar;

  String get todayKey => Task.formatDateKey(_today);
  String get selectedDateKey => Task.formatDateKey(_selectedCalendarDate);

  Future<void> initialize() async {
    _today = DateTime.now();
    _selectedCalendarDate = DateTime(_today.year, _today.month, _today.day);
    _currentCalendarMonth = DateTime(_today.year, _today.month, 1);

    await Future.wait([
      _loadTodayTasks(),
      _loadSelectedDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  /// Checks if day changed (e.g. past midnight) and refreshes if needed
  void checkDayBoundary() {
    final now = DateTime.now();
    if (now.year != _today.year ||
        now.month != _today.month ||
        now.day != _today.day) {
      _today = now;
      refreshAll();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      _loadTodayTasks(),
      _loadSelectedDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  Future<void> _loadTodayTasks() async {
    _isLoadingToday = true;
    notifyListeners();

    try {
      _todayTasks = await _repository.getTasksForDate(todayKey);
    } catch (e) {
      debugPrint('Error loading today tasks: $e');
    } finally {
      _isLoadingToday = false;
      notifyListeners();
    }
  }

  Future<void> _loadSelectedDateTasks() async {
    _isLoadingCalendar = true;
    notifyListeners();

    try {
      _selectedDateTasks =
          await _repository.getTasksForDate(selectedDateKey);
    } catch (e) {
      debugPrint('Error loading calendar date tasks: $e');
    } finally {
      _isLoadingCalendar = false;
      notifyListeners();
    }
  }

  Future<void> _loadMonthCounts(DateTime month) async {
    try {
      _monthTaskCounts =
          await _repository.getTaskCountsForMonth(month.year, month.month);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading month counts: $e');
    }
  }

  Future<void> selectCalendarDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == _selectedCalendarDate) return;

    _selectedCalendarDate = normalized;

    // If month changed as well, update month counts
    if (date.year != _currentCalendarMonth.year ||
        date.month != _currentCalendarMonth.month) {
      _currentCalendarMonth = DateTime(date.year, date.month, 1);
      _loadMonthCounts(_currentCalendarMonth);
    }

    await _loadSelectedDateTasks();
  }

  Future<void> setCalendarMonth(DateTime month) async {
    _currentCalendarMonth = DateTime(month.year, month.month, 1);
    await _loadMonthCounts(_currentCalendarMonth);
  }

  Future<void> createTask(Task task) async {
    try {
      await _repository.addTask(task);
      await refreshAll();
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task task, {DateTime? previousReminderTime}) async {
    try {
      await _repository.updateTask(task,
          previousReminderTime: previousReminderTime);
      await refreshAll();
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(int taskId) async {
    try {
      await _repository.deleteTask(taskId);
      await refreshAll();
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  Future<void> toggleTask(Task task) async {
    // Optimistic UI update
    final newCompleted = !task.isCompleted;
    final updatedTask = task.copyWith(isCompleted: newCompleted);

    _updateLocalTask(updatedTask);
    notifyListeners();

    try {
      await _repository.toggleTaskCompleted(task);
      // Reload to ensure ordering and exact DB synchronization
      if (task.date == todayKey) {
        _todayTasks = await _repository.getTasksForDate(todayKey);
      }
      if (task.date == selectedDateKey) {
        _selectedDateTasks = await _repository.getTasksForDate(selectedDateKey);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling task: $e');
      // Rollback on error
      await refreshAll();
      rethrow;
    }
  }

  void _updateLocalTask(Task updated) {
    if (updated.date == todayKey) {
      final index = _todayTasks.indexWhere((t) => t.id == updated.id);
      if (index != -1) {
        _todayTasks[index] = updated;
      }
    }
    if (updated.date == selectedDateKey) {
      final index = _selectedDateTasks.indexWhere((t) => t.id == updated.id);
      if (index != -1) {
        _selectedDateTasks[index] = updated;
      }
    }
  }
}
