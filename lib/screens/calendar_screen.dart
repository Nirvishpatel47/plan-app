import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../state/plan_notifier.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_view.dart';
import '../widgets/task_editor_dialog.dart';
import '../widgets/task_tile.dart';
import 'settings_screen.dart';

enum CalendarViewMode {
  taskList,
  dayTimeline,
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.taskList;

  void _openAddTask(BuildContext context, {String? prefilledBlock}) {
    final notifier = PlanScope.read(context);
    Task? initialTask;
    if (prefilledBlock != null) {
      final parts = prefilledBlock.split(' - ');
      initialTask = Task(
        title: '',
        date: notifier.selectedCalendarDateKey,
        createdAt: DateTime.now(),
        timeBlockStart: parts.isNotEmpty ? parts[0] : null,
        timeBlockEnd: parts.length > 1 ? parts[1] : null,
      );
    }

    TaskEditorDialog.show(
      context: context,
      initialDate: notifier.selectedCalendarDate,
      existingTask: initialTask,
      onSave: (task) async {
        try {
          await notifier.createTask(task);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Couldn't save task. Please try again."),
              ),
            );
          }
        }
      },
    );
  }

  void _openEditTask(BuildContext context, Task task) {
    final notifier = PlanScope.read(context);
    final previousReminder = task.reminderTime;
    TaskEditorDialog.show(
      context: context,
      existingTask: task,
      initialDate: notifier.selectedCalendarDate,
      onSave: (updatedTask) async {
        try {
          await notifier.updateTask(
            updatedTask,
            previousReminderTime: previousReminder,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Couldn't update task. Please try again."),
              ),
            );
          }
        }
      },
      onDelete: () => _confirmDelete(context, task),
    );
  }

  void _confirmDelete(BuildContext context, Task task) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '"${task.title}" will be permanently removed.',
          style: TextStyle(color: secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = PlanScope.read(context);
      try {
        await notifier.deleteTask(task.id!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't delete task. Please try again."),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = PlanScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    final isToday = Task.formatDateKey(notifier.selectedCalendarDate) ==
        Task.formatDateKey(notifier.today);
    final selectedDateLabel = isToday
        ? 'Today (${DateFormat('d MMM').format(notifier.selectedCalendarDate)})'
        : DateFormat('d MMMM y').format(notifier.selectedCalendarDate);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Settings action
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Calendar',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: primaryTextColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined, size: 22),
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  // Month navigation & date picker grid
                  CalendarView(
                    currentMonth: notifier.currentCalendarMonth,
                    selectedDate: notifier.selectedCalendarDate,
                    onMonthChanged: (m) => notifier.setCalendarMonth(m),
                    onDateSelected: (d) => notifier.selectCalendarDate(d),
                    monthTaskCounts: notifier.monthTaskCounts,
                  ),
                  const Divider(),
                  // Selected Date Subheader & View Mode Toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selected: $selectedDateLabel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        // Segmented toggle
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildModeButton(
                                icon: Icons.checklist,
                                tooltip: 'List view',
                                selected: _viewMode == CalendarViewMode.taskList,
                                onTap: () => setState(
                                    () => _viewMode = CalendarViewMode.taskList),
                                isDark: isDark,
                              ),
                              _buildModeButton(
                                icon: Icons.view_day_outlined,
                                tooltip: 'Day timeline / Time blocks',
                                selected: _viewMode == CalendarViewMode.dayTimeline,
                                onTap: () => setState(
                                    () => _viewMode = CalendarViewMode.dayTimeline),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _openAddTask(context),
                          tooltip: 'Add task for this date',
                          icon: const Icon(Icons.add, size: 24),
                          color: primaryTextColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (notifier.isLoadingCalendar)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              )
            else if (_viewMode == CalendarViewMode.taskList)
              if (notifier.selectedDateTasks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No tasks planned for this date.',
                            style: TextStyle(
                              fontSize: 15,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => _openAddTask(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add task'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final task = notifier.selectedDateTasks[index];
                      return Column(
                        children: [
                          TaskTile(
                            task: task,
                            onToggle: (_) async {
                              try {
                                await notifier.toggleTask(task);
                              } catch (_) {}
                            },
                            onEdit: () => _openEditTask(context, task),
                            onDelete: () async {
                              try {
                                await notifier.deleteTask(task.id!);
                              } catch (_) {}
                            },
                            onLogToTime: () async {
                              await notifier.logTaskToTimeEntry(task);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Logged "${task.title}" to Time Tracker'),
                                  ),
                                );
                              }
                            },
                          ),
                          const Divider(indent: 60, endIndent: 16),
                        ],
                      );
                    },
                    childCount: notifier.selectedDateTasks.length,
                  ),
                )
            else
              SliverToBoxAdapter(
                child: _buildDayTimelineView(
                  context,
                  notifier,
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                  surfaceColor,
                  isDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? (isDark ? AppTheme.darkBg : Colors.white)
              : (isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary),
        ),
      ),
    );
  }

  Widget _buildDayTimelineView(
    BuildContext context,
    PlanNotifier notifier,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
    Color surfaceColor,
    bool isDark,
  ) {
    final blockedTasks =
        notifier.selectedDateTasks.where((t) => t.hasTimeBlock).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(14, (i) {
          final hour = 8 + i; // 08:00 to 21:00
          final hourStr = '${hour.toString().padLeft(2, '0')}:00';
          final nextHourStr = '${(hour + 1).toString().padLeft(2, '0')}:00';

          final tasksInSlot = blockedTasks.where((t) {
            final startMins = TimeEntry.parseMinutes(t.timeBlockStart!);
            final slotMins = hour * 60;
            return startMins >= slotMins && startMins < slotMins + 60;
          }).toList();

          return InkWell(
            onTap: () {
              _openAddTask(context, prefilledBlock: '$hourStr - $nextHourStr');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      hourStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: tasksInSlot.isEmpty
                        ? Container(
                            height: 38,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color: borderColor.withValues(alpha: 0.5)),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: tasksInSlot.map((task) {
                              return InkWell(
                                onTap: () => _openEditTask(context, task),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: task.isCompleted
                                          ? borderColor
                                          : (isDark
                                              ? AppTheme.darkPrimary
                                              : AppTheme.lightPrimary),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        task.isCompleted
                                            ? Icons.check_circle_outline
                                            : Icons.schedule,
                                        size: 14,
                                        color: task.isCompleted
                                            ? secondaryTextColor
                                            : primaryTextColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${task.formattedTimeBlock} · ${task.title}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: task.isCompleted
                                                ? secondaryTextColor
                                                : primaryTextColor,
                                            decoration: task.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
