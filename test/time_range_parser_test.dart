import 'package:flutter_test/flutter_test.dart';
import 'package:plan/models/time_entry.dart';
import 'package:plan/services/time_range_parser.dart';

void main() {
  group('TimeRangeParser Tests', () {
    test('Standard range 11:00 - 11:30 parses accurately', () {
      final res = TimeRangeParser.parse('11:00 - 11:30');
      expect(res.isValid, true);
      expect(res.startTime, '11:00');
      expect(res.endTime, '11:30');
    });

    test('Range 8:00 - 9:00 with default start of day 08:00 resolves to 08:00–09:00', () {
      final res = TimeRangeParser.parse('8:00 - 9:00', defaultStartOfDay: '08:00');
      expect(res.isValid, true);
      expect(res.startTime, '08:00');
      expect(res.endTime, '09:00');
    });

    test('Compact range 8:00-9:30 without spaces parses correctly', () {
      final res = TimeRangeParser.parse('8:00-9:30');
      expect(res.isValid, true);
      expect(res.startTime, '08:00');
      expect(res.endTime, '09:30');
    });

    test('Hour-only input 9 - 10 resolves to 09:00–10:00', () {
      final res = TimeRangeParser.parse('9 - 10');
      expect(res.isValid, true);
      expect(res.startTime, '09:00');
      expect(res.endTime, '10:00');
    });

    test('Unambiguous 24-hour input 14:00 - 15:30 parses as 14:00–15:30', () {
      final res = TimeRangeParser.parse('14:00 - 15:30');
      expect(res.isValid, true);
      expect(res.startTime, '14:00');
      expect(res.endTime, '15:30');
    });

    test('Chronological inference: 8:00-9:00 morning followed later by 8:00-9:00 resolves to 20:00–21:00', () {
      final existing = [
        TimeEntry(
          id: 1,
          date: '2026-10-29',
          startTime: '08:00',
          endTime: '09:00',
          activityTitle: 'Morning Reading',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TimeEntry(
          id: 2,
          date: '2026-10-29',
          startTime: '14:00',
          endTime: '17:00',
          activityTitle: 'Afternoon Programming',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final res = TimeRangeParser.parse('8:00 - 9:00', existingEntries: existing);
      expect(res.isValid, true);
      expect(res.startTime, '20:00');
      expect(res.endTime, '21:00');
    });

    test('Rejects invalid minutes (> 59)', () {
      final res = TimeRangeParser.parse('11:65 - 12:00');
      expect(res.isValid, false);
      expect(res.errorMessage, contains('between 00 and 59'));
    });

    test('Rejects missing end time', () {
      final res = TimeRangeParser.parse('11:00');
      expect(res.isValid, false);
    });

    test('Rejects end before start', () {
      final res = TimeRangeParser.parse('15:00 - 14:00');
      expect(res.isValid, false);
      expect(res.errorMessage, contains('End time must be after start time'));
    });
  });
}
