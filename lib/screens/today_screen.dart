import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/task_editor_dialog.dart';
import '../widgets/task_tile.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  void _openAddTask(BuildContext context) {
    final notifier = PlanScope.read(context);
    TaskEditorDialog.show(
      context: context,
      initialDate: notifier.today,
      onSave: (task) async {
        try {
          await notifier.createTask(task);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't save task. Please try again.")),
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
      initialDate: notifier.today,
      onSave: (updatedTask) async {
        try {
          await notifier.updateTask(
            updatedTask,
            previousReminderTime: previousReminder,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't update task. Please try again.")),
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
            const SnackBar(content: Text("Couldn't delete task. Please try again.")),
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

    final formattedDate = DateFormat('EEEE, d MMMM').format(notifier.today);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clean Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _openAddTask(context),
                    tooltip: 'Add task',
                    icon: const Icon(Icons.add, size: 28),
                    color: primaryTextColor,
                  ),
                ],
              ),
            ),
            const Divider(),
            // Tasks List
            Expanded(
              child: notifier.isLoadingToday
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : notifier.todayTasks.isEmpty
                      ? _buildEmptyState(context, secondaryTextColor)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: notifier.todayTasks.length,
                          separatorBuilder: (context, index) => const Divider(
                            indent: 60,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final task = notifier.todayTasks[index];
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
                                        content: Text(
                                          "Couldn't delete task.",
                                        ),
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
            'No tasks for today.',
            style: TextStyle(
              fontSize: 16,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
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
