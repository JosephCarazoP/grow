import 'package:flutter/material.dart';
import '../../../services/bench_exercise_service.dart';
import '../models/bench_exercise.dart';
import '../models/bench_exercise.dart' as bench;

class ExerciseFormDialog extends StatefulWidget {
  final Exercise? exercise;

  const ExerciseFormDialog({Key? key, this.exercise}) : super(key: key);

  @override
  State<ExerciseFormDialog> createState() => _ExerciseFormDialogState();
}

class _ExerciseFormDialogState extends State<ExerciseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  final TextEditingController _cadenceController = TextEditingController();

  BenchExercise? _selectedBenchExercise;
  List<BenchExercise> _benchExercises = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBenchExercises();

    // Initialize form values if editing
    if (widget.exercise != null) {
      _setsController.text = widget.exercise!.sets.toString();
      _repsController.text = widget.exercise!.reps;
      _restController.text = widget.exercise!.rest;
      _cadenceController.text = widget.exercise!.cadence;
    } else {
      // Default values for new exercise
      _setsController.text = '3';
      _repsController.text = '12';
      _restController.text = '60 seg';
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    _setsController.dispose();
    _restController.dispose();
    _cadenceController.dispose();
    super.dispose();
  }

  // Load bench exercises from Firestore
  Future<void> _loadBenchExercises() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exercises = await BenchExerciseService.getExercises();
      setState(() {
        _benchExercises = exercises;

        // If editing, find the matching bench exercise
        if (widget.exercise != null &&
            widget.exercise!.benchExerciseId != null) {
          _selectedBenchExercise = _benchExercises.firstWhere(
            (e) => e.id == widget.exercise!.benchExerciseId,
            orElse: () {
              if (_benchExercises.isNotEmpty) {
                return _benchExercises.first;
              }
              throw Exception('No bench exercises available');
            },
          );
        } else if (_benchExercises.isNotEmpty) {
          _selectedBenchExercise = _benchExercises.first;
        }

        // Set default cadence from bench exercise if not editing
        if (widget.exercise == null && _selectedBenchExercise != null) {
          _cadenceController.text = _selectedBenchExercise!.defaultCadence;
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar ejercicios: $e';
        _isLoading = false;
      });
    }
  }

  void _saveExercise() {
    if (_formKey.currentState!.validate() && _selectedBenchExercise != null) {
      setState(() {
        _isSaving = true;
      });

      final exercise = bench.Exercise(
        name: _selectedBenchExercise!.name,
        sets: int.parse(_setsController.text),
        reps: _repsController.text,
        rest: _restController.text,
        cadence: _cadenceController.text,
        videoUrl: _selectedBenchExercise!.videoUrl,
        muscleGroup: _selectedBenchExercise!.muscleGroup,
      );

      Navigator.pop(context, exercise);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Detectar si es un dispositivo pequeño
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(isSmallDevice ? 16 : 24), // Padding reducido
        constraints: BoxConstraints(
          maxWidth:
              isSmallDevice ? screenWidth * 0.95 : 500, // Ancho adaptativo
        ),
        child:
            _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _benchExercises.isEmpty
                ? _buildEmptyState()
                : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 600;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exercise == null ? 'Añadir Ejercicio' : 'Editar Ejercicio',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallDevice ? 18 : 22, // Título más pequeño
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallDevice ? 16 : 24), // Espaciado reducido
            // Exercise selector
            Text(
              'Seleccionar ejercicio',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallDevice ? 14 : 16, // Texto más pequeño
              ),
            ),
            SizedBox(height: isSmallDevice ? 6 : 8),
            DropdownButtonFormField<BenchExercise>(
              value: _selectedBenchExercise,
              decoration: _buildInputDecoration(
                'Ejercicio',
                Icons.fitness_center,
                isSmallDevice,
              ),
              dropdownColor: Colors.grey.shade800,
              style: TextStyle(
                color: Colors.white,
                fontSize:
                    isSmallDevice ? 13 : 14, // Texto del dropdown más pequeño
              ),
              isExpanded: true,
              items:
                  _benchExercises.map((exercise) {
                    return DropdownMenuItem<BenchExercise>(
                      value: exercise,
                      child: Text(
                        '${exercise.name} (${exercise.muscleGroup})',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isSmallDevice ? 12 : 14),
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBenchExercise = value;
                  if (value != null) {
                    _cadenceController.text = value.defaultCadence;
                  }
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Por favor selecciona un ejercicio';
                }
                return null;
              },
            ),
            SizedBox(height: isSmallDevice ? 16 : 24),

            // Exercise info if selected
            if (_selectedBenchExercise != null) ...[
              _buildExerciseInfo(isSmallDevice),
              SizedBox(height: isSmallDevice ? 16 : 24),
            ],

            // Form fields
            Row(
              children: [
                // Sets
                Expanded(
                  child: TextFormField(
                    controller: _setsController,
                    decoration: _buildInputDecoration(
                      'Series',
                      Icons.repeat,
                      isSmallDevice,
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallDevice ? 13 : 14,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: isSmallDevice ? 12 : 16),

                // Reps
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    decoration: _buildInputDecoration(
                      'Repeticiones',
                      Icons.fitness_center,
                      isSmallDevice,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallDevice ? 13 : 14,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallDevice ? 12 : 16),
            Row(
              children: [
                // Rest
                Expanded(
                  child: TextFormField(
                    controller: _restController,
                    decoration: _buildInputDecoration(
                      'Descanso',
                      Icons.timer,
                      isSmallDevice,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallDevice ? 13 : 14,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: isSmallDevice ? 12 : 16),

                // Cadence
                Expanded(
                  child: TextFormField(
                    controller: _cadenceController,
                    decoration: _buildInputDecoration(
                      'Cadencia',
                      Icons.speed,
                      isSmallDevice,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallDevice ? 13 : 14,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallDevice ? 24 : 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallDevice ? 13 : 14,
                    ),
                  ),
                ),
                SizedBox(width: isSmallDevice ? 12 : 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallDevice ? 16 : 24,
                      vertical: isSmallDevice ? 8 : 12,
                    ),
                  ),
                  child:
                      _isSaving
                          ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Guardar',
                            style: TextStyle(fontSize: isSmallDevice ? 13 : 14),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    bool isSmallDevice,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: isSmallDevice ? 12 : 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.blue.withOpacity(0.7),
        size: isSmallDevice ? 18 : 20,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 12 : 16,
        vertical: isSmallDevice ? 12 : 16,
      ),
      errorStyle: TextStyle(fontSize: isSmallDevice ? 10 : 12),
    );
  }

  Widget _buildExerciseInfo(bool isSmallDevice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      padding: EdgeInsets.all(isSmallDevice ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedBenchExercise!.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _selectedBenchExercise!.imageUrls.first,
                    width: isSmallDevice ? 50 : 60,
                    height: isSmallDevice ? 50 : 60,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: isSmallDevice ? 50 : 60,
                          height: isSmallDevice ? 50 : 60,
                          color: Colors.grey.shade800,
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: isSmallDevice ? 20 : 24,
                          ),
                        ),
                  ),
                ),
              SizedBox(
                width:
                    _selectedBenchExercise!.imageUrls.isNotEmpty
                        ? (isSmallDevice ? 12 : 16)
                        : 0,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBenchExercise!.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallDevice ? 14 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _selectedBenchExercise!.muscleGroup,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: isSmallDevice ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedBenchExercise!.description != null &&
              _selectedBenchExercise!.description!.isNotEmpty) ...[
            SizedBox(height: isSmallDevice ? 12 : 16),
            Text(
              'Descripción:',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallDevice ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _selectedBenchExercise!.description!,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallDevice ? 11 : 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadBenchExercises,
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_outlined, color: Colors.grey, size: 48),
          SizedBox(height: 16),
          Text(
            'No hay ejercicios disponibles',
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
