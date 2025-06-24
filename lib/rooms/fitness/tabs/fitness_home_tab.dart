import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/community_post.dart';
import '../models/workout.dart';
import '../screens/post_detail_page.dart';
import '../screens/workout_detail_screen.dart';
import 'fitness_routines_tab.dart';

class FitnessHomeTab extends StatefulWidget {
  final Map<String, dynamic> roomData;
  final Function(String) navigateToSection;
  final String userId;

  const FitnessHomeTab({
    Key? key,
    required this.roomData,
    required this.navigateToSection,
    required this.userId,
  }) : super(key: key);

  @override
  State<FitnessHomeTab> createState() => _FitnessHomeTabState();
}

class _FitnessHomeTabState extends State<FitnessHomeTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Workout> userWorkouts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Query for personalized workouts for this user
      final personalizedWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomData['id'])
          .where('type', isEqualTo: 'personalized')
          .where('clientId', isEqualTo: widget.userId);

      // Query for challenges (general workouts)
      final generalWorkoutsQuery = _firestore
          .collection('workouts')
          .where('roomId', isEqualTo: widget.roomData['id'])
          .where('type', isEqualTo: 'challenge');

      // Execute both queries
      final personalizedSnapshot = await personalizedWorkoutsQuery.get();
      final generalSnapshot = await generalWorkoutsQuery.get();

      final List<Workout> loadedWorkouts = [];

      // Process personalized workouts
      for (var doc in personalizedSnapshot.docs) {
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
        );

        loadedWorkouts.add(workout);
      }

      // Process general workouts (challenges)
      for (var doc in generalSnapshot.docs) {
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
        );

        loadedWorkouts.add(workout);
      }

      // Verifica si el widget sigue montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          userWorkouts = loadedWorkouts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading workouts: $e');
      // Verifica si el widget sigue montado antes de actualizar el estado
      if (mounted) {
        setState(() {
          isLoading = false;
          userWorkouts = [];
        });
      }
    }
  }

  // Helper methods for parsing workout data
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
            _buildWelcomeBanner(context),
            const SizedBox(height: 24),
            _buildUserWorkouts(context),
            const SizedBox(height: 32),
            _buildCommunityActivity(context),
            const SizedBox(height: 32),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleImage(String imageUrl, String postId) {
    return GestureDetector(
      onTap: () {
        // Usa el postId proporcionado para navegar
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PostDetailPage(
                  postId: postId,
                  roomId:
                      widget.roomData['id'] ??
                      '', // Añade un valor predeterminado
                ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                color: Colors.grey[850],
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey[850],
                child: const Icon(Icons.error, color: Colors.white70),
              ),
        ),
      ),
    );
  }

  Widget _buildMultipleImages(List<String> imageUrls, String postId) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Aquí está el error - Asegurate que postId no sea nulo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PostDetailPage(
                        postId: postId, // Asegúrate de que postId no sea nulo
                        roomId:
                            widget.roomData['id'] ??
                            '', // Proporciona un valor predeterminado
                      ),
                ),
              );
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey[850],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey[850],
                        child: const Icon(Icons.error, color: Colors.white70),
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserWorkouts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En el método _buildUserWorkouts, actualiza el botón "Ver todas"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tus rutinas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => widget.navigateToSection('routines'),
                child: Text(
                  'Ver todo',
                  style: TextStyle(
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          Container(
            height: 150,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.white),
          )
        else if (userWorkouts.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center_outlined,
                  size: 48,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No tienes rutinas asignadas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explora las rutinas disponibles o solicita una personalizada',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FitnessRoutinesTab(
                                  roomData: widget.roomData,
                                  navigateToSection: widget.navigateToSection,
                                  userId: widget.userId,
                                ),
                          ),
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Explorar rutinas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 180, // Reduced height to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: userWorkouts.length,
              itemBuilder:
                  (context, index) => _buildWorkoutCard(userWorkouts[index]),
            ),
          ),
      ],
    );
  }

  void _showAllWorkoutsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior con título y botón de cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Todas tus rutinas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),

              // Lista de rutinas
              Expanded(
                child:
                    userWorkouts.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes rutinas asignadas',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: userWorkouts.length,
                          itemBuilder: (context, index) {
                            final workout = userWorkouts[index];
                            return _buildWorkoutListItem(workout, context);
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkoutListItem(Workout workout, BuildContext context) {
    Color categoryColor = workout.getCategoryColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: workout.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            errorWidget:
                (context, url, error) => Container(
                  color: Colors.grey.shade900,
                  child: const Icon(Icons.error_outline, color: Colors.white70),
                ),
          ),
        ),
        title: Text(
          workout.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    workout.category,
                    style: TextStyle(fontSize: 10, color: categoryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${workout.durationMinutes} min • ${workout.days.length} días',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          Navigator.pop(context); // Cierra el modal
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => WorkoutDetailScreen(
                    workout: workout,
                    onStart: () {
                      // Lógica para iniciar el entrenamiento
                    },
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    Color categoryColor = workout.getCategoryColor();

    return Container(
      width: 218.0,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => WorkoutDetailScreen(
                    workout: workout,
                    onStart: () {
                      // Logic to start workout
                    },
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image with fixed height
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: workout.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey.shade900,
                      height: 100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey.shade900,
                      height: 100,
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.white70,
                      ),
                    ),
              ),
            ),

            // Content with compact padding
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tags row
                  SizedBox(
                    height: 20,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Category tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            workout.category,
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Type tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                workout.type == WorkoutType.personalized
                                    ? Colors.purple.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            workout.type == WorkoutType.personalized
                                ? 'PERSONAL'
                                : 'RETO',
                            style: TextStyle(
                              color:
                                  workout.type == WorkoutType.personalized
                                      ? Colors.purple
                                      : Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Title
                  Text(
                    workout.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Duration
                  Text(
                    '${workout.durationMinutes} min • ${workout.days.length} días',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all existing methods
  Widget _buildWelcomeBanner(BuildContext context) {
    // Existing implementation
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade800, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Bienvenido a ${widget.roomData['name']}!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.roomData['description'] ??
                'Tu espacio para estar en forma y saludable',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => widget.navigateToSection('workouts'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Empezar entrenamiento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.play_arrow_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Comunidad activa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => widget.navigateToSection('community'),
                child: Text(
                  'Ver todo',
                  style: TextStyle(
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Stream builder to get the latest posts
        StreamBuilder<QuerySnapshot>(
          stream:
          _firestore
              .collection('posts')
              .where('roomId', isEqualTo: widget.roomData['id'])
              .orderBy('createdAt', descending: true)
              .limit(2)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error al cargar los posts',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              );
            }

            final posts = snapshot.data?.docs ?? [];

            if (posts.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people,
                      size: 48,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay actividad reciente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡Sé el primero en compartir algo con la comunidad!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: posts.map((doc) {
                final postId = doc.id;
                final roomId = widget.roomData['id'] as String? ?? '';
                final postData = doc.data() as Map<String, dynamic>;
                final isRepost = postData['isRepost'] == true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRepost)
                        Padding(
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.withOpacity(0.2),
                                      Colors.teal.withOpacity(0.2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Icon(
                                  Icons.repeat_rounded,
                                  size: 16,
                                  color: Colors.greenAccent.shade400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: postData['userData']?['name'] ?? 'Usuario',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' reposteó esta publicación',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isRepost ? 12 : 16,
                          vertical: 0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: CommunityPost(
                              postId: postId,
                              roomId: roomId,
                              showFullContent: true,
                              onCommentAdded: () {},
                              onLikeRemoved: () {},
                              autoShowComments: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommunityPost({
    required String username,
    required String avatar,
    required String timeAgo,
    required String content,
    required int likes,
    required int comments,
    required String postId,
    List<String> imageUrls = const [],
    bool isRepost = false,
    Map<String, dynamic>? originalPostData,
  }) {
    final String roomId = widget.roomData['roomId'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('posts').doc(postId).snapshots(),
      builder: (context, snapshot) {
        bool userLiked = false;
        if (snapshot.hasData && snapshot.data != null) {
          final postData = snapshot.data!.data() as Map<String, dynamic>?;
          if (postData != null) {
            final likedBy = List<String>.from(postData['likedBy'] ?? []);
            userLiked = likedBy.contains(widget.userId);
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(postId: postId, roomId: roomId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRepost)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.2),
                                Colors.teal.withOpacity(0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.repeat_rounded,
                            size: 16,
                            color: Colors.greenAccent.shade400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: ' reposteó esta publicación',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isRepost ? 12 : 16,
                    vertical: 0,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: CachedNetworkImageProvider(avatar),
                            backgroundColor: Colors.grey[800],
                            child: avatar.isEmpty || avatar.contains('ui-avatars')
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Hace $timeAgo',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.more_horiz,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),

                      // Images section
                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        imageUrls.length == 1
                            ? _buildSingleImage(imageUrls.first, postId)
                            : _buildMultipleImages(imageUrls, postId),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildInteractionButton(
                            icon: userLiked ? Icons.favorite : Icons.favorite_border,
                            label: likes.toString(),
                            iconColor: userLiked ? Colors.red : Colors.white.withOpacity(0.7),
                            onTap: () {
                              _toggleLike(postId, userLiked);
                            },
                          ),
                          const SizedBox(width: 24),
                          _buildInteractionButton(
                            icon: Icons.chat_bubble_outline,
                            label: comments.toString(),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailPage(
                                    postId: postId,
                                    roomId: roomId,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          _buildInteractionButton(
                            icon: Icons.share_outlined,
                            onTap: () => widget.navigateToSection('community'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // También actualiza el método _buildInteractionButton para manejar el color personalizado
  Widget _buildInteractionButton({
    required IconData icon,
    String? label,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? Colors.white.withOpacity(0.7),
            size: 20,
          ),
          if (label != null) const SizedBox(width: 4),
          if (label != null)
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  // Método para manejar el like/unlike
  void _toggleLike(String postId, bool currentlyLiked) async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para dar like')),
      );
      return;
    }

    final String currentUserId = widget.userId;
    final DocumentReference postRef = _firestore
        .collection('posts')
        .doc(postId);
    final String roomId = widget.roomData['roomId'] as String? ?? '';
    try {
      // Create reference to the like document
      final likeRef = _firestore
          .collection('likes')
          .doc('${postId}_$currentUserId');

      final likeDoc = await likeRef.get();

      if (currentlyLiked) {
        // Remove like
        if (likeDoc.exists) {
          await likeRef.delete();
        }

        // Update post counter
        await postRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Add like
        await likeRef.set({
          'postId': postId,
          'userId': currentUserId,
          'roomId': roomId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update post counter
        await postRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al actualizar like')));
    }
  }
}
