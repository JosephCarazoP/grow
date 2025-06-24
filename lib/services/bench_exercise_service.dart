// lib/rooms/fitness/services/bench_exercise_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../rooms/fitness/models/bench_exercise.dart';


class BenchExerciseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<BenchExercise>> getExercises() async {
    final snapshot = await _firestore.collection('benchExercises').get();

    return snapshot.docs
        .map((doc) {
      Map<String, dynamic> data = doc.data();
      data['id'] = doc.id;
      return BenchExercise.fromMap(data);
    })
        .toList();
  }
}