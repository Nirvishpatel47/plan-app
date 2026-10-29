import 'package:flutter/material.dart';
import '../models/recurring_task_template.dart';
import '../models/task.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';

class RecurringTasksScreen extends StatelessWidget {
  const RecurringTasksScreen({super.key});

  void _openTemplateEditor(BuildContext context,
      {RecurringTaskTemplate? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringTemplateEditorDialog(existing: existing),
    );
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

    final templates = notifier.recurringTemplates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Tasks & Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add habit template',
            onPressed: () => _openTemplateEditor(context),
          ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 40, color: secondaryTextColor),
                  const SizedBox(height: 12),
                  Text(
                    'No recurring tasks configured.',
                    style: TextStyle(fontSize: 16, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openTemplateEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Habit Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.darkPrimary
                          : AppTheme.lightPrimary,
                      foregroundColor:
                          isDark ? AppTheme.darkBg : Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  template.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: template.isPaused
                                        ? secondaryTextColor
                                        : primaryTextColor,
                                  ),
                                ),
                                if (template.isPaused) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Paused',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _buildPatternSummary(template),
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                            if (template.preferredStartTime != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Time block: ${template.preferredStartTime}–${template.preferredEndTime ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          template.isPaused
                              ? Icons.play_arrow_outlined
                              : Icons.pause_outlined,
                          size: 20,
                        ),
                        tooltip: template.isPaused ? 'Resume' : 'Pause',
                        onPressed: () async {
                          await notifier.updateRecurringTemplate(
                            template.copyWith(isPaused: !template.isPaused),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit template',
                        onPressed: () =>
                            _openTemplateEditor(context, existing: template),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _buildPatternSummary(RecurringTaskTemplate t) {
    switch (t.recurrenceType) {
      case RecurrenceType.daily:
        return 'Every day';
      case RecurrenceType.weekdays:
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayNames = t.weekdays.map((w) => days[w - 1]).join(', ');
        return dayNames.isEmpty ? 'Selected weekdays' : dayNames;
      case RecurrenceType.everyNDays:
        return 'Every ${t.everyNDays ?? 1} days';
      case RecurrenceType.customCycle:
        return '${t.cycleActiveDays ?? 4} active days / ${t.cycleRestDays ?? 1} rest day cycle';
    }
  }
}

class _RecurringTemplateEditorDialog extends StatefulWidget {
  final RecurringTaskTemplate? existing;

  const _RecurringTemplateEditorDialog({this.existing});

  @override
  State<_RecurringTemplateEditorDialog> createState() =>
      _RecurringTemplateEditorDialogState();
}

class _RecurringTemplateEditorDialogState
    extends State<_RecurringTemplateEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _everyNDaysController;
  late final TextEditingController _activeDaysController;
  late final TextEditingController _restDaysController;
  late final TextEditingController _timeBlockController;

  late RecurrenceType _recurrenceType;
  late List<int> _selectedWeekdays;
  late DateTime _startDate;
  DateTime? _endDate;
  DateTime? _cycleStartDate;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleController = TextEditingController(text: ex?.title ?? '');
    _descriptionController =
        TextEditingController(text: ex?.description ?? '');
    _everyNDaysController =
        TextEditingController(text: ex?.everyNDays?.toString() ?? '2');
    _activeDaysController =
        TextEditingController(text: ex?.cycleActiveDays?.toString() ?? '4');
    _restDaysController =
        TextEditingController(text: ex?.cycleRestDays?.toString() ?? '1');
    _timeBlockController = TextEditingController(
      text: ex?.preferredStartTime != null
          ? '${ex!.preferredStartTime} - ${ex.preferredEndTime ?? ''}'
          : '',
    );

    _recurrenceType = ex?.recurrenceType ?? RecurrenceType.daily;
    _selectedWeekdays = ex?.weekdays.toList() ?? [1, 2, 3, 4, 5]; // Mon-Fri default
    _startDate = ex != null ? Task.parseDateKey(ex.startDate) : DateTime.now();
    _endDate = ex?.endDate != null ? Task.parseDateKey(ex!.endDate!) : null;
    _cycleStartDate = ex?.cycleStartDate != null
        ? Task.parseDateKey(ex!.cycleStartDate!)
        : _startDate;
    _isPaused = ex?.isPaused ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _everyNDaysController.dispose();
    _activeDaysController.dispose();
    _restDaysController.dispose();
    _timeBlockController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final notifier = PlanScope.read(context);

    String? blockStart;
    String? blockEnd;
    if (_timeBlockController.text.trim().isNotEmpty) {
      final parts = _timeBlockController.text.split(RegExp(r'\s*-\s*'));
      if (parts.length == 2) {
        blockStart = parts[0].trim();
        blockEnd = parts[1].trim();
      }
    }

    final template = RecurringTaskTemplate(
      id: widget.existing?.id,
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      recurrenceType: _recurrenceType,
      weekdays: _selectedWeekdays,
      everyNDays: int.tryParse(_everyNDaysController.text.trim()) ?? 2,
      cycleActiveDays: int.tryParse(_activeDaysController.text.trim()) ?? 4,
      cycleRestDays: int.tryParse(_restDaysController.text.trim()) ?? 1,
      cycleStartDate: _cycleStartDate != null
          ? Task.formatDateKey(_cycleStartDate!)
          : null,
      startDate: Task.formatDateKey(_startDate),
      endDate: _endDate != null ? Task.formatDateKey(_endDate!) : null,
      preferredStartTime: blockStart,
      preferredEndTime: blockEnd,
      isPaused: _isPaused,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.existing != null) {
      await notifier.updateRecurringTemplate(template);
    } else {
      await notifier.createRecurringTemplate(template);
    }

    if (mounted) Navigator.of(context).pop();
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
    final viewInsets = MediaQuery.of(context).viewInsets;

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                widget.existing != null ? 'Edit Habit' : 'New Habit Template',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                style: TextStyle(color: primaryTextColor, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Habit Title',
                  hintText: 'e.g. Exercise, Reading, Programming, Japanese',
                ),
              ),
              const SizedBox(height: 12),
              // Recurrence Pattern Dropdown
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrenceType,
                decoration: const InputDecoration(labelText: 'Repeat Pattern'),
                dropdownColor: surfaceColor,
                items: RecurrenceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName,
                        style: TextStyle(color: primaryTextColor)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _recurrenceType = val);
                },
              ),
              const SizedBox(height: 12),
              // Pattern Specific Options
              if (_recurrenceType == RecurrenceType.weekdays) ...[
                const SizedBox(height: 6),
                Text('Select Days:',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _weekdayChip(1, 'Mon'),
                    _weekdayChip(2, 'Tue'),
                    _weekdayChip(3, 'Wed'),
                    _weekdayChip(4, 'Thu'),
                    _weekdayChip(5, 'Fri'),
                    _weekdayChip(6, 'Sat'),
                    _weekdayChip(7, 'Sun'),
                  ],
                ),
              ] else if (_recurrenceType == RecurrenceType.everyNDays) ...[
                TextField(
                  controller: _everyNDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Interval (Days)',
                    hintText: 'e.g. 2, 3',
                  ),
                ),
              ] else if (_recurrenceType == RecurrenceType.customCycle) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _activeDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Active Days',
                          hintText: '4',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _restDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Rest Days',
                          hintText: '1',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Time block range
              TextField(
                controller: _timeBlockController,
                decoration: const InputDecoration(
                  labelText: 'Default Time Block (optional)',
                  hintText: 'e.g. 09:00 - 10:00',
                ),
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  if (widget.existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final notifier = PlanScope.read(context);
                        await notifier.deleteRecurringTemplate(widget.existing!.id!);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red.shade600),
                      label: Text('Delete',
                          style: TextStyle(color: Colors.red.shade600)),
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
                    child: Text(widget.existing != null ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekdayChip(int dayIndex, String label) {
    final isSelected = _selectedWeekdays.contains(dayIndex);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(dayIndex);
          } else {
            _selectedWeekdays.remove(dayIndex);
          }
        });
      },
    );
  }
}
