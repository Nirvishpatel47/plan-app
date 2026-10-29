import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLogToTime;
  final VoidCallback? onSkip;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onLogToTime,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final completedTextColor =
        isDark ? AppTheme.darkTextCompleted : AppTheme.lightTextCompleted;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade700,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
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
      },
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: () => onToggle(!task.isCompleted),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: task.isCompleted,
                  onChanged: onToggle,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  activeColor:
                      isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
                ),
              ),
              const SizedBox(width: 12),
              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        color: task.isCompleted
                            ? completedTextColor
                            : primaryTextColor,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: completedTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Scheduled time block badge
                        if (task.hasTimeBlock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule,
                                    size: 11, color: secondaryTextColor),
                                const SizedBox(width: 3),
                                Text(
                                  task.formattedTimeBlock!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: task.isCompleted
                                        ? completedTextColor
                                        : primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Reminder time badge
                        if (task.reminderTime != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alarm,
                                size: 12,
                                color: task.isCompleted
                                    ? completedTextColor
                                    : secondaryTextColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat.jm().format(task.reminderTime!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: task.isCompleted
                                      ? completedTextColor
                                      : secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        // Recurring template indicator
                        if (task.recurringTemplateId != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 12,
                                color: task.isCompleted
                                    ? completedTextColor
                                    : secondaryTextColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Habit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick action: log to time tracking
              if (onLogToTime != null)
                IconButton(
                  icon: const Icon(Icons.add_chart_outlined, size: 18),
                  tooltip: 'Log to Time Tracker',
                  color: secondaryTextColor,
                  onPressed: onLogToTime,
                  visualDensity: VisualDensity.compact,
                ),
              // Dedicated edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit task',
                color: secondaryTextColor,
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
