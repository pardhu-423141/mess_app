// meal_utils.dart
import 'package:flutter/material.dart';

/// Represents a range of time of day.
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;
  TimeOfDayRange({required this.start, required this.end});
}

/// Provides a mapping of meal names to their corresponding integer codes.
Map<String, int> getMealCodes() {
  return {
    'Breakfast': 1,
    'Lunch': 2,
    'Snacks': 3,
    'Dinner': 4,
  };
}

/// Provides a mapping of meal names to their time ranges.
Map<String, TimeOfDayRange> getMealTimings() {
  return {
    'Breakfast': TimeOfDayRange(
      start: const TimeOfDay(hour: 5, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
    ),
    'Lunch': TimeOfDayRange(
      start: const TimeOfDay(hour: 10, minute: 30),
      end: const TimeOfDay(hour: 15, minute: 30),
    ),
    'Snacks': TimeOfDayRange(
      start: const TimeOfDay(hour: 15, minute: 30),
      end: const TimeOfDay(hour: 17, minute: 45),
    ),
    'Dinner': TimeOfDayRange(
      start: const TimeOfDay(hour: 18, minute: 15),
      end: const TimeOfDay(hour: 23, minute: 50),
    ),
  };
}

/// Retrieves the TimeOfDayRange for a given meal name.
TimeOfDayRange getMealTimeRange(String meal) {
  // It's safer to provide a default or throw an error if the meal doesn't exist,
  // but for now, the '!' operator is kept as per original logic.
  return getMealTimings()[meal]!;
}

/// Utility class for meal-related operations.
class MealUtils {
  /// Checks if a given time is within a specified time range.
  static bool isWithinRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  /// Determines the meal name for the current time.
  /// Returns null if no meal is found for the given time.
  static String? getMealNameForCurrentTime(TimeOfDay nowTime) {
    String? mealName;
    getMealTimings().forEach((name, range) {
      if (isWithinRange(nowTime, range.start, range.end)) {
        mealName = name;
      }
    });
    return mealName;
  }

  /// Retrieves the integer code for a given meal name.
  /// Returns 0 if the meal name is not found.
  static int getMealCode(String mealName) {
    return getMealCodes()[mealName] ?? 0;
  }
}