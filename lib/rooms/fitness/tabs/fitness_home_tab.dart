import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/suscription_service.dart';
import '../../../widgets/suscription_alert.dart';
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
  SubscriptionInfo? subscriptionInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadWorkouts(),
      _checkSubscriptionStatus(),
    ]);
  }

  Future<void> _checkSubscriptionStatus() async {
    final info = await SubscriptionService.checkSubscriptionStatus(
      widget.roomData['id'] ?? '',
    );

    if (mounted) {
      setState(() {
        subscriptionInfo = info;
      });
    }
  }

  void _handleRenewal() {
    // Navegar al proceso de renovación
    final double price = (widget.roomData['price'] ?? 0).toDouble();
    final double discount = (widget.roomData['discount'] ?? 0).toDouble();
    final double discountedPrice = price * (1 - (discount / 100));

    _showRenewalDialog(context, discountedPrice);
  }

  void _showRenewalDialog(BuildContext context, double price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Renovar suscripción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Deseas renovar tu suscripción a esta sala?'),
            const SizedBox(height: 16),
            Text(
              'Precio: ₡${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Aquí implementarías el proceso de pago para renovación
              _processRenewal(price);
            },
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
  }

  Future<void> _processRenewal(double price) async {
    // Implementar lógica de renovación - similar al proceso de pago original
    // pero marcando que es una renovación para no perder datos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Proceso de renovación iniciado...'),
      ),
    );
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
      onRefresh: _loadData,
      color: Colors.blue,
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alerta de suscripción
            if (subscriptionInfo != null)
              SubscriptionAlert(
                subscriptionInfo: subscriptionInfo!,
                onRenewPressed: _handleRenewal,
              ),

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
    final roomName = widget.roomData['name'] ?? 'Fitness';
    final String shortDescription = widget.roomData['shortDescription'] ?? 'Tu espacio personal para transformar tu cuerpo y mente';
    final String longDescription = widget.roomData['longDescription'] ?? shortDescription;
    final roomImageUrl = widget.roomData['.'];

    // Responsive values
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    final isLargeScreen = screenWidth >= 600;

    // Dynamic values based on screen size
    final bannerHeight = isSmallScreen ? 200.0 : (isMediumScreen ? 220.0 : 240.0);
    final expandedHeight = isSmallScreen ? 280.0 : (isMediumScreen ? 320.0 : 360.0);
    final titleFontSize = isSmallScreen ? 22.0 : (isMediumScreen ? 26.0 : 28.0);
    final descriptionFontSize = isSmallScreen ? 12.0 : 13.0;
    final buttonHeight = isSmallScreen ? 36.0 : 40.0;
    final buttonFontSize = isSmallScreen ? 11.0 : 12.0;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 14.0 : 18.0;

    return Container(
      margin: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Background image with overlay
            if (roomImageUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: roomImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black),
                  errorWidget: (context, url, error) => Container(color: Colors.black),
                ),
              ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.1, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            _BannerContent(
              roomName: roomName,
              shortDescription: shortDescription,
              longDescription: longDescription,
              navigateToSection: widget.navigateToSection,
              bannerHeight: bannerHeight,
              expandedHeight: expandedHeight,
              titleFontSize: titleFontSize,
              descriptionFontSize: descriptionFontSize,
              buttonHeight: buttonHeight,
              buttonFontSize: buttonFontSize,
              verticalPadding: verticalPadding,
              isSmallScreen: isSmallScreen,
            ),
          ],
        ),
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
              children:
                  posts.map((doc) {
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
                              padding: const EdgeInsets.only(
                                left: 24,
                                right: 24,
                                bottom: 4,
                              ),
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
                                            text:
                                                postData['userData']?['name'] ??
                                                'Usuario',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' reposteó esta publicación',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
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
                builder:
                    (context) => PostDetailPage(postId: postId, roomId: roomId),
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
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 4,
                    ),
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
                            child:
                                avatar.isEmpty || avatar.contains('ui-avatars')
                                    ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
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
                            icon:
                                userLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                            label: likes.toString(),
                            iconColor:
                                userLiked
                                    ? Colors.red
                                    : Colors.white.withOpacity(0.7),
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
                                  builder:
                                      (context) => PostDetailPage(
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

class _BannerContent extends StatefulWidget {
  final String roomName;
  final String shortDescription;
  final String longDescription;
  final Function(String) navigateToSection;
  final double bannerHeight;
  final double expandedHeight;
  final double titleFontSize;
  final double descriptionFontSize;
  final double buttonHeight;
  final double buttonFontSize;
  final double verticalPadding;
  final bool isSmallScreen;

  const _BannerContent({
    required this.roomName,
    required this.shortDescription,
    required this.longDescription,
    required this.navigateToSection,
    required this.bannerHeight,
    required this.expandedHeight,
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.verticalPadding,
    required this.isSmallScreen,
  });

  @override
  State<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends State<_BannerContent> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isExpanded ? widget.expandedHeight : widget.bannerHeight,
      padding: EdgeInsets.all(widget.verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room type pill
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSmallScreen ? 10 : 12,
              vertical: widget.isSmallScreen ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade600, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "FITNESS",
              style: TextStyle(
                fontSize: widget.isSmallScreen ? 9 : 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.7,
              ),
            ),
          ),

          SizedBox(height: widget.isSmallScreen ? 12 : 16),

          // Room name
          Text(
            widget.roomName,
            style: TextStyle(
              fontSize: widget.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -0.5,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),

          SizedBox(height: widget.isSmallScreen ? 8 : 10),

          // Description section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedCrossFade(
                    firstChild: Text(
                      widget.longDescription,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.descriptionFontSize,
                        height: 1.4,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    secondChild: Scrollbar(
                      radius: const Radius.circular(8),
                      child: SingleChildScrollView(
                        child: Text(
                          widget.longDescription,
                          style: TextStyle(
                            fontSize: widget.descriptionFontSize,
                            height: 1.4,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                ),

                // Ver más/menos button
                if (widget.longDescription.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? "Ver menos" : "Ver más",
                            style: TextStyle(
                              color: Colors.blue.shade300,
                              fontWeight: FontWeight.w500,
                              fontSize: widget.descriptionFontSize - 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.blue.shade300,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: widget.isSmallScreen ? 10 : 14),

          // Buttons
          Row(
            children: [
              // Start button
              Expanded(
                flex: widget.isSmallScreen ? 1 : 2,
                child: Container(
                  height: widget.buttonHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade100],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.navigateToSection('routines'),
                      child: Center(
                        child: Text(
                          'EMPEZAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: widget.buttonFontSize,
                            letterSpacing: 0.7,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Request routine button
              Expanded(
                flex: widget.isSmallScreen ? 2 : 3,
                child: Container(
                  height: widget.buttonHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade700,
                        Colors.grey.shade800,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade600,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Próximamente: Solicitud de rutina personalizada'),
                          ),
                        );
                      },
                      child: Center(
                        child: FittedBox(
                          child: Text(
                            'SOLICITAR RUTINA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: widget.buttonFontSize,
                              letterSpacing: 0.7,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}