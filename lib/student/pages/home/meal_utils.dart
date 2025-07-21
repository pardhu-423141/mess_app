import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/meal_utils.dart';

String getCurrentMealType() {
  final now = TimeOfDay.now();
  final timings = getMealTimings();

  for (var entry in timings.entries) {
    final range = entry.value;
    final nowInMinutes = now.hour * 60 + now.minute;
    final start = range.start.hour * 60 + range.start.minute;
    final end = range.end.hour * 60 + range.end.minute;

    if (nowInMinutes >= start && nowInMinutes <= end) {
      return entry.key;
    }
  }
  return 'Breakfast';
}

DateTime? getMealClosingTime(String mealType) {
  final timings = getMealTimings();
  final range = timings[mealType];
  if (range == null) return null;

  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, range.end.hour, range.end.minute);
}

String getMealTypeFromCode(String itemId) {
  if (itemId.length >= 2) {
    switch (itemId[1]) {
      case '1': return 'Breakfast';
      case '2': return 'Lunch';
      case '3': return 'Snacks';
      case '4': return 'Dinner';
    }
  }
  return 'Unknown Meal';
}

String getDayStringFromIdDigit(String itemId) {
  if (itemId.isNotEmpty) {
    switch (itemId[0]) {
      case '1': return 'Monday';
      case '2': return 'Tuesday';
      case '3': return 'Wednesday';
      case '4': return 'Thursday';
      case '5': return 'Friday';
      case '6': return 'Saturday';
      case '7': return 'Sunday';
    }
  }
  return 'Unknown Day';
}

String getCurrentActualDayString() {
  return DateFormat('EEEE').format(DateTime.now());
}
