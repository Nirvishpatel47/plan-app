import '../models/time_entry.dart';

class ParsedTimeRange {
  final String? startTime; // "HH:mm" in 24-hr format
  final String? endTime; // "HH:mm" in 24-hr format
  final bool isValid;
  final String? errorMessage;

  const ParsedTimeRange({
    this.startTime,
    this.endTime,
    required this.isValid,
    this.errorMessage,
  });

  factory ParsedTimeRange.success(String start, String end) {
    return ParsedTimeRange(
      startTime: start,
      endTime: end,
      isValid: true,
    );
  }

  factory ParsedTimeRange.failure(String message) {
    return ParsedTimeRange(
      isValid: false,
      errorMessage: message,
    );
  }

  String get formattedRange => isValid ? '$startTime–$endTime' : '';
}

class _RawTime {
  final int hour;
  final int minute;
  final String? meridiem; // 'am', 'pm', or null
  final bool is24Hour;

  const _RawTime({
    required this.hour,
    required this.minute,
    this.meridiem,
    this.is24Hour = false,
  });
}

class TimeRangeParser {
  /// Parses a time range string (e.g. '11:00 - 11:30', '8:00-9:00', '9 - 10')
  /// and resolves AM/PM chronologically given existing day entries and day start.
  static ParsedTimeRange parse(
    String input, {
    List<TimeEntry> existingEntries = const [],
    String defaultStartOfDay = '08:00',
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParsedTimeRange.failure('Please enter a time range (e.g. 11:00 - 11:30)');
    }

    // Split on dash, en-dash, or em-dash, or 'to'
    final separatorRegex = RegExp(r'\s*(?:[-–—]|to)\s*');
    final parts = trimmed.split(separatorRegex);
    if (parts.length != 2) {
      return ParsedTimeRange.failure(
        'Format must be start and end time separated by dash (e.g. 11:00 - 11:30)',
      );
    }

    final rawStart = _parseTimeComponent(parts[0]);
    if (rawStart == null) {
      return ParsedTimeRange.failure('Invalid start time: "${parts[0].trim()}"');
    }

    final rawEnd = _parseTimeComponent(parts[1]);
    if (rawEnd == null) {
      return ParsedTimeRange.failure('Invalid end time: "${parts[1].trim()}"');
    }

    if (rawStart.minute < 0 || rawStart.minute > 59) {
      return ParsedTimeRange.failure('Start minutes must be between 00 and 59');
    }
    if (rawEnd.minute < 0 || rawEnd.minute > 59) {
      return ParsedTimeRange.failure('End minutes must be between 00 and 59');
    }

    // Determine chronological context anchor
    final defaultStartMins = TimeEntry.parseMinutes(defaultStartOfDay);
    int anchorMinutes = defaultStartMins;

    if (existingEntries.isNotEmpty) {
      // Find the latest ending entry
      int maxEnd = 0;
      for (final e in existingEntries) {
        if (e.endMinutes > maxEnd) maxEnd = e.endMinutes;
      }
      if (maxEnd > 0) anchorMinutes = maxEnd;
    }

    // Generate possible candidate pairs for (start, end)
    final candidates = _generateCandidates(rawStart, rawEnd);

    if (candidates.isEmpty) {
      return ParsedTimeRange.failure('End time must be after start time');
    }

    // Filter to candidates where end > start
    final validPairs = candidates.where((pair) => pair.endMins > pair.startMins).toList();
    if (validPairs.isEmpty) {
      return ParsedTimeRange.failure('End time must be after start time');
    }

    // Score candidates based on chronological fit
    _CandidatePair bestPair = validPairs.first;
    int bestScore = 999999;

    for (final pair in validPairs) {
      int score = 0;

      // Penalize start time being before the anchor
      if (pair.startMins < anchorMinutes) {
        // Gap in the past
        score += (anchorMinutes - pair.startMins) * 3;
      } else {
        // Chronological continuation
        score += (pair.startMins - anchorMinutes);
      }

      // Penalize excessive single-entry durations (> 6 hours) unless explicit
      final duration = pair.endMins - pair.startMins;
      if (duration > 360) {
        score += (duration - 360) * 2;
      }

      // Penalize early morning hours (00:00 - 06:00) heavily if ambiguous
      if (!rawStart.is24Hour && rawStart.meridiem == null) {
        if (pair.startMins < 360) {
          score += 1000;
        }
      }

      if (score < bestScore) {
        bestScore = score;
        bestPair = pair;
      }
    }

    final startStr = TimeEntry.formatMinutes(bestPair.startMins);
    final endStr = TimeEntry.formatMinutes(bestPair.endMins);

    return ParsedTimeRange.success(startStr, endStr);
  }

  static _RawTime? _parseTimeComponent(String raw) {
    var text = raw.trim().toLowerCase();
    String? meridiem;

    if (text.endsWith('am')) {
      meridiem = 'am';
      text = text.substring(0, text.length - 2).trim();
    } else if (text.endsWith('pm')) {
      meridiem = 'pm';
      text = text.substring(0, text.length - 2).trim();
    }

    final timeParts = text.split(':');
    if (timeParts.length == 1) {
      // Just hour e.g. "9", "14"
      final h = int.tryParse(timeParts[0]);
      if (h == null || h < 0 || h > 23) return null;
      return _RawTime(
        hour: h,
        minute: 0,
        meridiem: meridiem,
        is24Hour: h > 12,
      );
    } else if (timeParts.length == 2) {
      // Hour and minute e.g. "8:30"
      final h = int.tryParse(timeParts[0]);
      final m = int.tryParse(timeParts[1]);
      if (h == null || m == null || h < 0 || h > 23) return null;
      return _RawTime(
        hour: h,
        minute: m,
        meridiem: meridiem,
        is24Hour: h > 12,
      );
    }

    return null;
  }

  static List<_CandidatePair> _generateCandidates(_RawTime start, _RawTime end) {
    final startHours = _possible24Hours(start);
    final endHours = _possible24Hours(end);

    final pairs = <_CandidatePair>[];
    for (final sh in startHours) {
      final sMins = sh * 60 + start.minute;
      for (final eh in endHours) {
        final eMins = eh * 60 + end.minute;
        if (eMins > sMins) {
          pairs.add(_CandidatePair(sMins, eMins));
        }
      }
    }
    return pairs;
  }

  static List<int> _possible24Hours(_RawTime raw) {
    if (raw.is24Hour) return [raw.hour];

    if (raw.meridiem == 'am') {
      return [raw.hour == 12 ? 0 : raw.hour];
    } else if (raw.meridiem == 'pm') {
      return [raw.hour == 12 ? 12 : raw.hour + 12];
    }

    // Ambiguous (1..12) without meridiem
    if (raw.hour == 12) {
      // 12:00 could be noon (12) or midnight (0)
      return [12, 0];
    } else if (raw.hour > 0 && raw.hour < 12) {
      // Could be AM (hour) or PM (hour + 12)
      return [raw.hour, raw.hour + 12];
    }

    return [raw.hour];
  }
}

class _CandidatePair {
  final int startMins;
  final int endMins;
  const _CandidatePair(this.startMins, this.endMins);
}
