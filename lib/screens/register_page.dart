import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final bioController = TextEditingController();
  bool acceptTerms = false;
  bool _isLoading = false;
  File? _profileImage;
  File? _coverImage;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;
  final _totalSteps = 2; // Reducido a 2 pasos

  // Método para seleccionar imagen de perfil
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  // Método para seleccionar imagen de portada
  Future<void> _pickCoverImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _coverImage = File(image.path);
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return null;

    try {
      final fileName = path.basename(_profileImage!.path);
      final destination = 'profile_images/$uid/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(destination);
      final uploadTask = storageRef.putFile(_profileImage!);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error al subir la imagen: $e');
      return null;
    }
  }

  Future<String?> _uploadCoverImage(String uid) async {
    if (_coverImage == null) return null;

    try {
      final fileName = path.basename(_coverImage!.path);
      final destination = 'cover_images/$uid/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(destination);
      final uploadTask = storageRef.putFile(_coverImage!);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error al subir la imagen de portada: $e');
      return null;
    }
  }

  // Método para finalizar el registro
  Future<void> _finishRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Registro en Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Subir imagen de perfil si existe
      String? photoUrl;
      if (_profileImage != null) {
        photoUrl = await _uploadProfileImage(uid);
      }

      // Subir imagen de portada si existe
      String? coverPhotoUrl;
      if (_coverImage != null) {
        coverPhotoUrl = await _uploadCoverImage(uid);
      }

      // Registro en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'photo':
        photoUrl ??
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nameController.text.trim())}',
        'coverPhoto': coverPhotoUrl,
        'description': bioController.text.trim(),
        'role': 'user',
        'socials': {'instagram': '', 'facebook': '', 'x': '', 'whatsapp': ''},
        'approvedRooms': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cuenta creada con éxito"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al completar el registro: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/grow_baja_calidad_negro.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),

                  // Indicador de pasos
                  _buildStepIndicator(),
                  const SizedBox(height: 30),

                  // Contenido según el paso actual
                  if (_currentStep == 0)
                    _buildBasicInfoStep()
                  else
                    _buildProfileStep(),

                  const SizedBox(height: 20),

                  // Botones de navegación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        ElevatedButton(
                          onPressed: _previousStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Anterior'),
                        )
                      else
                        const SizedBox(),

                      ElevatedButton(
                        onPressed:
                        _isLoading
                            ? null
                            : () {
                          if (_currentStep == 0) {
                            // Validación del paso 1
                            if (nameController.text.trim().isEmpty) {
                              _showError("Ingresa tu nombre completo.");
                              return;
                            }
                            if (passwordController.text !=
                                confirmPasswordController.text) {
                              _showError(
                                "Las contraseñas no coinciden.",
                              );
                              return;
                            }
                            if (!acceptTerms) {
                              _showError(
                                "Debe aceptar los términos y condiciones.",
                              );
                              return;
                            }
                            _nextStep();
                          } else {
                            // Último paso: completar el registro
                            _finishRegistration();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child:
                        _isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : Text(
                          _currentStep == _totalSteps - 1
                              ? 'Finalizar'
                              : 'Siguiente',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget para mostrar el indicador de pasos
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 120, // Ancho mayor al tener menos pasos
          height: 5,
          decoration: BoxDecoration(
            color: index <= _currentStep ? Colors.black : Colors.grey[300],
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // Widget para el paso 1: información básica
  Widget _buildBasicInfoStep() {
    return Column(
      children: [
        Text(
          "Crear tu cuenta",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Paso 1: Información básica",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Campos de texto existentes
        TextField(
          controller: nameController,
          decoration: _inputStyle('Nombre completo', Icons.person),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: emailController,
          decoration: _inputStyle('Correo electrónico', Icons.email),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: _inputStyle('Contraseña', Icons.lock),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: _inputStyle('Confirmar contraseña', Icons.lock_outline),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),

        // Términos y condiciones
        Row(
          children: [
            Checkbox(
              value: acceptTerms,
              onChanged: (v) => setState(() => acceptTerms = v!),
              activeColor: Colors.black,
            ),
            Expanded(
              child: Text(
                "Acepto los términos y condiciones",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget para el paso 2: perfil
  Widget _buildProfileStep() {
    return Column(
      children: [
        Text(
          "Completa tu perfil",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Paso 2: Personaliza tu perfil (opcional)",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Foto de perfil
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                _profileImage != null ? FileImage(_profileImage!) : null,
                child:
                _profileImage == null
                    ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Foto de portada
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
              image:
              _coverImage != null
                  ? DecorationImage(
                image: FileImage(_coverImage!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child:
            _coverImage == null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Añadir foto de portada',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            )
                : null,
          ),
        ),
        const SizedBox(height: 24),

        // Biografía
        TextField(
          controller: bioController,
          maxLines: 3,
          decoration: _inputStyle(
            'Acerca de mí (biografía)',
            Icons.description,
          ),
        ),
      ],
    );
  }
}