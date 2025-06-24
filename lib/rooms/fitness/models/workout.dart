import 'dart:ui';

import 'package:flutter/material.dart';

enum WorkoutType { personalized, challenge }
enum WorkoutLevel { beginner, intermediate, advanced }

class Workout {
  final String id;
  final String title;
  final String imageUrl;
  final String description;
  final String category;
  final WorkoutLevel level;
  final int durationMinutes;
  final int estimatedCalories;
  final WorkoutType type;
  final String? clientName;
  final String? clientId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? frequency;
  final String? cadence;
  final String? rest;
  final String? pathology;
  final List<WorkoutDay> days;
  final bool archived;

  Workout({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.estimatedCalories,
    required this.type,
    this.clientName,
    this.clientId,
    this.startDate,
    this.endDate,
    this.frequency,
    this.cadence,
    this.rest,
    this.pathology,
    required this.days,
    this.archived = false,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      title: json['title'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      category: json['category'],
      level: WorkoutLevel.values.firstWhere(
            (e) => e.toString() == 'WorkoutLevel.${json['level']}',
        orElse: () => WorkoutLevel.intermediate,
      ),
      durationMinutes: json['durationMinutes'],
      estimatedCalories: json['estimatedCalories'],
      type: WorkoutType.values.firstWhere(
            (e) => e.toString() == 'WorkoutType.${json['type']}',
        orElse: () => WorkoutType.challenge,
      ),
      clientName: json['clientName'],
      clientId: json['clientId'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      frequency: json['frequency'],
      cadence: json['cadence'],
      rest: json['rest'],
      pathology: json['pathology'],
      days: (json['days'] as List)
          .map((day) => WorkoutDay.fromJson(day))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'description': description,
      'category': category,
      'level': level.toString().split('.').last,
      'durationMinutes': durationMinutes,
      'estimatedCalories': estimatedCalories,
      'type': type.toString().split('.').last,
      'clientName': clientName,
      'clientId': clientId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'frequency': frequency,
      'cadence': cadence,
      'rest': rest,
      'pathology': pathology,
      'days': days.map((day) => day.toJson()).toList(),
    };
  }

  String get levelText {
    switch (level) {
      case WorkoutLevel.beginner:
        return 'NIVEL INICIAL';
      case WorkoutLevel.intermediate:
        return 'NIVEL MEDIO';
      case WorkoutLevel.advanced:
        return 'NIVEL AVANZADO';
      default:
        return 'NIVEL MEDIO';
    }
  }

  Color getLevelColor() {
    switch (level) {
      case WorkoutLevel.beginner:
        return Colors.teal;
      case WorkoutLevel.intermediate:
        return Colors.green;
      case WorkoutLevel.advanced:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Color getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'hiit':
        return Colors.blue;
      case 'fuerza':
        return Colors.orange;
      case 'cardio':
        return Colors.red;
      case 'yoga':
        return Colors.purple;
      case 'flexibilidad':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }
}

class WorkoutDay {
  final int dayOfWeek; // 1-7 (Lunes-Domingo)
  final String? warmup;
  final List<Exercise> exercises;
  final String? finalExercises;
  int? _totalMinutes;
  int? _totalCalories;

  WorkoutDay({
    required this.dayOfWeek,
    this.warmup,
    required this.exercises,
    this.finalExercises,
    int? totalMinutes,
    int? totalCalories,
  }) :
        _totalMinutes = totalMinutes,
        _totalCalories = totalCalories;

  // Getters and setters for totalMinutes and totalCalories
  int get totalMinutes => _totalMinutes ?? 0;
  int get totalCalories => _totalCalories ?? 0;

  set totalMinutes(int value) => _totalMinutes = value;
  set totalCalories(int value) => _totalCalories = value;

  // Calculate total time in seconds for all exercises in this day
  int get totalTimeSeconds {
    int total = 0;
    for (var exercise in exercises) {
      // Basic time for each exercise (in seconds)
      int exerciseTime = exercise.sets * 60; // Approximate time per set

      // Add rest time between sets
      String rest = exercise.rest;
      int restSeconds = 0;
      if (rest.contains('seg')) {
        restSeconds = int.tryParse(rest.replaceAll(RegExp(r'[^\d]'), '')) ?? 60;
      } else if (rest.contains('min')) {
        restSeconds = (int.tryParse(rest.replaceAll(RegExp(r'[^\d]'), '')) ?? 1) * 60;
      }

      total += exerciseTime + (restSeconds * (exercise.sets - 1));
    }

    // Add warmup time if present (5 minutes)
    if (warmup != null && warmup!.isNotEmpty) {
      total += 5 * 60;
    }

    // Add cooldown time if present (5 minutes)
    if (finalExercises != null && finalExercises!.isNotEmpty) {
      total += 5 * 60;
    }

    return total;
  }

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayOfWeek: json['dayOfWeek'],
      warmup: json['warmup'],
      exercises: (json['exercises'] as List)
          .map((exercise) => Exercise.fromJson(exercise))
          .toList(),
      finalExercises: json['finalExercises'],
      totalMinutes: json['totalMinutes'],
      totalCalories: json['totalCalories'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'warmup': warmup,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      'finalExercises': finalExercises,
      'totalMinutes': _totalMinutes,
      'totalCalories': _totalCalories,
    };
  }

  String get dayName {
    switch (dayOfWeek) {
      case 1: return 'Lunes';
      case 2: return 'Martes';
      case 3: return 'Miércoles';
      case 4: return 'Jueves';
      case 5: return 'Viernes';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return 'Día $dayOfWeek';
    }
  }
}

class Exercise {
  final String name;
  final int sets;
  final String reps;
  final String rest;
  final String cadence;
  final String? videoUrl;
  final String? muscleGroup; // New field
  final int? estimatedTimeSeconds; // New field
  final int? estimatedCalories; // New field
  final int? caloriesPerRep; // Nuevo campo

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.cadence,
    this.videoUrl,
    this.muscleGroup,
    this.estimatedTimeSeconds,
    this.estimatedCalories,
    this.caloriesPerRep, // Inicializado como opcional

  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'rest': rest,
      'cadence': cadence,
      'videoUrl': videoUrl,
      'muscleGroup': muscleGroup,
      'estimatedTimeSeconds': estimatedTimeSeconds,
      'estimatedCalories': estimatedCalories,
      'caloriesPerRep': caloriesPerRep, // Incluir en el JSON
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],
      rest: json['rest'],
      cadence: json['cadence'],
      videoUrl: json['videoUrl'],
      muscleGroup: json['muscleGroup'],
      estimatedTimeSeconds: json['estimatedTimeSeconds'],
      estimatedCalories: json['estimatedCalories'],
      caloriesPerRep: json['caloriesPerRep'], // Recuperar del JSON
    );
  }
}