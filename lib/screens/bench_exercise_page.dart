import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../rooms/fitness/models/bench_exercise.dart';
import '../rooms/fitness/admin/bench_exercise_form_screen.dart';
import '../widgets/drawer.dart';

class BenchExercisesPage extends StatefulWidget {
  const BenchExercisesPage({Key? key}) : super(key: key);

  @override
  State<BenchExercisesPage> createState() => _BenchExercisesPageState();
}

class _BenchExercisesPageState extends State<BenchExercisesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedMuscleGroup = 'Todos';

  final List<String> _muscleGroups = [
    'Todos', 'Pecho', 'Espalda', 'Piernas', 'Brazos', 'Hombros', 'Core', 'Cardio'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text(
            'Banco de Ejercicios',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildSearchSection(),
            _buildFilterChips(),
            Expanded(child: _buildExercisesList()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showExerciseForm,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar ejercicios...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[500]),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _muscleGroups.length,
        itemBuilder: (context, index) {
          final group = _muscleGroups[index];
          final isSelected = _selectedMuscleGroup == group;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(group),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedMuscleGroup = group;
                });
              },
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.white, // Fondo blanco cuando está seleccionado
              checkmarkColor: Colors.black, // Check negro cuando está seleccionado
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white, // Negro cuando seleccionado, blanco cuando no
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? Colors.white : Colors.grey[700]!,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildExercisesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('benchExercises').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var exercises = snapshot.data!.docs
            .map((doc) => BenchExercise.fromFirestore(doc))
            .toList();

        exercises = _applyFilters(exercises);

        if (exercises.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: exercises.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildExerciseCard(exercises[index]);
          },
        );
      },
    );
  }

  Widget _buildExerciseCard(BenchExercise exercise) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: InkWell(
        onTap: () => _showExerciseForm(exercise),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Imagen o placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: exercise.imageUrls.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    exercise.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.fitness_center,
                        color: Colors.grey[600],
                        size: 30,
                      );
                    },
                  ),
                )
                    : Icon(
                  Icons.fitness_center,
                  color: Colors.grey[600],
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // Información del ejercicio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.muscleGroup,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (exercise.description != null && exercise.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.description!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Botones de acción
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: Colors.blue,
                    onPressed: () => _showExerciseForm(exercise),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _deleteExercise(exercise),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay ejercicios',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer ejercicio',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otros términos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<BenchExercise> _applyFilters(List<BenchExercise> exercises) {
    return exercises.where((exercise) {
      final matchesSearch = _searchQuery.isEmpty ||
          exercise.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          exercise.muscleGroup.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesMuscleGroup = _selectedMuscleGroup == 'Todos' ||
          exercise.muscleGroup == _selectedMuscleGroup;

      return matchesSearch && matchesMuscleGroup;
    }).toList();
  }

  Future<void> _showExerciseForm([BenchExercise? exercise]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BenchExerciseFormPage(exercise: exercise),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);

      try {
        final BenchExercise exerciseData = result['exercise'];
        final List<File> newImages = result['newImages'] ?? [];

        final exercisesRef = _firestore.collection('benchExercises');
        final String exerciseId = exerciseData.id ?? exercisesRef.doc().id;

        List<String> allImageUrls = List.from(exerciseData.imageUrls);

        if (newImages.isNotEmpty) {
          for (var imageFile in newImages) {
            final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
            final storageRef = _storage.ref().child('bench_exercises/$exerciseId/$fileName');

            await storageRef.putFile(imageFile);
            final imageUrl = await storageRef.getDownloadURL();
            allImageUrls.add(imageUrl);
          }
        }

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

        await exercisesRef.doc(exerciseId).set(updatedExercise.toFirestore());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ejercicio guardado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteExercise(BenchExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${exercise.name}"?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        if (exercise.imageUrls.isNotEmpty && exercise.id != null) {
          final storageRef = _storage.ref().child('bench_exercises/${exercise.id}');
          final listResult = await storageRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        }

        if (exercise.id != null) {
          await _firestore.collection('benchExercises').doc(exercise.id).delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ejercicio eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}