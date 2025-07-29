import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/workout_tracking_service.dart';
import '../models/workout.dart';

class WorkoutCompletionScreen extends StatefulWidget {
  final Workout workout;
  final String dayName;
  final Map<String, double?> weights;
  final int dayNumber;
  final int duration;
  final int caloriesBurned;
  final int score;
  final String roomId;

  const WorkoutCompletionScreen({
    Key? key,
    required this.workout,
    required this.dayName,
    required this.weights,
    required this.dayNumber,
    required this.duration,
    required this.caloriesBurned,
    required this.score,
    required this.roomId,
  }) : super(key: key);

  @override
  State<WorkoutCompletionScreen> createState() => _WorkoutCompletionScreenState();
}

class _WorkoutCompletionScreenState extends State<WorkoutCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _contentController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _commentController = TextEditingController();
  bool _isSharing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    ));

    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      _contentController.forward();
    });

    // Vibrate on completion
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _shareProgressToRoom() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtener datos del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      // Usar el roomId que viene desde el widget
      String actualRoomId = widget.roomId;

      // Debug para verificar el roomId
      print('=== WORKOUT COMPLETION DEBUG ===');
      print('widget.roomId: ${widget.roomId}');

      // Si el roomId está vacío, obtenerlo de la sala fitness
      if (actualRoomId.isEmpty) {
        final roomSnapshot = await FirebaseFirestore.instance
            .collection('rooms')
            .where('type', isEqualTo: 'fitness')
            .limit(1)
            .get();

        if (roomSnapshot.docs.isNotEmpty) {
          actualRoomId = roomSnapshot.docs.first.id;
          print('Found roomId from Firestore: $actualRoomId');
        }
      }

      // Crear el contenido del post
      String postContent = '¡Acabo de completar mi entrenamiento del día ${widget.dayNumber}! 💪\n\n';
      postContent += '📊 Estadísticas:\n';
      postContent += '⏱️ Duración: ${_formatDuration(widget.duration)}\n';
      postContent += '🔥 Calorías quemadas: ${widget.caloriesBurned}\n';
      postContent += '💯 Puntuación: ${widget.score} puntos\n\n';
      postContent += '#FitnessGrowApp #Día${widget.dayNumber}Completado';

      // Crear el post con el roomId correcto
      await FirebaseFirestore.instance.collection('posts').add({
        'content': postContent,
        'userId': user.uid,
        'roomId': actualRoomId,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'repostsCount': 0,
        'likedBy': [],
        'userData': userData,
        'imageUrls': [],
        'videoData': [],
        'isRepost': false,
        'isWorkoutCompletion': true,
        'workoutData': {
          'workoutId': widget.workout.id,
          'workoutTitle': widget.workout.title,
          'dayNumber': widget.dayNumber,
          'duration': widget.duration,
          'caloriesBurned': widget.caloriesBurned,
          'score': widget.score,
        }
      });

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Tu progreso ha sido compartido con la comunidad!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navegar de vuelta cerrando todas las pantallas hasta el inicio
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      print('Error al compartir progreso: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Future<void> _finishWorkout() async {
    setState(() => _isSaving = true);

    // Save comment and workout data
    final comment = _commentController.text.trim();
    if (comment.isNotEmpty) {
      // Save comment to database
    }

    // Save weights
    widget.weights.forEach((exercise, weight) {
      if (weight != null) {
        // Save to database
      }
    });

    // Marcar el día como completado
    await WorkoutTrackingService.markDayAsCompleted(
      widget.workout.id,
      widget.dayName,
    );

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      // Pop hasta llegar a la pantalla de rutinas
      Navigator.of(context).pop(); // Cerrar WorkoutCompletionScreen
      Navigator.of(context).pop(); // Cerrar WorkoutSessionScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient effect
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.5,
                    colors: [
                      Colors.green.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),

                  // Success animation
                  AnimatedBuilder(
                    animation: _checkController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF2E7D32),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check,
                            size: 70 * _checkAnimation.value,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Content with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          '¡Entrenamiento completado!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        Text(
                          widget.dayName,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sumaste un día más',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Share button
                      ElevatedButton(
                        onPressed: _shareProgressToRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Compartir avance en la sala',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),

                        const SizedBox(height: 24),

                        // Comment field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 3,
                            maxLength: 200,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: '¿Querés dejar un comentario sobre el día?',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              counterStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Finish button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _finishWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                            : const Text(
                          'Finalizar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}