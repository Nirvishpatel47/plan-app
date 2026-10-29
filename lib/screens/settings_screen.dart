import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';
import 'recurring_tasks_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationStatus _notificationStatus = NotificationStatus.permissionNeeded;
  bool _testingNotification = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await NotificationService().checkStatus();
    if (mounted) {
      setState(() => _notificationStatus = status);
    }
  }

  Future<void> _handleTestNotification() async {
    setState(() => _testingNotification = true);
    final success = await NotificationService().sendTestNotification();
    await _checkNotificationStatus();
    if (!mounted) return;
    setState(() => _testingNotification = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Test notification sent! Check your notification panel.'
              : 'Could not send test notification. Check permissions in system settings.',
        ),
      ),
    );
  }

  Future<void> _handleExportData() async {
    try {
      final backupJson = await BackupService().exportBackupJson();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/plan_backup_$timestamp.json');
      await file.writeAsString(backupJson);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Plan Data Backup $timestamp',
          text: 'Backup of Plan tasks, habits, and time tracker records.',
        ),
      );

      if (mounted) {
        PlanScope.read(context).refreshAll();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup exported successfully (${file.path})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _handleImportData() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (pickedFiles.isEmpty || pickedFiles.first.path == null) return;

      final file = File(pickedFiles.first.path!);
      final jsonString = await file.readAsString();

      final validation = BackupService().validateBackupJson(jsonString);

      if (!mounted) return;

      if (!validation.isValid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Invalid Backup File'),
            content: Text(validation.errorMessage ?? 'Unable to parse file.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show Import Options Dialog
      _showImportOptionsDialog(validation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showImportOptionsDialog(ImportValidationResult validation) {
    ImportMode selectedMode = ImportMode.merge;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final notifier = PlanScope.read(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Import Backup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found in backup:\n• ${validation.tasksCount} tasks\n• ${validation.templatesCount} habit templates\n• ${validation.timeEntriesCount} time entries',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text('Select Import Mode:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                RadioGroup<ImportMode>(
                  groupValue: selectedMode,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMode = val);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<ImportMode>(
                        value: ImportMode.merge,
                        title: const Text('Merge'),
                        subtitle: const Text('Add missing records without deleting current data'),
                      ),
                      RadioListTile<ImportMode>(
                        value: ImportMode.restoreReplace,
                        title: const Text('Restore / Replace'),
                        subtitle: const Text('Warning: Replaces current data with backup'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await BackupService().importBackup(validation, mode: selectedMode);
                    await notifier.refreshAll();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Data imported successfully!')),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Import error: $e')),
                    );
                  }
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = PlanScope.of(context);
    final settings = notifier.appSettings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ROUTINE SECTION
          _buildSectionHeader('Routine', secondaryTextColor),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Recurring Tasks & Habits'),
                  subtitle: Text(
                    '${notifier.recurringTemplates.length} configured',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecurringTasksScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Default Start of Day'),
                  trailing: Text(settings.startOfDay,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: primaryTextColor)),
                  onTap: () async {
                    final parts = settings.startOfDay.split(':');
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.tryParse(parts[0]) ?? 8,
                        minute: int.tryParse(parts[1]) ?? 0,
                      ),
                    );
                    if (picked != null) {
                      final timeStr =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      notifier.updateSettings(
                          settings.copyWith(startOfDay: timeStr));
                    }
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.timelapse_outlined),
                  title: const Text('Daily Tracking Window'),
                  subtitle: Text(
                    '${settings.trackingWindowStart} – ${settings.trackingWindowEnd}',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    // Quick window editor
                    final pickedStart = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 8, minute: 0),
                      helpText: 'Tracking Window Start',
                    );
                    if (pickedStart == null || !context.mounted) return;

                    final pickedEnd = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 20, minute: 0),
                      helpText: 'Tracking Window End',
                    );
                    if (pickedEnd == null || !context.mounted) return;

                    final startStr =
                        '${pickedStart.hour.toString().padLeft(2, '0')}:00';
                    final endStr =
                        '${pickedEnd.hour.toString().padLeft(2, '0')}:00';
                    notifier.updateSettings(
                      settings.copyWith(
                        trackingWindowStart: startStr,
                        trackingWindowEnd: endStr,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // NOTIFICATIONS SECTION
          _buildSectionHeader('Notifications', secondaryTextColor),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Hourly Check-in Reminders'),
                  subtitle: Text(
                    'Prompts to review and log during tracking window',
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                  ),
                  value: settings.hourlyRemindersEnabled,
                  onChanged: (val) {
                    notifier.updateSettings(
                        settings.copyWith(hourlyRemindersEnabled: val));
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.hourglass_empty_outlined),
                  title: const Text('Reminder Interval'),
                  trailing: Text('Every ${settings.hourlyInterval}h',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: primaryTextColor)),
                  onTap: () {
                    // Toggle 1h, 2h
                    final next = settings.hourlyInterval == 1 ? 2 : 1;
                    notifier.updateSettings(
                        settings.copyWith(hourlyInterval: next));
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text('Notification Status'),
                  trailing: Text(
                    _notificationStatus == NotificationStatus.enabled
                        ? 'Active'
                        : 'Permission needed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _notificationStatus == NotificationStatus.enabled
                          ? Colors.green.shade600
                          : Colors.amber.shade800,
                    ),
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('Test Notification'),
                  subtitle: const Text('Triggers real local alert immediately'),
                  trailing: _testingNotification
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _handleTestNotification,
                          child: const Text('Test'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // DATA & BACKUP SECTION
          _buildSectionHeader('Data & Backup', secondaryTextColor),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Export Data (.json)'),
                  subtitle: Text(
                    settings.lastExportTimestamp != null
                        ? 'Last export: ${DateFormat.yMd().add_jm().format(settings.lastExportTimestamp!)}'
                        : 'Local-first offline backup',
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleExportData,
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Import Data (.json)'),
                  subtitle: const Text('Merge or restore from file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleImportData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // APPEARANCE SECTION
          _buildSectionHeader('Appearance', secondaryTextColor),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        notifier.updateSettings(settings.copyWith(themeMode: val));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}
