import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/workout_tracking_service.dart';
import '../screens/workout_completion_screen.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/workout.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Workout workout;
  final int? dayIndex;
  final String roomId;

  const WorkoutSessionScreen({
    Key? key,
    required this.workout,
    this.dayIndex,
    required this.roomId,
  }) : super(key: key);

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  Set<String> _completedDays = {};

  int _currentExerciseIndex = -1;
  int? _selectedDayIndex;
  final Map<String, double?> _weights = {};
  final Map<String, double?> _previousWeights = {};
  bool _isLoading = false;
  bool _showDaySelection = true;

  // Countdown timer
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  @override
  void initState() {
    super.initState();
    _selectedDayIndex = widget.dayIndex;
    _showDaySelection = widget.dayIndex == null;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )
      ..repeat(reverse: true);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )
      ..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    _fadeController.forward();
    _slideController.forward();

    _loadPreviousWeights();
    _loadCompletedDays(); // Agregar esta línea

    if (!_showDaySelection) {
      _startCountdown();
    }
  }

  Future<void> _loadCompletedDays() async {
    final completed = await WorkoutTrackingService.getCompletedDays(widget.workout.id);
    if (mounted) {
      setState(() {
        _completedDays = completed;
      });
    }
  }

  void _loadPreviousWeights() {
    // Mock data - in real app, load from Firestore
    _previousWeights['Press de banca plano'] = 20.0;
    _previousWeights['Remo con barra'] = 35.0;
  }

  void _startCountdown() {
    _countdown = 5;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown == 0) {
        timer.cancel();
        _nextExercise();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  WorkoutDay get _currentDay => widget.workout.days[_selectedDayIndex!];

  bool get _hasWarmup =>
      _currentDay.warmup != null && _currentDay.warmup!.isNotEmpty;

  int get _totalExercises =>
      _currentDay.exercises.length + (_hasWarmup ? 1 : 0);

  void _selectDay(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDayIndex = index;
      _showDaySelection = false;
    });
    _startCountdown();
  }

  void _nextExercise() {
    HapticFeedback.lightImpact();
    if (_currentExerciseIndex < _totalExercises - 1) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentExerciseIndex++;
        });
        _fadeController.forward();
        _slideController.forward(from: 0);
      });
    }
  }

  void _previousExercise() {
    HapticFeedback.lightImpact();
    if (_currentExerciseIndex > 0) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentExerciseIndex--;
        });
        _fadeController.forward();
        _slideController.forward(from: 0);
      });
    }
  }

  void _completeWorkout() async {
    setState(() => _isLoading = true);

    try {
      // Obtener el roomId correcto
      String actualRoomId = '';

      // Primero intentar obtener el roomId del workout
      final workoutDoc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workout.id)
          .get();

      if (workoutDoc.exists) {
        actualRoomId = workoutDoc.data()?['roomId'] ?? '';
      }

      // Si no se encontró, buscar la sala fitness
      if (actualRoomId.isEmpty) {
        final roomSnapshot = await FirebaseFirestore.instance
            .collection('rooms')
            .where('type', isEqualTo: 'fitness')
            .limit(1)
            .get();

        if (roomSnapshot.docs.isNotEmpty) {
          actualRoomId = roomSnapshot.docs.first.id;
        }
      }

      // Navegación con el roomId correcto
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutCompletionScreen(
              workout: widget.workout,
              dayName: _currentDay.dayName,
              weights: _weights,
              dayNumber: (_selectedDayIndex ?? 0) + 1,
              duration: widget.workout.durationMinutes,
              caloriesBurned: widget.workout.durationMinutes * 5, // Estimated calories
              score: 85, // Default score
              roomId: actualRoomId, // Usar el roomId obtenido
            ),
          ),
        );
      }
    } catch (e) {
      print('Error getting roomId: $e');
      // En caso de error, navegar de todos modos con string vacío
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutCompletionScreen(
              workout: widget.workout,
              dayName: _currentDay.dayName,
              weights: _weights,
              dayNumber: (_selectedDayIndex ?? 0) + 1,
              duration: widget.workout.durationMinutes,
              caloriesBurned: widget.workout.durationMinutes * 5,
              score: 85,
              roomId: '', // Se manejará en WorkoutCompletionScreen
            ),
          ),
        );
      }
    }
  }

  Widget _buildCompletionScreen() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _showDaySelection
            ? _buildDaySelectionScreen()
            : _currentExerciseIndex == -1
            ? _buildWelcomeScreen()
            : _currentExerciseIndex < _totalExercises
            ? _buildExerciseScreen()
            : _buildCompletionScreen(),
      ),
    );
  }

  Widget _buildDaySelectionScreen() {
    return Container(
      color: Colors.black,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Header ultra minimalista
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Título simple y elegante
            Text(
              'Selecciona tu día',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 60),

            // Lista de días con diseño limpio
            Expanded(
              child: ListView.builder(
                itemCount: widget.workout.days.length,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final day = widget.workout.days[index];
                  final hasWarmup = day.warmup != null && day.warmup!.isNotEmpty;
                  final isCompleted = _completedDays.contains(day.dayName);

                  return GestureDetector(
                    onTap: () {  // Removida la condición isCompleted ? null :
                      HapticFeedback.selectionClick();
                      _selectDay(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 100,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.08)
                            : Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // Número del día o check
                            if (isCompleted)
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                  size: 28,
                                ),
                              )
                            else
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),

                            const SizedBox(width: 24),

                            // Información
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        day.dayName,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: isCompleted
                                              ? Colors.green
                                              : Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'COMPLETADO',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '${day.exercises.length} ejercicios',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.4),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      if (hasWarmup) ...[
                                        Text(
                                          '  •  ',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.2),
                                            fontSize: 14,
                                          ),
                                        ),
                                        Icon(
                                          Icons.whatshot,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.4),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Calentamiento',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(0.4),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Indicador sutil
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted ? Icons.refresh : Icons.arrow_forward,  // Cambio de icono
                                size: 16,
                                color: isCompleted
                                    ? Colors.green
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Espacio inferior
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_slideAnimation),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Text(
                _currentDay.dayName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.workout.durationMinutes} minutos',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  'Hoy no negociás. Hoy cumplís.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 60),
              Column(
                children: [
                  Text(
                    'Empezando entrenamiento en',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _countdown.toString(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseScreen() {
    final isWarmup = _hasWarmup && _currentExerciseIndex == 0;
    final exerciseIndex = _hasWarmup
        ? _currentExerciseIndex - 1
        : _currentExerciseIndex;

    Exercise exercise;
    if (isWarmup) {
      exercise = Exercise(
        name: 'Calentamiento dinámico',
        sets: 1,
        reps: _currentDay.warmup!,
        rest: 'Sin descanso',
        videoUrl: null,
        cadence: "",
      );
    } else {
      exercise = _currentDay.exercises[exerciseIndex];
    }

    final previousWeight = !isWarmup ? _previousWeights[exercise.name] : null;
    final isLastExercise = _currentExerciseIndex == _totalExercises - 1;
    final isFirstExercise = _currentExerciseIndex == 0;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header minimalista
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Barra de progreso sutil
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentExerciseIndex + 1) / _totalExercises,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.6),
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón retroceso
                    IconButton(
                      onPressed: isFirstExercise ? null : _previousExercise,
                      icon: Icon(
                        Icons.arrow_back,
                        color: isFirstExercise
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.8),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),

                    // Info central
                    Column(
                      children: [
                        Text(
                          _currentDay.dayName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentExerciseIndex + 1} / $_totalExercises',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Botón salir
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(_slideAnimation),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Indicador de tipo
                      if (isWarmup)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.orange.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CALENTAMIENTO',
                                style: TextStyle(
                                  color: Colors.orange.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Nombre del ejercicio
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 40),

                      // Video button si existe
                      if (exercise.videoUrl != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 32),
                          child: TextButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              // Abrir video
                            },
                            icon: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Ver técnica',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Info principal en cards separados
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Series y reps
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (!isWarmup) ...[
                                  _buildInfoItem(
                                    icon: Icons.repeat,
                                    label: 'SERIES',
                                    value: exercise.sets.toString(),
                                    color: Colors.blue.shade300,
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ],
                                _buildInfoItem(
                                  icon: isWarmup ? Icons.timer : Icons.fitness_center,
                                  label: isWarmup ? 'TIEMPO' : 'REPS',
                                  value: exercise.reps,
                                  color: isWarmup ? Colors.orange.shade300 : Colors.green.shade300,
                                ),
                                if (!isWarmup) ...[
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  _buildInfoItem(
                                    icon: Icons.pause,
                                    label: 'DESCANSO',
                                    value: exercise.rest,
                                    color: Colors.purple.shade300,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Sección de peso
                      if (!isWarmup) ...[
                        const SizedBox(height: 32),

                        // Peso anterior
                        if (previousWeight != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: Colors.green.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Peso anterior: ${previousWeight.toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    color: Colors.green.shade400,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Input de peso
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 8),
                                child: Text(
                                  'PESO USADO',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.2),
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) {
                                        final weight = double.tryParse(value);
                                        if (weight != null) {
                                          _weights[exercise.name] = weight;
                                        }
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'kg',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botón de acción
          Container(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    HapticFeedback.mediumImpact();
                    if (isLastExercise) {
                      _completeWorkout();
                    } else {
                      _nextExercise();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                      : Text(
                    isLastExercise
                        ? 'Completar entrenamiento'
                        : 'Siguiente',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Widget helper para los items de información
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color.withOpacity(0.8),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}