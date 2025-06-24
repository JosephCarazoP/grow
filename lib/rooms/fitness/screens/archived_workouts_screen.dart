import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/workout.dart';

class ArchivedWorkoutsScreen extends StatefulWidget {
  final String roomId;
  final String userId;

  const ArchivedWorkoutsScreen({
    Key? key,
    required this.roomId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ArchivedWorkoutsScreen> createState() => _ArchivedWorkoutsScreenState();
}

class _ArchivedWorkoutsScreenState extends State<ArchivedWorkoutsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Workout> archivedWorkouts = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadArchivedWorkouts();
  }

  Future<void> _loadArchivedWorkouts() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Consulta para obtener rutinas generales archivadas
      final generalWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomId)
          .where('type', isEqualTo: 'challenge')
          .where('archived', isEqualTo: true);

      // Consulta para obtener rutinas personalizadas archivadas
      final personalizedWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomId)
          .where('type', isEqualTo: 'personalized')
          .where('clientId', isEqualTo: widget.userId)
          .where('archived', isEqualTo: true);

      // Ejecutar las consultas
      final generalSnapshots = await generalWorkoutsQuery.get();
      final personalizedSnapshots = await personalizedWorkoutsQuery.get();

      final List<Workout> loadedWorkouts = [];

      // Procesar rutinas generales archivadas
      for (var doc in generalSnapshots.docs) {
        final data = doc.data();
        final workout = Workout(
          id: doc.id,
          title: data['title'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          level: _parseWorkoutLevel(data['level']),
          durationMinutes: data['durationMinutes'] ?? 0,
          estimatedCalories: data['estimatedCalories'] ?? 0,
          type: WorkoutType.challenge,
          days: _parseDays(data['days'] ?? []),
          archived: true,
        );
        loadedWorkouts.add(workout);
      }

      // Procesar rutinas personalizadas archivadas
      for (var doc in personalizedSnapshots.docs) {
        final data = doc.data();
        final workout = Workout(
          id: doc.id,
          title: data['title'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          level: _parseWorkoutLevel(data['level']),
          durationMinutes: data['durationMinutes'] ?? 0,
          estimatedCalories: data['estimatedCalories'] ?? 0,
          type: WorkoutType.personalized,
          clientName: data['clientName'],
          clientId: data['clientId'],
          days: _parseDays(data['days'] ?? []),
          archived: true,
        );
        loadedWorkouts.add(workout);
      }

      setState(() {
        archivedWorkouts = loadedWorkouts;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading archived workouts: $e');
      setState(() {
        error = 'Error al cargar las rutinas archivadas: $e';
        isLoading = false;
      });
    }
  }

  // Método auxiliar para parsear el nivel de entrenamiento (igual que en FitnessRoutinesTab)
  WorkoutLevel _parseWorkoutLevel(String? level) {
    if (level == null) return WorkoutLevel.intermediate;
    switch (level.toLowerCase()) {
      case 'beginner':
      case 'inicial':
      case 'principiante':
        return WorkoutLevel.beginner;
      case 'advanced':
      case 'avanzado':
        return WorkoutLevel.advanced;
      case 'intermediate':
      case 'medio':
      default:
        return WorkoutLevel.intermediate;
    }
  }

  // Método auxiliar para parsear los días de entrenamiento (igual que en FitnessRoutinesTab)
  List<WorkoutDay> _parseDays(List<dynamic> daysData) {
    return daysData.map((dayData) {
      final Map<String, dynamic> day = dayData as Map<String, dynamic>;
      return WorkoutDay(
        dayOfWeek: day['dayOfWeek'] ?? 1,
        warmup: day['warmup'],
        exercises: _parseExercises(day['exercises'] ?? []),
        finalExercises: day['finalExercises'],
      );
    }).toList();
  }

  // Método auxiliar para parsear los ejercicios (igual que en FitnessRoutinesTab)
  List<Exercise> _parseExercises(List<dynamic> exercisesData) {
    return exercisesData.map((exerciseData) {
      final Map<String, dynamic> exercise = exerciseData as Map<String, dynamic>;
      return Exercise(
        name: exercise['name'] ?? '',
        sets: exercise['sets'] ?? 1,
        reps: exercise['reps'] ?? '',
        rest: exercise['rest'] ?? '',
        cadence: exercise['cadence'] ?? '',
        videoUrl: exercise['videoUrl'],
      );
    }).toList();
  }

  Future<void> _unarchiveWorkout(Workout workout) async {
    try {
      await _firestore.collection('workouts').doc(workout.id).update({
        'archived': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina restaurada correctamente')),
      );

      // Recargar la lista
      _loadArchivedWorkouts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al restaurar la rutina: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Rutinas archivadas',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
        onRefresh: _loadArchivedWorkouts,
        color: Colors.blue,
        backgroundColor: Colors.black,
        child: archivedWorkouts.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: archivedWorkouts.length,
          itemBuilder: (context, index) {
            final workout = archivedWorkouts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildArchivedWorkoutItem(workout),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined,
                color: Colors.white.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              'No tienes rutinas archivadas',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedWorkoutItem(Workout workout) {
    Color categoryColor = workout.getCategoryColor();
    Color levelColor = workout.getLevelColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: workout.imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                height: 150,
                width: double.infinity,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade900,
                height: 150,
                width: double.infinity,
                child: const Icon(Icons.error_outline, color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        workout.category,
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: levelColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        workout.levelText,
                        style: TextStyle(
                          color: levelColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  workout.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _unarchiveWorkout(workout),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Restaurar rutina'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}