import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_view.dart';
import '../widgets/task_editor_dialog.dart';
import '../widgets/task_tile.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  void _openAddTask(BuildContext context) {
    final notifier = PlanScope.read(context);
    TaskEditorDialog.show(
      context: context,
      initialDate: notifier.selectedCalendarDate,
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

    final isToday = Task.formatDateKey(notifier.selectedCalendarDate) ==
        Task.formatDateKey(notifier.today);
    final selectedDateLabel = isToday
        ? 'Today (${DateFormat('d MMM').format(notifier.selectedCalendarDate)})'
        : DateFormat('d MMMM y').format(notifier.selectedCalendarDate);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
              child: Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: primaryTextColor,
                ),
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
            // Selected Date Subheader & Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected: $selectedDateLabel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openAddTask(context),
                    tooltip: 'Add task for this date',
                    icon: const Icon(Icons.add, size: 24),
                    color: primaryTextColor,
                  ),
                ],
              ),
            ),
            // Tasks for selected date
            Expanded(
              child: notifier.isLoadingCalendar
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : notifier.selectedDateTasks.isEmpty
                      ? _buildEmptyState(context, secondaryTextColor)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: notifier.selectedDateTasks.length,
                          separatorBuilder: (context, index) => const Divider(
                            indent: 60,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final task = notifier.selectedDateTasks[index];
                            return TaskTile(
                              task: task,
                              onToggle: (_) async {
                                try {
                                  await notifier.toggleTask(task);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Couldn't update task status.",
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              onEdit: () => _openEditTask(context, task),
                              onDelete: () async {
                                try {
                                  await notifier.deleteTask(task.id!);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Couldn't delete task."),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color secondaryTextColor) {
    return Center(
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
    );
  }
}
