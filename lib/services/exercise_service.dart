import 'package:cloud_firestore/cloud_firestore.dart';
import '../rooms/fitness/models/bench_exercise.dart';

class ExerciseService {
  final String? id;
  final String name;
  final String muscleGroup;
  final String? description;
  final int caloriesPerRep;
  final String defaultCadence;
  final String? videoUrl;
  final List<String> imageUrls;

  ExerciseService({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.caloriesPerRep,
    required this.defaultCadence,
    this.description,
    this.videoUrl,
    this.imageUrls = const [],
  });

  // Factory constructor to create a BenchExercise from a Firestore document
  factory ExerciseService.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ExerciseService(
      id: doc.id,
      name: data['name'] ?? '',
      muscleGroup: data['muscleGroup'] ?? '',
      description: data['description'],
      caloriesPerRep: data['caloriesPerRep'] ?? 1,
      defaultCadence: data['defaultCadence'] ?? '2-0-2',
      videoUrl: data['videoUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }

  // Convert the BenchExercise instance to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'muscleGroup': muscleGroup,
      'description': description,
      'caloriesPerRep': caloriesPerRep,
      'defaultCadence': defaultCadence,
      'videoUrl': videoUrl,
      'imageUrls': imageUrls,
    };
  }

  // Create a copy of this BenchExercise with some fields replaced
  ExerciseService copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? description,
    int? caloriesPerRep,
    String? defaultCadence,
    String? videoUrl,
    List<String>? imageUrls,
  }) {
    return ExerciseService(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      description: description ?? this.description,
      caloriesPerRep: caloriesPerRep ?? this.caloriesPerRep,
      defaultCadence: defaultCadence ?? this.defaultCadence,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  Exercise toExercise({
    int sets = 3,
    String reps = '12',
    String rest = '60 seg',
    String? cadence,
  }) {
    return Exercise(
      name: name,
      sets: sets,
      reps: reps,
      rest: rest,
      cadence: cadence ?? defaultCadence,
      muscleGroup: muscleGroup,
      caloriesPerRep: caloriesPerRep,
      videoUrl: videoUrl,
      benchExerciseId: id,
    );
  }
}