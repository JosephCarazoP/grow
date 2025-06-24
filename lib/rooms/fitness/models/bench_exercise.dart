import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  final String name;
  final int sets;
  final String reps;
  final String rest;
  final String cadence;
  final String? muscleGroup;
  final int? caloriesPerRep;
  final String? videoUrl;
  final String? benchExerciseId;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.cadence,
    this.muscleGroup,
    this.caloriesPerRep,
    this.videoUrl,
    this.benchExerciseId,
  });

  // Make sure to include it in copyWith
  Exercise copyWith({
    String? name,
    int? sets,
    String? reps,
    String? rest,
    String? cadence,
    String? muscleGroup,
    int? caloriesPerRep,
    String? videoUrl,
    String? benchExerciseId,
  }) {
    return Exercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      rest: rest ?? this.rest,
      cadence: cadence ?? this.cadence,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      caloriesPerRep: caloriesPerRep ?? this.caloriesPerRep,
      videoUrl: videoUrl ?? this.videoUrl,
      benchExerciseId: benchExerciseId ?? this.benchExerciseId,
    );
  }

  // Also include it in toMap
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'rest': rest,
      'cadence': cadence,
      'muscleGroup': muscleGroup,
      'caloriesPerRep': caloriesPerRep,
      'videoUrl': videoUrl,
      'benchExerciseId': benchExerciseId,
    };
  }

  // And in fromMap
  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 3,
      reps: map['reps'] ?? '12',
      rest: map['rest'] ?? '60 seg',
      cadence: map['cadence'] ?? '2-1-2',
      muscleGroup: map['muscleGroup'],
      caloriesPerRep: map['caloriesPerRep'],
      videoUrl: map['videoUrl'],
      benchExerciseId: map['benchExerciseId'],
    );
  }
}

class BenchExercise {
  final String? id;
  final String name;
  final String muscleGroup;
  final String? description;
  final String? videoUrl;
  final int caloriesPerRep;
  final String defaultCadence;
  final List<String> imageUrls;

  BenchExercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    this.description,
    this.videoUrl,
    required this.caloriesPerRep,
    required this.defaultCadence,
    required this.imageUrls,
  });

  // Método para crear un objeto desde un DocumentSnapshot
  static BenchExercise fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return fromMap({...data, 'id': doc.id});
  }

  // Método para crear un objeto desde un Map
  static BenchExercise fromMap(Map<String, dynamic> map) {
    return BenchExercise(
      id: map['id'],
      name: map['name'] ?? '',
      muscleGroup: map['muscleGroup'] ?? '',
      description: map['description'],
      videoUrl: map['videoUrl'],
      caloriesPerRep: map['caloriesPerRep'] ?? 1,
      defaultCadence: map['defaultCadence'] ?? '2-0-2',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }

  // Método para convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'muscleGroup': muscleGroup,
      'description': description,
      'videoUrl': videoUrl,
      'caloriesPerRep': caloriesPerRep,
      'defaultCadence': defaultCadence,
      'imageUrls': imageUrls,
    };
  }

// Método para convertir a la clase Exercise (para usar en workouts)
  Exercise toExercise() {
    return Exercise(
      name: name,
      muscleGroup: muscleGroup,
      caloriesPerRep: caloriesPerRep,
      videoUrl: videoUrl,
      cadence: defaultCadence,
      sets: 3,
      reps: '10-12',
      rest: '60s',
      benchExerciseId: id, // Usar benchExerciseId en lugar de id
    );
  }
}