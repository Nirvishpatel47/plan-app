import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class CalendarView extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final Map<String, int> monthTaskCounts;

  const CalendarView({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.monthTaskCounts,
  });

  void _previousMonth() {
    final prev = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    onMonthChanged(prev);
  }

  void _nextMonth() {
    final next = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    onMonthChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final secondaryTextColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final primaryColor =
        isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final selectedTextColor =
        isDark ? AppTheme.darkBg : Colors.white;

    final monthTitle = DateFormat.yMMMM().format(currentMonth);

    // Days in current month
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    // Weekday of the first day: 1 = Monday, 7 = Sunday
    final firstWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    // Leading empty slots for Monday-first week
    final leadingEmpty = firstWeekday - 1;

    final today = DateTime.now();
    final todayKey = Task.formatDateKey(today);
    final selectedKey = Task.formatDateKey(selectedDate);

    final weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: _previousMonth,
              ),
              Text(
                monthTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday header row
          Row(
            children: weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          // Month Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmpty + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmpty) {
                return const SizedBox.shrink();
              }

              final dayNumber = index - leadingEmpty + 1;
              final dayDate =
                  DateTime(currentMonth.year, currentMonth.month, dayNumber);
              final dayKey = Task.formatDateKey(dayDate);

              final isSelected = dayKey == selectedKey;
              final isToday = dayKey == todayKey;
              final hasTasks = (monthTaskCounts[dayKey] ?? 0) > 0;

              return InkWell(
                onTap: () => onDateSelected(dayDate),
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.transparent,
                      border: isToday && !isSelected
                          ? Border.all(color: primaryColor, width: 1.5)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? selectedTextColor
                                : primaryTextColor,
                          ),
                        ),
                        if (hasTasks)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? selectedTextColor
                                    : secondaryTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
