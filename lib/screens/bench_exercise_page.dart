import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../rooms/fitness/models/bench_exercise.dart';
import '../rooms/fitness/admin/bench_exercise_form_screen.dart';

class BenchExercisesPage extends StatefulWidget {
  const BenchExercisesPage({Key? key}) : super(key: key);

  @override
  State<BenchExercisesPage> createState() => _BenchExercisesPageState();
}

class _BenchExercisesPageState extends State<BenchExercisesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de Ejercicios'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('benchExercises').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay ejercicios disponibles'),
            );
          }

          final exercises = snapshot.data!.docs.map((doc) {
            return BenchExercise.fromFirestore(doc);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: exercise.imageUrls.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      exercise.imageUrls.first,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.fitness_center),
                        );
                      },
                    ),
                  )
                      : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fitness_center),
                  ),
                  title: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Grupo: ${exercise.muscleGroup} • Cadencia: ${exercise.defaultCadence}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showExerciseForm(exercise),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteExercise(exercise),
                      ),
                    ],
                  ),
                  onTap: () => _showExerciseForm(exercise),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExerciseForm,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showExerciseForm([BenchExercise? exercise]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BenchExerciseFormPage(exercise: exercise),
    );

    if (result != null) {
      setState(() => _isLoading = true);

      try {
        final BenchExercise exerciseData = result['exercise'];
        final List<File> newImages = result['newImages'];

        // Referencia a la colección
        final exercisesRef = _firestore.collection('benchExercises');

        // Si es un nuevo ejercicio, crear un ID
        final String exerciseId = exerciseData.id ?? exercisesRef.doc().id;

        // Lista para almacenar todas las URLs de imágenes
        List<String> allImageUrls = List.from(exerciseData.imageUrls);

        // Subir nuevas imágenes si hay
        if (newImages.isNotEmpty) {
          for (var imageFile in newImages) {
            final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
            final storageRef = _storage.ref().child('bench_exercises/$exerciseId/$fileName');

            await storageRef.putFile(imageFile);
            final imageUrl = await storageRef.getDownloadURL();
            allImageUrls.add(imageUrl);
          }
        }

        // Actualizar el ejercicio con todas las URLs de imágenes
        final updatedExercise = BenchExercise(
          id: exerciseId,
          name: exerciseData.name,
          muscleGroup: exerciseData.muscleGroup,
          description: exerciseData.description,
          videoUrl: exerciseData.videoUrl,
          caloriesPerRep: exerciseData.caloriesPerRep,
          defaultCadence: exerciseData.defaultCadence,
          imageUrls: allImageUrls,
        );

        // Guardar en Firestore
        await exercisesRef.doc(exerciseId).set(updatedExercise.toFirestore());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ejercicio guardado correctamente')),
        );
      } catch (e) {
        print('Error al guardar ejercicio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteExercise(BenchExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        // Eliminar imágenes del storage
        if (exercise.imageUrls.isNotEmpty && exercise.id != null) {
          final storageRef = _storage.ref().child('bench_exercises/${exercise.id}');
          try {
            final listResult = await storageRef.listAll();
            for (var item in listResult.items) {
              await item.delete();
            }
          } catch (e) {
            print('Error al eliminar imágenes: $e');
          }
        }

        // Eliminar documento de Firestore
        if (exercise.id != null) {
          await _firestore.collection('benchExercises').doc(exercise.id).delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ejercicio eliminado correctamente')),
        );
      } catch (e) {
        print('Error al eliminar ejercicio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}