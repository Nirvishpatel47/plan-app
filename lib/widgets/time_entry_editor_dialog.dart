import 'package:flutter/material.dart';
import '../models/time_entry.dart';
import '../services/time_range_parser.dart';
import '../theme/app_theme.dart';

class TimeEntryEditorDialog extends StatefulWidget {
  final TimeEntry? existingEntry;
  final String date;
  final List<TimeEntry> existingDayEntries;
  final String defaultStartOfDay;
  final String? initialTimeRange;
  final ValueChanged<TimeEntry> onSave;
  final VoidCallback? onDelete;

  const TimeEntryEditorDialog({
    super.key,
    this.existingEntry,
    required this.date,
    this.existingDayEntries = const [],
    this.defaultStartOfDay = '08:00',
    this.initialTimeRange,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    TimeEntry? existingEntry,
    required String date,
    List<TimeEntry> existingDayEntries = const [],
    String defaultStartOfDay = '08:00',
    String? initialTimeRange,
    required ValueChanged<TimeEntry> onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimeEntryEditorDialog(
        existingEntry: existingEntry,
        date: date,
        existingDayEntries: existingDayEntries,
        defaultStartOfDay: defaultStartOfDay,
        initialTimeRange: initialTimeRange,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<TimeEntryEditorDialog> createState() => _TimeEntryEditorDialogState();
}

class _TimeEntryEditorDialogState extends State<TimeEntryEditorDialog> {
  late final TextEditingController _timeRangeController;
  late final TextEditingController _activityController;
  late final TextEditingController _notesController;

  String? _parseError;
  String? _resolvedPreview;

  @override
  void initState() {
    super.initState();
    String initialTimeText = '';
    if (widget.existingEntry != null) {
      initialTimeText =
          '${widget.existingEntry!.startTime} - ${widget.existingEntry!.endTime}';
    } else if (widget.initialTimeRange != null) {
      initialTimeText = widget.initialTimeRange!;
    } else if (widget.existingDayEntries.isNotEmpty) {
      int maxEnd = 0;
      for (final e in widget.existingDayEntries) {
        if (e.endMinutes > maxEnd) maxEnd = e.endMinutes;
      }
      final startStr = TimeEntry.formatMinutes(maxEnd);
      final endStr = TimeEntry.formatMinutes((maxEnd + 60).clamp(0, 1439));
      initialTimeText = '$startStr - $endStr';
    } else {
      initialTimeText = '08:00 - 09:00';
    }

    _timeRangeController = TextEditingController(text: initialTimeText);
    _activityController =
        TextEditingController(text: widget.existingEntry?.activityTitle ?? '');
    _notesController =
        TextEditingController(text: widget.existingEntry?.notes ?? '');

    _validateTime();
  }

  @override
  void dispose() {
    _timeRangeController.dispose();
    _activityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateTime() {
    final text = _timeRangeController.text;
    final parsed = TimeRangeParser.parse(
      text,
      existingEntries: widget.existingDayEntries
          .where((e) => e.id != widget.existingEntry?.id)
          .toList(),
      defaultStartOfDay: widget.defaultStartOfDay,
    );

    setState(() {
      if (parsed.isValid) {
        _parseError = null;
        _resolvedPreview = '${parsed.startTime} – ${parsed.endTime}';
      } else {
        _parseError = parsed.errorMessage;
        _resolvedPreview = null;
      }
    });
  }

  Future<void> _pickTimesWithPicker() async {
    final now = TimeOfDay.now();
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'Select Start Time',
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (pickedStart.hour + 1) % 24,
        minute: pickedStart.minute,
      ),
      helpText: 'Select End Time',
    );
    if (pickedEnd == null || !mounted) return;

    final startStr =
        '${pickedStart.hour.toString().padLeft(2, '0')}:${pickedStart.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${pickedEnd.hour.toString().padLeft(2, '0')}:${pickedEnd.minute.toString().padLeft(2, '0')}';

    _timeRangeController.text = '$startStr - $endStr';
    _validateTime();
  }

  void _handleSave() {
    _validateTime();
    if (_parseError != null) return;

    final activity = _activityController.text.trim();
    if (activity.isEmpty) {
      setState(() {
        _parseError = 'Please enter an activity title';
      });
      return;
    }

    final parsed = TimeRangeParser.parse(
      _timeRangeController.text,
      existingEntries: widget.existingDayEntries
          .where((e) => e.id != widget.existingEntry?.id)
          .toList(),
      defaultStartOfDay: widget.defaultStartOfDay,
    );

    if (!parsed.isValid) return;

    final notesText = _notesController.text.trim();

    final TimeEntry entry;
    if (widget.existingEntry != null) {
      entry = widget.existingEntry!.copyWith(
        startTime: parsed.startTime,
        endTime: parsed.endTime,
        activityTitle: activity,
        notes: notesText.isEmpty ? null : notesText,
        updatedAt: DateTime.now(),
      );
    } else {
      entry = TimeEntry(
        date: widget.date,
        startTime: parsed.startTime!,
        endTime: parsed.endTime!,
        activityTitle: activity,
        notes: notesText.isEmpty ? null : notesText,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    widget.onSave(entry);
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

    final isEditing = widget.existingEntry != null;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      margin: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Time Log' : 'Log Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                if (_resolvedPreview != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _resolvedPreview!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _timeRangeController,
                            style: TextStyle(color: primaryTextColor, fontSize: 16),
                            decoration: const InputDecoration(
                              labelText: 'Time Range (e.g. 11:00 - 11:30)',
                              hintText: '11:00 - 11:30',
                            ),
                            onChanged: (_) => _validateTime(),
                            onSubmitted: (_) => _handleSave(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _pickTimesWithPicker,
                          icon: const Icon(Icons.access_time),
                          tooltip: 'Select using clock picker',
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                    if (_parseError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _parseError!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _activityController,
                      autofocus: !isEditing,
                      style: TextStyle(color: primaryTextColor, fontSize: 16),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Activity',
                        hintText: 'Reading, Programming, Exercise...',
                      ),
                      onSubmitted: (_) => _handleSave(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      style: TextStyle(color: primaryTextColor, fontSize: 14),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Add details if needed',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                  child: Text(isEditing ? 'Save' : 'Log Time'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
