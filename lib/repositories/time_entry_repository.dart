import 'dart:math';
import '../database/database_helper.dart';
import '../models/activity_history_entry.dart';
import '../models/time_entry.dart';

class TimeGap {
  final String startTime;
  final String endTime;
  final int durationMinutes;

  const TimeGap({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  String get formattedDuration {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m untracked';
    if (h > 0) return '${h}h untracked';
    return '${m}m untracked';
  }
}

class TimeEntryConflict {
  final int entryId1;
  final int entryId2;
  final String overlapTimeRange;

  const TimeEntryConflict({
    required this.entryId1,
    required this.entryId2,
    required this.overlapTimeRange,
  });
}

class DailyTimeSummary {
  final int totalRecordedMinutes;
  final int uniqueCoveredMinutes;
  final int untrackedMinutes;
  final int entryCount;
  final List<TimeGap> gaps;
  final List<TimeEntryConflict> conflicts;

  const DailyTimeSummary({
    required this.totalRecordedMinutes,
    required this.uniqueCoveredMinutes,
    required this.untrackedMinutes,
    required this.entryCount,
    required this.gaps,
    required this.conflicts,
  });

  String get formattedRecordedTime => _formatMinutes(totalRecordedMinutes);
  String get formattedCoveredTime => _formatMinutes(uniqueCoveredMinutes);
  String get formattedUntrackedTime => _formatMinutes(untrackedMinutes);

  static String _formatMinutes(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class TimeEntryRepository {
  final DatabaseHelper _databaseHelper;

  TimeEntryRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper();

  Future<List<TimeEntry>> getTimeEntriesForDate(String date) async {
    return await _databaseHelper.getTimeEntriesForDate(date);
  }

  Future<TimeEntry> addTimeEntry(TimeEntry entry) async {
    final id = await _databaseHelper.insertTimeEntry(entry);
    final inserted = entry.copyWith(id: id);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'time_entry_created',
        entityType: 'time_entry',
        entityId: id,
        details: '${entry.formattedTimeRange}: ${entry.activityTitle}',
        timestamp: DateTime.now(),
      ),
    );

    return inserted;
  }

  Future<void> updateTimeEntry(TimeEntry entry) async {
    if (entry.id == null) return;
    await _databaseHelper.updateTimeEntry(entry);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'time_entry_updated',
        entityType: 'time_entry',
        entityId: entry.id,
        details: '${entry.formattedTimeRange}: ${entry.activityTitle}',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> deleteTimeEntry(int id) async {
    await _databaseHelper.deleteTimeEntry(id);

    await _databaseHelper.insertActivityHistory(
      ActivityHistoryEntry(
        eventType: 'time_entry_deleted',
        entityType: 'time_entry',
        entityId: id,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Calculates the day summary including exact durations, non-overlapping coverage,
  /// untracked gaps, and conflicts.
  DailyTimeSummary calculateSummary(
    List<TimeEntry> entries, {
    required String windowStart,
    required String windowEnd,
  }) {
    final winStartMins = TimeEntry.parseMinutes(windowStart);
    final winEndMins = TimeEntry.parseMinutes(windowEnd);

    int totalRecorded = 0;
    for (final e in entries) {
      totalRecorded += e.durationMinutes;
    }

    // Sort intervals to calculate merged coverage
    final sortedIntervals = entries
        .map((e) => _Interval(e.startMinutes, e.endMinutes, e.id ?? 0))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Calculate unique covered minutes without double counting
    final merged = <_Interval>[];
    for (final interval in sortedIntervals) {
      if (merged.isEmpty) {
        merged.add(_Interval(interval.start, interval.end, interval.id));
      } else {
        final last = merged.last;
        if (interval.start < last.end) {
          // Overlap: extend last end
          merged[merged.length - 1] = _Interval(
            last.start,
            max(last.end, interval.end),
            last.id,
          );
        } else {
          merged.add(_Interval(interval.start, interval.end, interval.id));
        }
      }
    }

    int uniqueCovered = 0;
    for (final m in merged) {
      uniqueCovered += (m.end - m.start);
    }

    // Detect conflicts among raw entries
    final conflicts = <TimeEntryConflict>[];
    for (int i = 0; i < sortedIntervals.length; i++) {
      for (int j = i + 1; j < sortedIntervals.length; j++) {
        final a = sortedIntervals[i];
        final b = sortedIntervals[j];
        if (b.start < a.end) {
          // Conflict
          final overlapStart = max(a.start, b.start);
          final overlapEnd = min(a.end, b.end);
          if (overlapEnd > overlapStart) {
            conflicts.add(
              TimeEntryConflict(
                entryId1: a.id,
                entryId2: b.id,
                overlapTimeRange:
                    '${TimeEntry.formatMinutes(overlapStart)}–${TimeEntry.formatMinutes(overlapEnd)}',
              ),
            );
          }
        }
      }
    }

    // Calculate untracked gaps within configured tracking window
    final gaps = <TimeGap>[];
    int currentPointer = winStartMins;

    for (final m in merged) {
      if (m.end <= winStartMins) continue;
      if (m.start >= winEndMins) break;

      final clampedStart = max(m.start, winStartMins);
      if (clampedStart > currentPointer) {
        gaps.add(
          TimeGap(
            startTime: TimeEntry.formatMinutes(currentPointer),
            endTime: TimeEntry.formatMinutes(clampedStart),
            durationMinutes: clampedStart - currentPointer,
          ),
        );
      }
      currentPointer = max(currentPointer, min(m.end, winEndMins));
    }

    if (currentPointer < winEndMins) {
      gaps.add(
        TimeGap(
          startTime: TimeEntry.formatMinutes(currentPointer),
          endTime: TimeEntry.formatMinutes(winEndMins),
          durationMinutes: winEndMins - currentPointer,
        ),
      );
    }

    int untrackedTotal = 0;
    for (final gap in gaps) {
      untrackedTotal += gap.durationMinutes;
    }

    return DailyTimeSummary(
      totalRecordedMinutes: totalRecorded,
      uniqueCoveredMinutes: uniqueCovered,
      untrackedMinutes: untrackedTotal,
      entryCount: entries.length,
      gaps: gaps,
      conflicts: conflicts,
    );
  }
}

class _Interval {
  final int start;
  final int end;
  final int id;
  const _Interval(this.start, this.end, this.id);
}
