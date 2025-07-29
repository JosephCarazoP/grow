import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout.dart';
import '../screens/workout_detail_screen.dart';

class FitnessRoutinesTab extends StatefulWidget {
  final Map<String, dynamic> roomData;
  final Function(String) navigateToSection;
  final String userId;

  const FitnessRoutinesTab({
    Key? key,
    required this.roomData,
    required this.navigateToSection,
    required this.userId,
  }) : super(key: key);

  @override
  State<FitnessRoutinesTab> createState() => _FitnessRoutinesTabState();
}

class _FitnessRoutinesTabState extends State<FitnessRoutinesTab> {
  final Set<String> _expandedWorkouts = {};
  final List<String> categories = [
    'Todos',
    'HIIT',
    'Fuerza',
    'Cardio',
    'Yoga',
    'Flexibilidad',
  ];
  String selectedCategory = 'Todos';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Workout> workouts = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Consulta para obtener rutinas generales (no personalizadas)
      final generalWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomData['id'])
          .where('type', isEqualTo: 'challenge')
          .where('archived', isEqualTo: false);

      // Consulta para obtener rutinas personalizadas para este usuario específico
      final personalizedWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomData['id'])
          .where('type', isEqualTo: 'personalized')
          .where('clientId', isEqualTo: widget.userId)
          .where('archived', isEqualTo: false);

      // Ejecutar ambas consultas
      final generalWorkoutsSnapshot = await generalWorkoutsQuery.get();
      final personalizedWorkoutsSnapshot =
          await personalizedWorkoutsQuery.get();

      final List<Workout> loadedWorkouts = [];

      // Procesar rutinas generales
      for (var doc in generalWorkoutsSnapshot.docs) {
        final data = doc.data();

        // Convertir los datos de Firestore a nuestro modelo Workout
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
          archived: data['archived'] ?? false,
        );

        loadedWorkouts.add(workout);
      }

      // Procesar rutinas personalizadas
      for (var doc in personalizedWorkoutsSnapshot.docs) {
        final data = doc.data();

        // Convertir los datos de Firestore a nuestro modelo Workout
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
        );

        loadedWorkouts.add(workout);
      }

      // Verificar si el widget sigue montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          workouts = loadedWorkouts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading workouts: $e');

      // Verificar si el widget sigue montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          error = 'Error al cargar las rutinas: $e';
          isLoading = false;
        });
      }
    }
  }

  // Método auxiliar para parsear el nivel de entrenamiento
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

  // Método auxiliar para parsear los días de entrenamiento
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

  // Método auxiliar para parsear los ejercicios
  List<Exercise> _parseExercises(List<dynamic> exercisesData) {
    return exercisesData.map((exerciseData) {
      final Map<String, dynamic> exercise =
          exerciseData as Map<String, dynamic>;

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

  List<Workout> get filteredWorkouts {
    if (selectedCategory == 'Todos') {
      return workouts;
    } else {
      return workouts
          .where((workout) => workout.category == selectedCategory)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      color: Colors.blue,
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategorySelector(),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (error != null)
              _buildErrorWidget()
            else if (filteredWorkouts.isEmpty)
              _buildEmptyState()
            else
              _buildRoutinesList(),
            const SizedBox(height: 100), // Extra space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWorkouts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              color: Colors.white.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              selectedCategory == 'Todos'
                  ? 'No hay rutinas disponibles en esta sala'
                  : 'No hay rutinas de $selectedCategory disponibles',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // El resto de widgets se mantienen igual
  Widget _buildCategorySelector() {
    // Código existente sin cambios
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color:
                        isSelected
                            ? Colors.blue.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoutinesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Rutinas disponibles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ...filteredWorkouts
              .map(
                (workout) => Column(
                  children: [
                    _buildWorkoutItem(workout),
                    const SizedBox(height: 16),
                  ],
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(Workout workout) {
    final bool isExpanded = _expandedWorkouts.contains(workout.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Collapsible header (always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedWorkouts.remove(workout.id);
                  } else {
                    _expandedWorkouts.add(workout.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Workout thumbnail with badge overlay
                    Stack(
                      children: [
                        // Image container
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: workout.imageUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey.shade900,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white54,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey.shade900,
                                    child: const Icon(
                                      Icons.fitness_center,
                                      color: Colors.white38,
                                    ),
                                  ),
                            ),
                          ),
                        ),

                        // Type badge positioned at the top-right of the image
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  workout.type == WorkoutType.personalized
                                      ? Colors.purpleAccent
                                      : Colors.blueAccent,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Icon(
                              workout.type == WorkoutType.personalized
                                  ? Icons.person
                                  : Icons.emoji_events,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Title and category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final typeText =
                                  workout.type == WorkoutType.personalized
                                      ? "Personalizado"
                                      : "Reto";
                              final useAbbreviation = availableWidth < 220;

                              return Row(
                                children: [
                                  Tooltip(
                                    message: typeText,
                                    child: Text(
                                      useAbbreviation &&
                                              workout.type ==
                                                  WorkoutType.personalized
                                          ? "Personal"
                                          : typeText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            workout.type ==
                                                    WorkoutType.personalized
                                                ? Colors.purpleAccent
                                                : Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 2,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.fitness_center,
                                    size: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      workout.category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 2,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${workout.durationMinutes}m',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Expand/collapse icon with rotation animation
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0, end: isExpanded ? 0.5 : 0),
                      builder: (_, value, __) {
                        return Transform.rotate(
                          angle: value * 3.14159,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Animated expanded content
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Container(
                height: isExpanded ? null : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),

                      // Image section
                      Stack(
                        children: [
                          // Main image (no badge overlay)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Hero(
                              tag: 'workout-${workout.id}',
                              child: CachedNetworkImage(
                                imageUrl: workout.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: const Color(0xFF121212),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white70,
                                              ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: const Color(0xFF121212),
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.white30,
                                        size: 28,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          // Removed the personalized badge since it's redundant
                        ],
                      ),

                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats row
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildStat(
                                      Icons.timer_outlined,
                                      '${workout.durationMinutes} min',
                                      'Duración',
                                    ),
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  Expanded(
                                    child: _buildStat(
                                      Icons.local_fire_department_outlined,
                                      '${workout.estimatedCalories} kcal',
                                      'Calorías',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Actions row
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => WorkoutDetailScreen(
                                                workout: workout,
                                                roomId:
                                                    widget.roomData['id'] ?? '',
                                                onStart: () {
                                                  // Logic to start workout
                                                },
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      'Comenzar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildIconButton(Icons.info_outline, () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => WorkoutDetailScreen(
                                            workout: workout,
                                            roomId: widget.roomData['id'] ?? '',
                                            onStart: () {
                                              // Logic to start workout
                                            },
                                          ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                _buildMoreOptionsButton(workout),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildMoreOptionsButton(Workout workout) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.white70, size: 16),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.black,
        elevation: 8,
        offset: const Offset(0, 8),
        onSelected: (value) async {
          if (value == 'archive') {
            await _archiveWorkout(workout);
          } else if (value == 'delete') {
            await _deleteWorkout(workout);
          }
        },
        itemBuilder:
            (context) => [
              PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    const Text(
                      'Archivar rutina',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Eliminar rutina',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
      ),
    );
  }

  Future<void> _archiveWorkout(Workout workout) async {
    try {
      await _firestore.collection('workouts').doc(workout.id).update({
        'archived': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina archivada correctamente')),
      );

      // Recargar la lista
      _loadWorkouts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al archivar la rutina: $e')),
      );
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'Eliminar rutina',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              '¿Estás seguro de que deseas eliminar esta rutina? Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('workouts').doc(workout.id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina eliminada correctamente')),
      );

      // Recargar la lista
      _loadWorkouts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la rutina: $e')),
      );
    }
  }
}
