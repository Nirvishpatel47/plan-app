import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../repositories/time_entry_repository.dart';
import '../state/plan_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/time_entry_editor_dialog.dart';
import 'settings_screen.dart';

class TimeScreen extends StatelessWidget {
  const TimeScreen({super.key});

  void _openAddEntry(BuildContext context, {String? prefilledRange}) {
    final notifier = PlanScope.read(context);
    TimeEntryEditorDialog.show(
      context: context,
      date: notifier.selectedTimeScreenDateKey,
      existingDayEntries: notifier.selectedDateTimeEntries,
      defaultStartOfDay: notifier.appSettings.startOfDay,
      initialTimeRange: prefilledRange,
      onSave: (entry) async {
        try {
          await notifier.createTimeEntry(entry);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't save time entry.")),
            );
          }
        }
      },
    );
  }

  void _openEditEntry(BuildContext context, TimeEntry entry) {
    final notifier = PlanScope.read(context);
    TimeEntryEditorDialog.show(
      context: context,
      existingEntry: entry,
      date: notifier.selectedTimeScreenDateKey,
      existingDayEntries: notifier.selectedDateTimeEntries,
      defaultStartOfDay: notifier.appSettings.startOfDay,
      onSave: (updated) async {
        try {
          await notifier.updateTimeEntry(updated);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't update time entry.")),
            );
          }
        }
      },
      onDelete: () => _deleteEntryWithUndo(context, entry),
    );
  }

  void _deleteEntryWithUndo(BuildContext context, TimeEntry entry) async {
    final notifier = PlanScope.read(context);
    try {
      await notifier.deleteTimeEntry(entry.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${entry.activityTitle}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await notifier.createTimeEntry(
                  entry.copyWith(id: null),
                );
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete time entry.")),
        );
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final notifier = PlanScope.read(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: notifier.selectedTimeScreenDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      notifier.selectTimeScreenDate(picked);
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

    final isToday = Task.formatDateKey(notifier.selectedTimeScreenDate) ==
        Task.formatDateKey(notifier.today);

    final dateDisplay = isToday
        ? 'Today, ${DateFormat('d MMMM').format(notifier.selectedTimeScreenDate)}'
        : DateFormat('EEEE, d MMMM').format(notifier.selectedTimeScreenDate);

    final summary = notifier.dailyTimeSummary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screen Header & Settings action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: primaryTextColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _openAddEntry(context),
                        tooltip: 'Log time entry',
                        icon: const Icon(Icons.add, size: 28),
                        color: primaryTextColor,
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
                ],
              ),
            ),
            // Date Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    tooltip: 'Previous day',
                    onPressed: () => notifier.previousDayTimeScreen(),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.calendar_month,
                                size: 15, color: secondaryTextColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    tooltip: 'Next day',
                    onPressed: () => notifier.nextDayTimeScreen(),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (!isToday) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => notifier.goToTodayTimeScreen(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            // Compact Day Summary Card
            if (summary != null && notifier.selectedDateTimeEntries.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryMetric(
                      title: 'Recorded',
                      value: summary.formattedRecordedTime,
                      color: primaryTextColor,
                    ),
                    _buildDivider(borderColor),
                    _buildSummaryMetric(
                      title: 'Coverage',
                      value: summary.formattedCoveredTime,
                      color: primaryTextColor,
                    ),
                    _buildDivider(borderColor),
                    _buildSummaryMetric(
                      title: 'Untracked',
                      value: summary.formattedUntrackedTime,
                      color: secondaryTextColor,
                    ),
                    _buildDivider(borderColor),
                    _buildSummaryMetric(
                      title: 'Entries',
                      value: '${summary.entryCount}',
                      color: primaryTextColor,
                    ),
                  ],
                ),
              ),
            const Divider(),
            // Chronological Timeline & Gaps
            Expanded(
              child: notifier.isLoadingTime
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : notifier.selectedDateTimeEntries.isEmpty
                      ? _buildEmptyState(context, secondaryTextColor)
                      : _buildTimelineList(
                          context,
                          notifier.selectedDateTimeEntries,
                          summary,
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

  Widget _buildSummaryMetric({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 24,
      color: borderColor,
    );
  }

  Widget _buildTimelineList(
    BuildContext context,
    List<TimeEntry> entries,
    DailyTimeSummary? summary,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
    Color surfaceColor,
    bool isDark,
  ) {
    // Interleave entries and gaps for clear notebook-style chronological timeline
    final items = <_TimelineItem>[];

    final gaps = summary?.gaps ?? [];
    final conflicts = summary?.conflicts ?? [];

    int entryIdx = 0;
    int gapIdx = 0;

    while (entryIdx < entries.length || gapIdx < gaps.length) {
      if (entryIdx < entries.length && gapIdx < gaps.length) {
        final entryStart = entries[entryIdx].startMinutes;
        final gapStart = TimeEntry.parseMinutes(gaps[gapIdx].startTime);

        if (gapStart <= entryStart) {
          items.add(_TimelineItem.gap(gaps[gapIdx]));
          gapIdx++;
        } else {
          final entry = entries[entryIdx];
          final hasConflict =
              conflicts.any((c) => c.entryId1 == entry.id || c.entryId2 == entry.id);
          items.add(_TimelineItem.entry(entry, hasConflict));
          entryIdx++;
        }
      } else if (entryIdx < entries.length) {
        final entry = entries[entryIdx];
        final hasConflict =
            conflicts.any((c) => c.entryId1 == entry.id || c.entryId2 == entry.id);
        items.add(_TimelineItem.entry(entry, hasConflict));
        entryIdx++;
      } else {
        items.add(_TimelineItem.gap(gaps[gapIdx]));
        gapIdx++;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isGap) {
          final gap = item.gap!;
          // Subtle gap indicator with quick log button
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.more_horiz, size: 16, color: secondaryTextColor),
                const SizedBox(width: 8),
                Text(
                  '${gap.startTime}–${gap.endTime} · ${gap.formattedDuration}',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _openAddEntry(
                    context,
                    prefilledRange: '${gap.startTime} - ${gap.endTime}',
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: secondaryTextColor),
                        Text(
                          'Log',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final entry = item.entry!;
        return Dismissible(
          key: ValueKey('entry_${entry.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade700,
            child: const Icon(Icons.delete_outline,
                color: Colors.white, size: 22),
          ),
          onDismissed: (_) => _deleteEntryWithUndo(context, entry),
          child: InkWell(
            onTap: () => _openEditEntry(context, entry),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.hasConflict ? Colors.amber.shade700 : borderColor,
                  width: item.hasConflict ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Time Column
                  SizedBox(
                    width: 95,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.formattedTimeRange,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          entry.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  const SizedBox(width: 12),
                  // Activity details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.activityTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        if (entry.notes != null && entry.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              entry.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.hasConflict)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Overlap',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  Icon(Icons.edit_outlined, size: 18, color: secondaryTextColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, Color secondaryTextColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 40, color: secondaryTextColor),
          const SizedBox(height: 12),
          Text(
            'No time entries for this date.',
            style: TextStyle(
              fontSize: 16,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _openAddEntry(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log Time'),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final bool isGap;
  final TimeEntry? entry;
  final TimeGap? gap;
  final bool hasConflict;

  _TimelineItem.entry(this.entry, this.hasConflict)
      : isGap = false,
        gap = null;

  _TimelineItem.gap(this.gap)
      : isGap = true,
        entry = null,
        hasConflict = false;
}
