import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/bench_exercise.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class BenchExerciseFormPage extends StatefulWidget {
  final BenchExercise? exercise;

  const BenchExerciseFormPage({Key? key, this.exercise}) : super(key: key);

  @override
  State<BenchExerciseFormPage> createState() => _BenchExerciseFormPageState();
}

class _BenchExerciseFormPageState extends State<BenchExerciseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _customMuscleGroupController =
      TextEditingController();
  final TextEditingController _caloriesPerRepController =
      TextEditingController();
  final TextEditingController _defaultCadenceController =
      TextEditingController();

  String? _selectedMuscleGroup;
  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  bool _isSaving = false;

  // Lista predefinida de grupos musculares
  final List<String> _muscleGroups = [
    'Pecho',
    'Espalda',
    'Hombros',
    'Brazos',
    'Piernas',
    'Core',
    'Cardio',
    'Full body',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      _nameController.text = widget.exercise!.name;
      _descriptionController.text = widget.exercise!.description ?? '';
      _videoUrlController.text = widget.exercise!.videoUrl ?? '';
      _caloriesPerRepController.text =
          widget.exercise!.caloriesPerRep.toString();
      _defaultCadenceController.text = widget.exercise!.defaultCadence;

      // Verificar si el grupo muscular está en la lista predefinida
      if (_muscleGroups.contains(widget.exercise!.muscleGroup)) {
        _selectedMuscleGroup = widget.exercise!.muscleGroup;
      } else {
        _selectedMuscleGroup = 'Otro';
        _customMuscleGroupController.text = widget.exercise!.muscleGroup;
      }

      // Guardar URLs de imágenes existentes
      _existingImageUrls = List<String>.from(widget.exercise!.imageUrls);
    } else {
      // Valores por defecto para nuevo ejercicio
      _caloriesPerRepController.text = '1';
      _defaultCadenceController.text = '2-0-2';
      _selectedMuscleGroup = 'Pecho'; // Valor predeterminado
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    _customMuscleGroupController.dispose();
    _caloriesPerRepController.dispose();
    _defaultCadenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _saveExercise() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      // Determinar grupo muscular final
      final String muscleGroup =
          _selectedMuscleGroup == 'Otro'
              ? _customMuscleGroupController.text
              : _selectedMuscleGroup!;

      final benchExercise = BenchExercise(
        id: widget.exercise?.id,
        name: _nameController.text,
        muscleGroup: muscleGroup,
        description: _descriptionController.text,
        caloriesPerRep: int.parse(_caloriesPerRepController.text),
        defaultCadence: _defaultCadenceController.text,
        videoUrl:
            _videoUrlController.text.isEmpty ? null : _videoUrlController.text,
        imageUrls: _existingImageUrls,
      );

      // Devolver el ejercicio y las nuevas imágenes
      Navigator.pop(context, {
        'exercise': benchExercise,
        'newImages': _selectedImages,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.exercise == null
              ? 'Nuevo Ejercicio'
              : 'Editar Ejercicio',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveExercise,
            icon:
                _isSaving
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Icon(Icons.save, color: Colors.white),
            label: Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body:
          _isSaving
              ? Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Sección de imágenes destacada
                    _buildImageSection(),
                    const SizedBox(height: 24),

                    // Información básica
                    _buildSectionHeader(
                      'Información básica',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),

                    // Nombre del ejercicio
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration(
                        'Nombre del ejercicio',
                        Icons.fitness_center_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    // Grupo muscular
                    DropdownButtonFormField<String>(
                      value: _selectedMuscleGroup,
                      decoration: _buildInputDecoration(
                        'Grupo muscular',
                        Icons.accessibility_new_outlined,
                      ),
                      dropdownColor: Colors.grey.shade900,
                      style: const TextStyle(color: Colors.white),
                      items:
                          _muscleGroups.map((group) {
                            return DropdownMenuItem<String>(
                              value: group,
                              child: Text(group),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMuscleGroup = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor selecciona un grupo muscular';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Grupo muscular personalizado
                    if (_selectedMuscleGroup == 'Otro')
                      TextFormField(
                        controller: _customMuscleGroupController,
                        decoration: _buildInputDecoration(
                          'Grupo muscular personalizado',
                          Icons.edit_outlined,
                        ),
                        validator: (value) {
                          if (_selectedMuscleGroup == 'Otro' &&
                              (value == null || value.isEmpty)) {
                            return 'Por favor ingresa el grupo muscular';
                          }
                          return null;
                        },
                        style: const TextStyle(color: Colors.white),
                      ),

                    if (_selectedMuscleGroup == 'Otro')
                      const SizedBox(height: 16),

                    // Calorías por rep
                    TextFormField(
                      controller: _caloriesPerRepController,
                      decoration: _buildInputDecoration(
                        'Calorías por repetición',
                        Icons.local_fire_department_outlined,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Debe ser un número';
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    // Cadencia predeterminada
                    TextFormField(
                      controller: _defaultCadenceController,
                      decoration: _buildInputDecoration(
                        'Cadencia predeterminada',
                        Icons.speed_outlined,
                      ).copyWith(
                        helperText:
                            'Formato: concéntrica-pausa-excéntrica (ej: 2-0-2)',
                        helperStyle: TextStyle(color: Colors.grey),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Este campo es obligatorio';
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),

                    // Sección de multimedia
                    _buildSectionHeader('Multimedia', Icons.movie_outlined),
                    const SizedBox(height: 16),

                    // URL de video
                    TextFormField(
                      controller: _videoUrlController,
                      decoration: _buildInputDecoration(
                        'URL de video (YouTube)',
                        Icons.video_library_outlined,
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),

                    // Sección de descripción
                    _buildSectionHeader(
                      'Descripción',
                      Icons.description_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Campo de descripción
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // En bench_exercise_form_screen.dart, modifica este bloque:
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            maxLines: 8,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Describe el ejercicio...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Imágenes del ejercicio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text('Añadir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_existingImageUrls.isEmpty && _selectedImages.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    color: Colors.grey.shade600,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Añade imágenes del ejercicio',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),

        // Imágenes existentes
        if (_existingImageUrls.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Imágenes existentes',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _existingImageUrls.length,
                itemBuilder: (context, index) {
                  return _buildImageItem(
                    imageProvider: NetworkImage(_existingImageUrls[index]),
                    onRemove: () => _removeExistingImage(index),
                    isNetwork: true,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),

        // Imágenes seleccionadas
        if (_selectedImages.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Imágenes nuevas',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return _buildImageItem(
                    imageProvider: FileImage(_selectedImages[index]),
                    onRemove: () => _removeSelectedImage(index),
                    isNetwork: false,
                  );
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImageItem({
    required ImageProvider imageProvider,
    required VoidCallback onRemove,
    required bool isNetwork,
  }) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder:
                  isNetwork
                      ? (context, error, stackTrace) => Container(
                        color: Colors.grey.shade800,
                        child: Icon(Icons.error, color: Colors.red),
                      )
                      : null,
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Colors.blue.withOpacity(0.7), size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
