import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class TaskEditorDialog extends StatefulWidget {
  final Task? existingTask;
  final DateTime initialDate;
  final ValueChanged<Task> onSave;
  final VoidCallback? onDelete;

  const TaskEditorDialog({
    super.key,
    this.existingTask,
    required this.initialDate,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    Task? existingTask,
    required DateTime initialDate,
    required ValueChanged<Task> onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskEditorDialog(
        existingTask: existingTask,
        initialDate: initialDate,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  late final TextEditingController _titleController;
  late DateTime _selectedDate;
  TimeOfDay? _reminderTimeOfDay;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingTask?.title ?? '');

    if (widget.existingTask != null) {
      _selectedDate = widget.existingTask!.dateAsDateTime;
      if (widget.existingTask!.reminderTime != null) {
        _reminderTimeOfDay =
            TimeOfDay.fromDateTime(widget.existingTask!.reminderTime!);
      }
    } else {
      _selectedDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickReminderTime() async {
    // Only request permission when the user actually taps to set a reminder
    final granted = await NotificationService().requestPermissionIfNeeded();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _permissionDenied = true;
      });
    }

    final initialTime = _reminderTimeOfDay ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      setState(() {
        _reminderTimeOfDay = picked;
      });
    }
  }

  void _clearReminder() {
    setState(() {
      _reminderTimeOfDay = null;
      _permissionDenied = false;
    });
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    DateTime? fullReminderDateTime;
    if (_reminderTimeOfDay != null) {
      fullReminderDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _reminderTimeOfDay!.hour,
        _reminderTimeOfDay!.minute,
      );
    }

    final dateKey = Task.formatDateKey(_selectedDate);

    final Task task;
    if (widget.existingTask != null) {
      task = widget.existingTask!.copyWith(
        title: title,
        date: dateKey,
        reminderTime: fullReminderDateTime,
        clearReminder: fullReminderDateTime == null,
      );
    } else {
      task = Task(
        title: title,
        date: dateKey,
        reminderTime: fullReminderDateTime,
        createdAt: DateTime.now(),
      );
    }

    widget.onSave(task);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final primaryTextColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final isEditing = widget.existingTask != null;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final isToday = Task.formatDateKey(_selectedDate) ==
        Task.formatDateKey(DateTime.now());
    final dateDisplay = isToday
        ? 'Today (${DateFormat.MMMd().format(_selectedDate)})'
        : DateFormat.yMMMd().format(_selectedDate);

    return Container(
      margin: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEditing ? 'Edit Task' : 'Add Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 14),
            // Title input
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(color: primaryTextColor, fontSize: 16),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
              ),
              onSubmitted: (_) => _handleSave(),
            ),
            const SizedBox(height: 12),
            // Date row
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: secondaryTextColor),
                    const SizedBox(width: 10),
                    Text(
                      'Date: $dateDisplay',
                      style: TextStyle(color: primaryTextColor, fontSize: 14),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: secondaryTextColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Reminder row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm, size: 18, color: secondaryTextColor),
                  const SizedBox(width: 10),
                  Text(
                    'Reminder: ',
                    style: TextStyle(color: primaryTextColor, fontSize: 14),
                  ),
                  const Spacer(),
                  if (_reminderTimeOfDay == null)
                    TextButton(
                      onPressed: _pickReminderTime,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(48, 36),
                      ),
                      child: Text(
                        'Off / Set time',
                        style: TextStyle(color: secondaryTextColor, fontSize: 13),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _pickReminderTime,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text(
                              _reminderTimeOfDay!.format(context),
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Remove reminder',
                          onPressed: _clearReminder,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (_permissionDenied) ...[
              const SizedBox(height: 6),
              Text(
                'Notification permission was denied. Task will save without reminder.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                if (isEditing && widget.onDelete != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDelete!();
                    },
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.shade600),
                    label: Text(
                      'Delete',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: secondaryTextColor)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppTheme.darkPrimary
                        : AppTheme.lightPrimary,
                    foregroundColor:
                        isDark ? AppTheme.darkBg : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
