import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../repositories/settings_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/time_entry_repository.dart';
import '../services/notification_service.dart';

class PlanNotifier extends ChangeNotifier {
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;

  bool _isDisposed = false;

  PlanNotifier({
    TaskRepository? taskRepository,
    TimeEntryRepository? timeEntryRepository,
    SettingsRepository? settingsRepository,
    NotificationService? notificationService,
  })  : _taskRepository = taskRepository ?? TaskRepository(),
        _timeEntryRepository =
            timeEntryRepository ?? TimeEntryRepository(),
        _settingsRepository = settingsRepository ?? SettingsRepository(),
        _notificationService =
            notificationService ?? NotificationService();

  DateTime _today = DateTime.now();
  late DateTime _selectedCalendarDate;
  late DateTime _currentCalendarMonth;
  late DateTime _selectedTimeScreenDate;

  List<Task> _todayTasks = [];
  List<Task> _selectedDateTasks = [];
  Map<String, int> _monthTaskCounts = {};

  List<TimeEntry> _selectedDateTimeEntries = [];
  DailyTimeSummary? _dailyTimeSummary;

  List<RecurringTaskTemplate> _recurringTemplates = [];
  AppSettings _appSettings = const AppSettings();

  bool _isLoadingToday = true;
  bool _isLoadingCalendar = true;
  bool _isLoadingTime = true;
  bool _isLoadingSettings = true;

  DateTime get today => _today;
  DateTime get selectedCalendarDate => _selectedCalendarDate;
  DateTime get currentCalendarMonth => _currentCalendarMonth;
  DateTime get selectedTimeScreenDate => _selectedTimeScreenDate;

  List<Task> get todayTasks => List.unmodifiable(_todayTasks);
  List<Task> get selectedDateTasks => List.unmodifiable(_selectedDateTasks);
  Map<String, int> get monthTaskCounts => Map.unmodifiable(_monthTaskCounts);

  List<TimeEntry> get selectedDateTimeEntries =>
      List.unmodifiable(_selectedDateTimeEntries);
  DailyTimeSummary? get dailyTimeSummary => _dailyTimeSummary;

  List<RecurringTaskTemplate> get recurringTemplates =>
      List.unmodifiable(_recurringTemplates);
  AppSettings get appSettings => _appSettings;

  bool get isLoadingToday => _isLoadingToday;
  bool get isLoadingCalendar => _isLoadingCalendar;
  bool get isLoadingTime => _isLoadingTime;
  bool get isLoadingSettings => _isLoadingSettings;

  String get todayKey => Task.formatDateKey(_today);
  String get selectedCalendarDateKey =>
      Task.formatDateKey(_selectedCalendarDate);
  String get selectedTimeScreenDateKey =>
      Task.formatDateKey(_selectedTimeScreenDate);

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    _today = DateTime.now();
    _selectedCalendarDate = DateTime(_today.year, _today.month, _today.day);
    _currentCalendarMonth = DateTime(_today.year, _today.month, 1);
    _selectedTimeScreenDate = DateTime(_today.year, _today.month, _today.day);

    await _loadSettings();

    // Reconcile recurring tasks from 7 days ago to 14 days ahead
    try {
      await _taskRepository.reconcileRecurringOccurrences(
        from: _today.subtract(const Duration(days: 7)),
        to: _today.add(const Duration(days: 14)),
      );
    } catch (e) {
      debugPrint('Error reconciling recurring occurrences: $e');
    }

    await Future.wait([
      _loadTodayTasks(),
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
      _loadTimeEntriesForSelectedDate(),
      _loadTemplates(),
    ]);

    // Reschedule hourly reminders in background
    try {
      await _notificationService.syncHourlyReminders(_appSettings);
    } catch (_) {}
  }

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
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
      _loadTimeEntriesForSelectedDate(),
      _loadTemplates(),
      _loadSettings(),
    ]);
  }

  Future<void> _loadSettings() async {
    _isLoadingSettings = true;
    _safeNotify();
    try {
      _appSettings = await _settingsRepository.getSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoadingSettings = false;
      _safeNotify();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _appSettings = newSettings;
    _safeNotify();
    await _settingsRepository.saveSettings(newSettings);
    await _notificationService.syncHourlyReminders(newSettings);
    _updateDailySummary();
    _safeNotify();
  }

  Future<void> _loadTodayTasks() async {
    _isLoadingToday = true;
    _safeNotify();
    try {
      _todayTasks = await _taskRepository.getTasksForDate(todayKey);
    } catch (e) {
      debugPrint('Error loading today tasks: $e');
    } finally {
      _isLoadingToday = false;
      _safeNotify();
    }
  }

  Future<void> _loadCalendarDateTasks() async {
    _isLoadingCalendar = true;
    _safeNotify();
    try {
      _selectedDateTasks =
          await _taskRepository.getTasksForDate(selectedCalendarDateKey);
    } catch (e) {
      debugPrint('Error loading calendar date tasks: $e');
    } finally {
      _isLoadingCalendar = false;
      _safeNotify();
    }
  }

  Future<void> _loadMonthCounts(DateTime month) async {
    try {
      _monthTaskCounts =
          await _taskRepository.getTaskCountsForMonth(month.year, month.month);
      _safeNotify();
    } catch (e) {
      debugPrint('Error loading month counts: $e');
    }
  }

  Future<void> selectCalendarDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == _selectedCalendarDate) return;

    _selectedCalendarDate = normalized;

    if (date.year != _currentCalendarMonth.year ||
        date.month != _currentCalendarMonth.month) {
      _currentCalendarMonth = DateTime(date.year, date.month, 1);
      _loadMonthCounts(_currentCalendarMonth);
    }

    await _loadCalendarDateTasks();
  }

  Future<void> setCalendarMonth(DateTime month) async {
    _currentCalendarMonth = DateTime(month.year, month.month, 1);
    await _loadMonthCounts(_currentCalendarMonth);
  }

  // ---------------------------------------------------------------------------
  // TASK ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> createTask(Task task) async {
    await _taskRepository.addTask(task);
    await Future.wait([
      _loadTodayTasks(),
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  Future<void> updateTask(Task task, {DateTime? previousReminderTime}) async {
    await _taskRepository.updateTask(task,
        previousReminderTime: previousReminderTime);
    await Future.wait([
      _loadTodayTasks(),
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  Future<void> deleteTask(int taskId) async {
    await _taskRepository.deleteTask(taskId);
    await Future.wait([
      _loadTodayTasks(),
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  Future<void> toggleTask(Task task) async {
    final newCompleted = !task.isCompleted;
    final updatedTask = task.copyWith(isCompleted: newCompleted);

    _updateLocalTask(updatedTask);
    _safeNotify();

    try {
      await _taskRepository.toggleTaskCompleted(task);
      if (task.date == todayKey) {
        _todayTasks = await _taskRepository.getTasksForDate(todayKey);
      }
      if (task.date == selectedCalendarDateKey) {
        _selectedDateTasks =
            await _taskRepository.getTasksForDate(selectedCalendarDateKey);
      }
      _safeNotify();
    } catch (e) {
      await Future.wait([
        _loadTodayTasks(),
        _loadCalendarDateTasks(),
      ]);
      rethrow;
    }
  }

  Future<void> skipTask(Task task) async {
    await _taskRepository.skipTask(task);
    await Future.wait([
      _loadTodayTasks(),
      _loadCalendarDateTasks(),
      _loadMonthCounts(_currentCalendarMonth),
    ]);
  }

  void _updateLocalTask(Task updated) {
    if (updated.date == todayKey) {
      final index = _todayTasks.indexWhere((t) => t.id == updated.id);
      if (index != -1) _todayTasks[index] = updated;
    }
    if (updated.date == selectedCalendarDateKey) {
      final index = _selectedDateTasks.indexWhere((t) => t.id == updated.id);
      if (index != -1) _selectedDateTasks[index] = updated;
    }
  }

  // ---------------------------------------------------------------------------
  // TIME SCREEN & ENTRIES
  // ---------------------------------------------------------------------------

  Future<void> _loadTimeEntriesForSelectedDate() async {
    _isLoadingTime = true;
    _safeNotify();
    try {
      _selectedDateTimeEntries = await _timeEntryRepository
          .getTimeEntriesForDate(selectedTimeScreenDateKey);
      _updateDailySummary();
    } catch (e) {
      debugPrint('Error loading time entries: $e');
    } finally {
      _isLoadingTime = false;
      _safeNotify();
    }
  }

  void _updateDailySummary() {
    _dailyTimeSummary = _timeEntryRepository.calculateSummary(
      _selectedDateTimeEntries,
      windowStart: _appSettings.trackingWindowStart,
      windowEnd: _appSettings.trackingWindowEnd,
    );
  }

  Future<void> selectTimeScreenDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == _selectedTimeScreenDate) return;
    _selectedTimeScreenDate = normalized;
    await _loadTimeEntriesForSelectedDate();
  }

  Future<void> goToTodayTimeScreen() async {
    await selectTimeScreenDate(_today);
  }

  Future<void> previousDayTimeScreen() async {
    await selectTimeScreenDate(
        _selectedTimeScreenDate.subtract(const Duration(days: 1)));
  }

  Future<void> nextDayTimeScreen() async {
    await selectTimeScreenDate(
        _selectedTimeScreenDate.add(const Duration(days: 1)));
  }

  Future<void> createTimeEntry(TimeEntry entry) async {
    await _timeEntryRepository.addTimeEntry(entry);
    await _loadTimeEntriesForSelectedDate();
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    await _timeEntryRepository.updateTimeEntry(entry);
    await _loadTimeEntriesForSelectedDate();
  }

  Future<void> deleteTimeEntry(int id) async {
    await _timeEntryRepository.deleteTimeEntry(id);
    await _loadTimeEntriesForSelectedDate();
  }

  /// Creates a time log entry directly from a scheduled task with prefilled values
  Future<void> logTaskToTimeEntry(Task task) async {
    final start = task.timeBlockStart ?? _appSettings.startOfDay;
    // Default 1 hour duration if end is missing
    String end = task.timeBlockEnd ?? '';
    if (end.isEmpty) {
      final startMins = TimeEntry.parseMinutes(start);
      end = TimeEntry.formatMinutes((startMins + 60).clamp(0, 1439));
    }

    final entry = TimeEntry(
      date: task.date,
      startTime: start,
      endTime: end,
      activityTitle: task.title,
      linkedTaskId: task.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await createTimeEntry(entry);
  }

  // ---------------------------------------------------------------------------
  // RECURRING TEMPLATES
  // ---------------------------------------------------------------------------

  Future<void> _loadTemplates() async {
    try {
      _recurringTemplates = await _taskRepository.getAllTemplates();
      _safeNotify();
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  Future<void> createRecurringTemplate(RecurringTaskTemplate template) async {
    await _taskRepository.addTemplate(template);
    // Reconcile occurrences immediately for next 14 days
    await _taskRepository.reconcileRecurringOccurrences(
      from: _today,
      to: _today.add(const Duration(days: 14)),
    );
    await refreshAll();
  }

  Future<void> updateRecurringTemplate(RecurringTaskTemplate template) async {
    await _taskRepository.updateTemplate(template);
    await _taskRepository.reconcileRecurringOccurrences(
      from: _today,
      to: _today.add(const Duration(days: 14)),
    );
    await refreshAll();
  }

  Future<void> deleteRecurringTemplate(int id) async {
    await _taskRepository.deleteTemplate(id);
    await refreshAll();
  }
}
