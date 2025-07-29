import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WorkoutTrackingService {
  static const String _completedDaysKey = 'completed_workout_days';

  // Guarda un día como completado
  static Future<void> markDayAsCompleted(String workoutId, String dayName) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final key = '${_completedDaysKey}_${workoutId}_$weekStart';

    final completedDays = await getCompletedDays(workoutId);
    completedDays.add(dayName);

    await prefs.setStringList(key, completedDays.toList());
  }

  // Obtiene los días completados de la semana actual
  static Future<Set<String>> getCompletedDays(String workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final key = '${_completedDaysKey}_${workoutId}_$weekStart';

    final days = prefs.getStringList(key) ?? [];
    return days.toSet();
  }

  // Obtiene el inicio de la semana (lunes)
  static String _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}