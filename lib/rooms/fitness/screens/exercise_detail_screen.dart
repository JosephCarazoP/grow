import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bench_exercise.dart';
import '../models/workout.dart' as workout_model;
import '../../../services/exercise_service.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;
  final Exercise? workoutExercise;

  const ExerciseDetailScreen({
    Key? key,
    required this.exerciseId,
    this.workoutExercise,
  }) : super(key: key);

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  BenchExercise? _benchExercise;
  Exercise? _exercise;
  YoutubePlayerController? _controller;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // If we already have the exercise data from workout, use it
    if (widget.workoutExercise != null) {
      _exercise = widget.workoutExercise;
      _setupYoutubeController();
      _isLoading = false;
    } else {
      _loadExercise();
    }
  }

  void _setupYoutubeController() {
    final String? videoUrl = _exercise?.videoUrl ?? _benchExercise?.videoUrl;
    if (videoUrl != null) {
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null) {
        _controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            controlsVisibleAtStart: true,
          ),
        );
      }
    }
  }

  Future<void> _loadExercise() async {
    setState(() => _isLoading = true);
    try {
      // Retrieve exercise data from Firestore
      final docRef = _firestore.collection('benchExercises').doc(widget.exerciseId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final benchExercise = BenchExercise.fromMap({...data, 'id': docSnapshot.id});

        setState(() {
          _benchExercise = benchExercise;
          _exercise = benchExercise.toExercise();
          _isLoading = false;
        });

        _setupYoutubeController();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ejercicio no encontrado'))
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el ejercicio: $e'))
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_isLoading ? 'Cargando ejercicio...' : _exercise?.name ?? 'Ejercicio'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _exercise == null
          ? const Center(child: Text('No se encontró el ejercicio', style: TextStyle(color: Colors.white)))
          : _buildExerciseDetails(),
    );
  }

  Widget _buildExerciseDetails() {
    // Get imageUrls from either exercise or benchExercise
    final List<String> imageUrls = _benchExercise?.imageUrls ?? [];
    final String? description = _benchExercise?.description;
    final String defaultCadence = _exercise?.cadence ?? _benchExercise?.defaultCadence ?? '2-0-2';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video de YouTube si está disponible
          if (_controller != null)
            YoutubePlayer(
              controller: _controller!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.blue,
              progressColors: const ProgressBarColors(
                playedColor: Colors.blue,
                handleColor: Colors.blueAccent,
              ),
            )
          else if (imageUrls.isNotEmpty)
            Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
              ),
              child: PageView.builder(
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.error, color: Colors.red));
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.blue,
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            Container(
              height: 230,
              width: double.infinity,
              color: Colors.grey.shade900,
              child: Center(
                child: Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.grey.shade800,
                ),
              ),
            ),

          // Información del ejercicio
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título y grupo muscular
                Text(
                  _exercise!.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _exercise!.muscleGroup ?? 'Sin grupo muscular',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_exercise!.caloriesPerRep ?? 1} cal/rep',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Parámetros del ejercicio si viene de un workout
                if (widget.workoutExercise != null) ...[
                  _buildSectionTitle('Parámetros configurados'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildParameterCard(
                        icon: Icons.repeat,
                        title: 'Series',
                        value: '${widget.workoutExercise!.sets}',
                      ),
                      const SizedBox(width: 8),
                      _buildParameterCard(
                        icon: Icons.format_list_numbered,
                        title: 'Repeticiones',
                        value: widget.workoutExercise!.reps,
                      ),
                      const SizedBox(width: 8),
                      _buildParameterCard(
                        icon: Icons.timer_outlined,
                        title: 'Descanso',
                        value: widget.workoutExercise!.rest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildParameterCard(
                    icon: Icons.speed,
                    title: 'Cadencia',
                    value: widget.workoutExercise!.cadence,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 24),
                ],

                // Descripción
                _buildSectionTitle('Descripción'),
                const SizedBox(height: 12),
                Text(
                  description ?? 'No hay descripción disponible para este ejercicio.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // Cadencia predeterminada
                _buildSectionTitle('Cadencia recomendada'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: 'Cadencia',
                  icon: Icons.speed_outlined,
                  iconColor: Colors.green,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        defaultCadence,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La cadencia indica el tiempo (en segundos) para cada fase del movimiento: excéntrica-pausa-concéntrica.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildParameterCard({
    required IconData icon,
    required String title,
    required String value,
    bool fullWidth = false,
  }) {
    return Expanded(
      flex: fullWidth ? 3 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}