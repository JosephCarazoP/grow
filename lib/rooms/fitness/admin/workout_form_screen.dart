import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import './exercise_form_dialog.dart';
import '../models/bench_exercise.dart' as bench;

class WorkoutFormScreen extends StatefulWidget {
  final Workout? workoutToEdit;
  final String roomId;
  final String userId;

  const WorkoutFormScreen({
    Key? key,
    this.workoutToEdit,
    required this.roomId,
    required this.userId,
  }) : super(key: key);

  @override
  State<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends State<WorkoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  File? _imageFile;
  String? _imageUrl;
  bool _isLoadingMembers = false;
  List<Map<String, dynamic>> _roomMembers = [];
  String? _selectedClientId;

  // Controladores de texto
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _cadenceController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  final TextEditingController _pathologyController = TextEditingController();

  // Valores del formulario
  String _category = 'Hipertrofia';
  WorkoutLevel _level = WorkoutLevel.intermediate;
  WorkoutType _type = WorkoutType.challenge;
  DateTime? _startDate;
  DateTime? _endDate;

  // Días de entrenamiento
  final List<bool> _selectedDays = List.generate(7, (_) => false);
  final List<WorkoutDay> _workoutDays = [];
  String? _generalWarmup;

  // Lista de categorías disponibles
  final List<String> _categories = [
    'HIIT',
    'Fuerza',
    'Cardio',
    'Yoga',
    'Flexibilidad',
    'Hipertrofia',
    'Resistencia',
    'Funcional',
    'Entrenamiento de Core',
    'Bajo Impacto',
    'Movilidad',
    'Potencia',
    'Agilidad',
    'Equilibrio',
    'Resistencia Muscular',
    'Resistencia Cardiovascular',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.workoutToEdit != null) {
      _loadWorkoutData();
    }
  }

  void _loadWorkoutData() {
    final workout = widget.workoutToEdit!;

    _titleController.text = workout.title;
    _descriptionController.text = workout.description;
    _imageUrl = workout.imageUrl;
    _category = workout.category;
    _level = workout.level;
    _type = workout.type;

    if (_type == WorkoutType.personalized) {
      _clientNameController.text = workout.clientName ?? '';
      _selectedClientId = workout.clientId; // Add this line
      _startDate = workout.startDate;
      _endDate = workout.endDate;
      _frequencyController.text = workout.frequency ?? '';
      _cadenceController.text = workout.cadence ?? '';
      _restController.text = workout.rest ?? '';
      _pathologyController.text = workout.pathology ?? '';
    }

    // Cargar días seleccionados
    for (final day in workout.days) {
      _selectedDays[day.dayOfWeek - 1] = true;
    }
    _workoutDays.addAll(workout.days);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _frequencyController.dispose();
    _cadenceController.dispose();
    _restController.dispose();
    _pathologyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    try {
      final fileName =
          'workout_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir la imagen: $e')));
      return null;
    }
  }

  int _calculateDuration() {
    // Duración estimada basada en número de ejercicios y nivel
    int totalExercises = 0;
    for (final day in _workoutDays) {
      totalExercises += day.exercises.length;
    }

    int baseMinutes = 0;
    switch (_level) {
      case WorkoutLevel.beginner:
        baseMinutes = 20;
        break;
      case WorkoutLevel.intermediate:
        baseMinutes = 30;
        break;
      case WorkoutLevel.advanced:
        baseMinutes = 45;
        break;
    }

    return baseMinutes + (totalExercises * 2); // 2 minutos por ejercicio
  }

  int _calculateCalories() {
    // Calorías estimadas basadas en duración, nivel y calorías específicas por ejercicio
    int totalCalories = 0;

    // Sumar las calorías de todos los ejercicios en todos los días
    for (var day in _workoutDays) {
      for (var exercise in day.exercises) {
        // Si el ejercicio tiene calorías predefinidas, usar ese valor
        if (exercise.caloriesPerRep != null) {
          // Calcular basado en series y calorías por rep
          int reps = 10; // Valor predeterminado

          // Intentar extraer un valor concreto de repeticiones
          final repsString = exercise.reps;
          if (repsString.contains('-')) {
            // Si es un rango (como "10-12"), tomar el valor promedio
            final parts = repsString.split('-');
            if (parts.length == 2) {
              final min = int.tryParse(parts[0]) ?? 10;
              final max = int.tryParse(parts[1]) ?? 12;
              reps = ((min + max) / 2).round();
            }
          } else {
            // Si es un valor simple
            reps = int.tryParse(repsString) ?? 10;
          }

          // Calcular calorías: series * reps * calorías por rep
          totalCalories += exercise.sets * reps * exercise.caloriesPerRep!;
        } else {
          // Usar el método aproximado para ejercicios sin valores predefinidos
          totalCalories +=
              5 * exercise.sets; // 5 calorías por serie como aproximación
        }
      }
    }

    // Aplicar un multiplicador basado en el nivel para los valores aproximados
    double levelMultiplier = 1.0;
    switch (_level) {
      case WorkoutLevel.beginner:
        levelMultiplier = 0.8;
        break;
      case WorkoutLevel.intermediate:
        levelMultiplier = 1.0;
        break;
      case WorkoutLevel.advanced:
        levelMultiplier = 1.3;
        break;
    }

    return (totalCalories * levelMultiplier).round();
  }

  Future<void> _saveWorkout() async {
    if (_formKey.currentState!.validate()) {
      if (_workoutDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes agregar al menos un día de entrenamiento'),
          ),
        );
        return;
      }

      if (_type == WorkoutType.personalized && _selectedClientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes seleccionar un cliente para la rutina personalizada',
            ),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Get current user ID
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para guardar una rutina'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Check if user is an admin in this specific room
        final roomDoc = await _firestore.collection('rooms').doc(widget.roomId).get();
        if (!roomDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La sala no existe en la base de datos'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final roomData = roomDoc.data() as Map<String, dynamic>;
        final List<dynamic> admins = roomData['admins'] ?? [];

        // Check if current user is in the admins list
        if (!admins.contains(currentUser.uid)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No tienes permisos para crear rutinas en esta sala. Solo los administradores pueden hacerlo.',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Proceed with image upload
        final imageUrl = await _uploadImage();
        if (imageUrl == null && _imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes seleccionar una imagen para la rutina'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Create Workout object with clientId included
        final workout = Workout(
          id:
          widget.workoutToEdit?.id ??
              _firestore.collection('workouts').doc().id,
          title: _titleController.text,
          imageUrl: imageUrl ?? _imageUrl!,
          description: _descriptionController.text,
          category: _category,
          level: _level,
          durationMinutes: _calculateDuration(),
          estimatedCalories: _calculateCalories(),
          type: _type,
          clientName:
          _type == WorkoutType.personalized
              ? _clientNameController.text
              : null,
          clientId:
          _type == WorkoutType.personalized
              ? _selectedClientId
              : null,
          startDate: _type == WorkoutType.personalized ? _startDate : null,
          endDate: _type == WorkoutType.personalized ? _endDate : null,
          frequency:
          _type == WorkoutType.personalized
              ? _frequencyController.text
              : null,
          cadence:
          _type == WorkoutType.personalized
              ? _cadenceController.text
              : null,
          rest: _type == WorkoutType.personalized ? _restController.text : null,
          pathology:
          _type == WorkoutType.personalized
              ? _pathologyController.text
              : null,
          days: _workoutDays,
        );

        // Prepare data with additional security fields
        final workoutData = {
          ...workout.toJson(),
          'creatorUid': currentUser.uid,
          'roomId': widget.roomId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'archived': false,
        };

        // Save to Firestore
        await _firestore
            .collection('workouts')
            .doc(workout.id)
            .set(workoutData);

        // Show success message and go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rutina guardada correctamente')),
        );

        Navigator.pop(context, true);
      } catch (e) {
        print('Error detallado al guardar rutina: $e');
        String errorMsg = 'Error al guardar la rutina';

        if (e.toString().contains('PERMISSION_DENIED')) {
          errorMsg =
          'No tienes permisos para realizar esta acción. Verifica tu rol de usuario.';
        } else if (e.toString().contains('App Check')) {
          errorMsg =
          'Error de autenticación con Firebase. Contacta al administrador.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editWorkoutDay(int dayIndex) {
    // Obtener el día de la semana (1-7)
    final dayOfWeek = dayIndex + 1;

    // Verificar si ya existe este día en la rutina
    final existingDayIndex = _workoutDays.indexWhere(
      (day) => day.dayOfWeek == dayOfWeek,
    );

    // Si existe, editar ese día; si no, crear uno nuevo
    if (existingDayIndex >= 0) {
      _showDayEditDialog(_workoutDays[existingDayIndex], existingDayIndex);
    } else {
      final newDay = WorkoutDay(
        dayOfWeek: dayOfWeek,
        warmup: _generalWarmup,
        exercises: [],
        finalExercises: null,
      );
      _showDayEditDialog(newDay, -1);
    }
  }

  // Function to select a client
  Future<void> _selectClient() async {
    setState(() {
      _isLoadingMembers = true;
    });

    try {
      // Fetch members where roomId matches the current room
      final membersSnapshot =
          await _firestore
              .collection('members')
              .where('roomId', isEqualTo: widget.roomId)
              .where('status', isEqualTo: 'active') // Only get active members
              .get();

      if (membersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay miembros en esta sala')),
        );
        setState(() {
          _isLoadingMembers = false;
        });
        return;
      }

      // Get user details for each member
      _roomMembers = [];
      for (var memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        // Get the user data directly from members collection
        _roomMembers.add({
          'id': memberData['userId'],
          'name': memberData['userName'] ?? 'Usuario sin nombre',
          'photoUrl': memberData['userPhoto'],
          'email': '', // You don't have email in members collection
        });
      }

      if (_roomMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay miembros en esta sala')),
        );
        setState(() {
          _isLoadingMembers = false;
        });
        return;
      }

      // Show dialog to select client
      _showClientSelectionDialog();
    } catch (e) {
      print('Error loading members: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar miembros: $e')));
    } finally {
      setState(() {
        _isLoadingMembers = false;
      });
    }
  }

  void _showClientSelectionDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF303030), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Seleccionar Cliente',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          splashRadius: 20,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child:
                        _isLoadingMembers
                            ? const Center(
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  color: Colors.blue,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                            : _roomMembers.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.group_off_rounded,
                                        size: 48,
                                        color: Colors.blue.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No hay miembros disponibles',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Invita miembros a esta sala para poder asignarles rutinas personalizadas',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _roomMembers.length,
                              separatorBuilder:
                                  (context, index) => const Divider(
                                    height: 1,
                                    indent: 72,
                                    endIndent: 24,
                                    color: Color(0xFF303030),
                                  ),
                              itemBuilder: (context, index) {
                                final member = _roomMembers[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _clientNameController.text =
                                            member['name'];
                                        _selectedClientId = member['id'];
                                      });
                                      Navigator.pop(context);
                                    },
                                    splashColor: Colors.blue.withOpacity(0.1),
                                    highlightColor: Colors.blue.withOpacity(
                                      0.05,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.blue.withOpacity(
                                                  0.3,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              child:
                                                  member['photoUrl'] != null &&
                                                          member['photoUrl']
                                                              .toString()
                                                              .isNotEmpty
                                                      ? Image.network(
                                                        member['photoUrl'],
                                                        fit: BoxFit.cover,
                                                        loadingBuilder: (
                                                          context,
                                                          child,
                                                          loadingProgress,
                                                        ) {
                                                          if (loadingProgress ==
                                                              null)
                                                            return child;
                                                          return Center(
                                                            child: CircularProgressIndicator(
                                                              value:
                                                                  loadingProgress
                                                                              .expectedTotalBytes !=
                                                                          null
                                                                      ? loadingProgress
                                                                              .cumulativeBytesLoaded /
                                                                          loadingProgress
                                                                              .expectedTotalBytes!
                                                                      : null,
                                                              color:
                                                                  Colors.white,
                                                              strokeWidth: 2,
                                                            ),
                                                          );
                                                        },
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => Center(
                                                              child: Text(
                                                                member['name'][0]
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                      )
                                                      : Center(
                                                        child: Text(
                                                          member['name'][0]
                                                              .toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  member['name'] ??
                                                      'Usuario sin nombre',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (member['email'] != null &&
                                                    member['email']
                                                        .toString()
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      member['email'],
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.6),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF262626),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showDayEditDialog(WorkoutDay day, int dayIndex) {
    // Form field controllers
    final warmupController = TextEditingController(text: day.warmup);
    final finalExercisesController = TextEditingController(
      text: day.finalExercises,
    );

    // Mutable list of exercises to edit
    List<Exercise> exercises = List<Exercise>.from(day.exercises);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 550,
                    maxHeight: 650,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF202020),
                        const Color(0xFF151515),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        spreadRadius: 2,
                        blurRadius: 15,
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 20, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.2),
                              Colors.indigo.withOpacity(0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: Colors.blue.shade300,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Configuración: ${_getDayName(day.dayOfWeek)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () => Navigator.pop(context),
                              splashRadius: 24,
                            ),
                          ],
                        ),
                      ),

                      // Content area
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Warmup section
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_run_rounded,
                                    color: Colors.orange.shade300,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Calentamiento',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.orange.withOpacity(0.8),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Configure aquí el calentamiento específico para este día. Si prefiere un calentamiento general para todos los días, déjelo en blanco y configure el calentamiento general.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: warmupController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  hintText:
                                      'Describe el calentamiento para este día',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.orange.withOpacity(0.6),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                              ),

                              const SizedBox(height: 24),

                              // Exercises section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        color: Colors.blue.shade300,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Ejercicios',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await showDialog<Exercise>(
                                        context: context,
                                        builder:
                                            (context) =>
                                                const ExerciseFormDialog(),
                                      );

                                      if (result != null) {
                                        setState(() {
                                          exercises.add(result);
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Agregar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Exercises list
                              if (exercises.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.07),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.fitness_center_outlined,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay ejercicios agregados',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Agrega ejercicios con el botón "Agregar"',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight:
                                        360, // Aumentado de 240 a 360 para mostrar más elementos
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: exercises.length,
                                    itemBuilder: (context, index) {
                                      final exercise = exercises[index];
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ), // Reducido de 8 a 6
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.withOpacity(0.1),
                                              Colors.indigo.withOpacity(0.05),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                          ),
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue.withOpacity(0.1),
                                                Colors.indigo.withOpacity(0.05),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.08,
                                              ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            8,
                                            14,
                                            4,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Primera fila: número y nombre del ejercicio
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .blue
                                                                .shade300,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      exercise.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Detalles del ejercicio
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                  top: 6,
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildExerciseDetail(
                                                      Icons.repeat_rounded,
                                                      '${exercise.sets} series',
                                                      Colors.green,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    _buildExerciseDetail(
                                                      Icons.fitness_center,
                                                      '${exercise.reps} reps',
                                                      Colors.orange,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    _buildExerciseDetail(
                                                      Icons.timer,
                                                      exercise.rest,
                                                      Colors.red,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Botones de acción en la parte inferior
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    TextButton.icon(
                                                      icon: Icon(
                                                        Icons.edit_rounded,
                                                        color:
                                                            Colors
                                                                .blue
                                                                .shade300,
                                                        size: 16,
                                                      ),
                                                      label: Text(
                                                        'Editar',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade300,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        minimumSize: Size.zero,
                                                      ),
                                                      onPressed: () async {
// Add semicolon at the end
                                                        final result = await showDialog<bench.Exercise?>(
                                                          context: context,
                                                          builder: (context) => ExerciseFormDialog(
                                                            exercise: bench.Exercise(
                                                                name: exercise.name,
                                                                sets: exercise.sets,
                                                                reps: exercise.reps,
                                                                rest: exercise.rest,
                                                                cadence: exercise.cadence,
                                                                videoUrl: exercise.videoUrl,
                                                                muscleGroup: exercise.muscleGroup
                                                            ),
                                                          ),
                                                        ); // Solo un punto y coma aquídd semicolon here;

                                                        if (result != null) {
                                                          setState(() {
                                                            exercises[index] = Exercise(
                                                                name: result.name,
                                                                sets: result.sets,
                                                                reps: result.reps,
                                                                rest: result.rest,
                                                                cadence: result.cadence,
                                                                videoUrl: result.videoUrl,
                                                                muscleGroup: result.muscleGroup
                                                            );
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    TextButton.icon(
                                                      icon: const Icon(
                                                        Icons.delete_rounded,
                                                        color: Colors.redAccent,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Eliminar',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.redAccent,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        minimumSize: Size.zero,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          exercises.removeAt(
                                                            index,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 24),

                              // Final exercises section
                              Row(
                                children: [
                                  Icon(
                                    Icons.sports_gymnastics_rounded,
                                    color: Colors.purple.shade300,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Ejercicios finales',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.purple.withOpacity(0.8),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Agregue ejercicios de enfriamiento o finales específicos para este día (estiramientos, cardiovascular ligero, etc).',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: finalExercisesController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  hintText:
                                      'Ej: 5 minutos de bicicleta o ejercicios abdominales',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.purple.withOpacity(0.6),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer with actions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stats summary
                            Row(
                              children: [
                                Icon(
                                  Icons.fitness_center_rounded,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${exercises.length} ejercicios',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            // Action buttons
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white60,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final updatedDay = WorkoutDay(
                                      dayOfWeek: day.dayOfWeek,
                                      warmup:
                                          warmupController.text.trim().isEmpty
                                              ? null
                                              : warmupController.text.trim(),
                                      exercises: exercises,
                                      finalExercises:
                                          finalExercisesController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : finalExercisesController.text
                                                  .trim(),
                                    );

                                    setState(() {
                                      if (dayIndex >= 0) {
                                        _workoutDays[dayIndex] = updatedDay;
                                      } else {
                                        _workoutDays.add(updatedDay);
                                      }
                                    });

                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Guardar'),
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
          ),
    ).then((_) {
      setState(() {}); // Update the UI after closing the dialog
    });
  }

  Widget _buildExerciseDetail(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.indigo.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14, // Reducido de 16 a 14
            color: color.withOpacity(0.9),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10, // Reducido de 11 a 10
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día $dayOfWeek';
    }
  }

  void _toggleDay(int index) {
    final newValue = !_selectedDays[index];
    setState(() {
      _selectedDays[index] = newValue;

      // If day is being selected, add it to workout days or edit it
      if (newValue) {
        // Check if day already exists
        final dayOfWeek = index + 1;
        final existingDayIndex = _workoutDays.indexWhere(
          (day) => day.dayOfWeek == dayOfWeek,
        );

        if (existingDayIndex == -1) {
          // If the day doesn't exist, create a new one with empty exercises list
          final newDay = WorkoutDay(dayOfWeek: dayOfWeek, exercises: []);
          _workoutDays.add(newDay);
        }

        // Open the day edit dialog to configure exercises
        _editWorkoutDay(index);
      } else {
        // If day is being deselected, remove it from workout days
        _workoutDays.removeWhere((day) => day.dayOfWeek == index + 1);
      }
    });
  }

  void _setGeneralWarmup() {
    final controller = TextEditingController(text: _generalWarmup);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF202020), const Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 20,
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header - fixed at top
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.2),
                          Colors.amber.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_run_rounded,
                          color: Colors.orange.withOpacity(0.8),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Calentamiento general',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          splashRadius: 20,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content - scrollable
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.amber.withOpacity(0.8),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Use este calentamiento general solo si será el mismo para todos los días. Si prefiere calentamientos específicos, configúrelos al editar cada día individual.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                hintText: 'Describe el calentamiento general',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.withOpacity(0.6),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer with actions - fixed at bottom
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _generalWarmup =
                                  controller.text.trim().isEmpty
                                      ? null
                                      : controller.text.trim();
                            });

                            // Apply to all days that don't have specific warmup
                            if (_generalWarmup != null) {
                              for (int i = 0; i < _workoutDays.length; i++) {
                                if (_workoutDays[i].warmup == null ||
                                    _workoutDays[i].warmup!.isEmpty) {
                                  final updatedDay = WorkoutDay(
                                    dayOfWeek: _workoutDays[i].dayOfWeek,
                                    warmup: _generalWarmup,
                                    exercises: _workoutDays[i].exercises,
                                    finalExercises:
                                        _workoutDays[i].finalExercises,
                                  );
                                  _workoutDays[i] = updatedDay;
                                }
                              }
                            }

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Aplicar a todos los días'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.workoutToEdit == null ? 'Nueva rutina' : 'Editar rutina',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveWorkout,
            icon:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.save, color: Colors.white),
            label: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildMediaSection(),
            const SizedBox(height: 24),
            _buildTypeSection(),
            if (_type == WorkoutType.personalized) ...[
              const SizedBox(height: 24),
              _buildPersonalizedSection(),
            ],
            const SizedBox(height: 24),
            _buildScheduleSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información básica',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: _buildInputDecoration('Título de la rutina'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El título es obligatorio';
            }
            return null;
          },
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: _buildInputDecoration('Descripción'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La descripción es obligatoria';
            }
            return null;
          },
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _category,
          items:
              _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
          onChanged: (value) {
            setState(() {
              _category = value!;
            });
          },
          decoration: _buildInputDecoration('Categoría'),
          dropdownColor: Colors.grey.shade900,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<WorkoutLevel>(
          value: _level,
          items:
              WorkoutLevel.values.map((level) {
                String text;
                switch (level) {
                  case WorkoutLevel.beginner:
                    text = 'Principiante';
                    break;
                  case WorkoutLevel.intermediate:
                    text = 'Intermedio';
                    break;
                  case WorkoutLevel.advanced:
                    text = 'Avanzado';
                    break;
                }
                return DropdownMenuItem(value: level, child: Text(text));
              }).toList(),
          onChanged: (value) {
            setState(() {
              _level = value!;
            });
          },
          decoration: _buildInputDecoration('Nivel'),
          dropdownColor: Colors.grey.shade900,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imagen de la rutina',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child:
                _imageFile != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                    : (_imageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(_imageUrl!, fit: BoxFit.cover),
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 50,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca para seleccionar una imagen',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        )),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de rutina',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTypeSelector(
                title: 'Reto',
                description: 'Reto general para todos los usuarios',
                icon: Icons.emoji_events,
                color: Colors.amber,
                isSelected: _type == WorkoutType.challenge,
                onTap: () {
                  setState(() {
                    _type = WorkoutType.challenge;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTypeSelector(
                title: 'Personalizada',
                description: 'Plan específico para un cliente',
                icon: Icons.person,
                color: Colors.purple,
                isSelected: _type == WorkoutType.personalized,
                onTap: () {
                  setState(() {
                    _type = WorkoutType.personalized;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelector({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: isSelected ? color : Colors.white54),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información personalizada',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Client selection button
        GestureDetector(
          onTap: _selectClient,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _clientNameController.text.isEmpty
                            ? 'Seleccionar cliente'
                            : _clientNameController.text,
                        style: TextStyle(
                          color:
                              _clientNameController.text.isEmpty
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.people,
                  color: Colors.blue.withOpacity(0.7),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // The rest of your personalized fields remain the same
        Row(
          children: [
            Expanded(
              child: _buildDateSelector(
                label: 'Fecha de inicio',
                value: _startDate,
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Color(0xFF303030),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateSelector(
                label: 'Fecha de fin',
                value: _endDate,
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        _endDate ??
                        (_startDate?.add(const Duration(days: 30)) ??
                            DateTime.now()),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Color(0xFF303030),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
            ),
          ],
        ),

        // Rest of your existing personalized fields
        const SizedBox(height: 16),
        TextFormField(
          controller: _frequencyController,
          decoration: _buildInputDecoration(
            'Frecuencia (ej: 3 veces por semana)',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cadenceController,
          decoration: _buildInputDecoration('Cadencia general (ej: 2-1-2)'),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _restController,
          decoration: _buildInputDecoration(
            'Descanso general (ej: 60 segundos)',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pathologyController,
          decoration: _buildInputDecoration(
            'Patología o consideraciones especiales',
          ),
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('dd/MM/yyyy').format(value)
                        : 'Seleccionar',
                    style: TextStyle(
                      color:
                          value != null
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.blue.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Programación',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Selecciona los días de entrenamiento:',
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 12),
        _buildDaySelector(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _setGeneralWarmup,
                icon: Icon(
                  Icons.directions_run_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text('Establecer calentamiento general'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.blue.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El calentamiento general solo es necesario si será el mismo para todos los días.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
        const SizedBox(height: 16),
        const Text(
          'Detalles de los días seleccionados:',
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 12),
        _buildDaysList(),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final isSelected = _selectedDays[index];
          final dayName = _getDayName(index + 1).substring(0, 3);

          return GestureDetector(
            onTap: () => _toggleDay(index),
            child: Container(
              width: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isSelected
                          ? Colors.blue.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      color:
                          isSelected
                              ? Colors.blue
                              : Colors.white.withOpacity(0.7),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                      size: 14,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaysList() {
    if (_workoutDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          'Selecciona y configura al menos un día para la rutina',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Ordenar los días por número de día (lunes a domingo)
    final sortedDays = List<WorkoutDay>.from(_workoutDays)
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    // Calculate totals for summary
    int totalExercises = 0;
    int totalMinutes = 0;
    int totalCalories = 0;

    for (var day in sortedDays) {
      totalExercises += day.exercises.length;

      // Estimate time based on exercise count, sets, and rest time
      int dayMinutes = 0;
      for (var exercise in day.exercises) {
        // Base time per exercise (prep + execution)
        int exerciseTime = 2;

        // Add time for sets and reps
        exerciseTime += exercise.sets * 1;

        // Add rest time (parse from format like "60 seg")
        String rest = exercise.rest;
        int restSeconds = 0;
        if (rest.contains('seg')) {
          restSeconds =
              int.tryParse(rest.replaceAll(RegExp(r'[^\d]'), '')) ?? 60;
        } else if (rest.contains('min')) {
          restSeconds =
              (int.tryParse(rest.replaceAll(RegExp(r'[^\d]'), '')) ?? 1) * 60;
        }

        exerciseTime += (restSeconds * exercise.sets) ~/ 60;
        dayMinutes += exerciseTime;
      }

      // Add warmup time if present
      if (day.warmup != null && day.warmup!.isNotEmpty) {
        dayMinutes += 5;
      }

      // Add cooldown time if present
      if (day.finalExercises != null && day.finalExercises!.isNotEmpty) {
        dayMinutes += 5;
      }

      // Calculate calories based on time and intensity level
      int dayCalories = 0;
      switch (_level) {
        case WorkoutLevel.beginner:
          dayCalories = dayMinutes * 5;
          break;
        case WorkoutLevel.intermediate:
          dayCalories = dayMinutes * 8;
          break;
        case WorkoutLevel.advanced:
          dayCalories = dayMinutes * 12;
          break;
      }

      // Store values for use in the UI
      day.totalMinutes = dayMinutes;
      day.totalCalories = dayCalories;

      totalMinutes += dayMinutes;
      totalCalories += dayCalories;
    }

    return Column(
      children: [
        // Summary widget
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.2),
                Colors.purple.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const Text(
                'Resumen de la Rutina',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiempo total',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${totalMinutes.toString()} min',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Calorías estimadas',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '$totalCalories kcal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$totalExercises ejercicios en ${sortedDays.length} días',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Days list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];

            return Dismissible(
              key: ValueKey(
                'workout-day-${day.dayOfWeek}-${DateTime.now().millisecondsSinceEpoch}',
              ),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade800.withOpacity(0.8),
                      Colors.red.shade600.withOpacity(0.9),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onDismissed: (direction) {
                setState(() {
                  _workoutDays.removeWhere((d) => d.dayOfWeek == day.dayOfWeek);
                  _selectedDays[day.dayOfWeek - 1] = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Día ${day.dayName} eliminado'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () {
                        setState(() {
                          _workoutDays.add(day);
                          _selectedDays[day.dayOfWeek - 1] = true;
                        });
                      },
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade700.withOpacity(0.9),
                      Colors.purple.shade800.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () => _editWorkoutDay(day.dayOfWeek - 1),
                          icon: const Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: Colors.white70,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day name with indicator
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      day.dayName.substring(0, 3).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day.dayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${day.exercises.length} ejercicios',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Stats row
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: Colors.blue.shade200,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${day.totalMinutes} min',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 16,
                                        color: Colors.orange.shade300,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${day.totalCalories} kcal',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Exercises preview
                            if (day.exercises.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              const SizedBox(height: 12),

                              // Show first 3 exercises
                              ...day.exercises
                                  .take(3)
                                  .map(
                                    (exercise) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.fitness_center,
                                              size: 14,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              exercise.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${exercise.sets} × ${exercise.reps}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                              // "And X more" indicator
                              if (day.exercises.length > 3) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'y ${day.exercises.length - 3} más...',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
