import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grow/screens/room_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_hub.dart';
import 'introduction_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool rememberMe = false;
  bool isLoading = false;
  bool _obscureText = true;

  void _showError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error de inicio de sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> login() async {
    setState(() => isLoading = true);

    try {
      // Firebase Authentication
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Fetch user data from Firestore
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        _showError("El perfil de usuario no existe en la base de datos.");
        setState(() => isLoading = false);
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'user';

      // Save last login timestamp
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Save "Remember Me" state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', rememberMe);

      // Redirect based on role
      if (role == 'owner') {
        // Redirect to HomeHub if the role is owner
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeHubPage()),
        );
      } else {
        // Check if this is the user's first login by checking account creation time
        final accountCreatedAt = userCredential.user!.metadata.creationTime;
        final now = DateTime.now();
        final timeDifference = now.difference(accountCreatedAt!);

        // If account was created less than 5 minutes ago, consider it a new user
        final isNewUser = timeDifference.inMinutes < 5;

        // Also check SharedPreferences as backup
        final hasSeenIntro = await prefs.getBool('hasSeenIntro') ?? false;

        if (isNewUser || !hasSeenIntro) {
          // First time user - show introduction
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GrowIntroScreen()),
          );
        } else {
          // Returning user - go directly to Discipline room
          final querySnapshot =
          await FirebaseFirestore.instance
              .collection('rooms')
              .where('name', isEqualTo: 'Discipline')
              .where('oficial', isEqualTo: true)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final roomData = querySnapshot.docs.first.data();
            final roomId = querySnapshot.docs.first.id;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) => RoomDetailsPage(roomId: roomId, roomData: roomData),
              ),
            );
          } else {
            _showError("No se encontró la sala oficial 'Discipline'.");
            setState(() => isLoading = false);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      String message = switch (e.code) {
        'user-not-found' => 'No existe una cuenta con este correo.\nVerifica que esté bien escrito o regístrate.',
        'wrong-password' => 'Contraseña incorrecta.\nRevisa tu contraseña e intenta nuevamente.',
        'invalid-email' => 'El formato del correo es inválido.\nEjemplo: usuario@gmail.com',
        'user-disabled' => 'Esta cuenta ha sido deshabilitada.\nContacta al soporte para más información.',
        'too-many-requests' => 'Demasiados intentos fallidos.\nPor seguridad, intenta más tarde.',
        'network-request-failed' => 'Error de conexión.\nVerifica tu conexión a internet e intenta de nuevo.',
        'invalid-credential' => 'Las credenciales son incorrectas.\nRevisa tu correo y contraseña.',
        'operation-not-allowed' => 'Operación no permitida.\nContacta al administrador.',
        'weak-password' => 'La contraseña es muy débil.\nDebe tener al menos 6 caracteres.',
        _ => 'Error al iniciar sesión.\nCódigo: ${e.code}',
      };

      _showError(message);
    } catch (e) {
      setState(() => isLoading = false);

      // Manejar errores de red específicos
      if (e.toString().contains('network error') ||
          e.toString().contains('timeout') ||
          e.toString().contains('interrupted connection') ||
          e.toString().contains('unreachable host')) {
        _showError(
            'Sin conexión a internet.\nVerifica tu conexión e intenta nuevamente.'
        );
      } else if (e.toString().contains('RecaptchaCallWrapper') ||
          e.toString().contains('recaptcha')) {
        _showError(
            'Error de verificación de seguridad.\nIntenta nuevamente en unos momentos.'
        );
      } else {
        _showError(
            'Ocurrió un error inesperado.\nIntenta nuevamente más tarde.'
        );
      }
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[700]),
      prefixIcon: Icon(icon, color: Colors.grey[800]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo sin marco
                  Image.asset(
                    'assets/grow_baja_calidad_negro.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  // Títulos
                  Text(
                    "Bienvenido de nuevo",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Campos
                  TextField(
                    controller: emailController,
                    decoration: _inputStyle('Correo electrónico', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    decoration: _inputStyle('Contraseña', Icons.lock).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => login(),
                    style: TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  // Remember me
                  // Replace the Row widget (around line 190) with this responsive layout:
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Check if screen is small (less than 350px width)
                      bool isSmallScreen = constraints.maxWidth < 350;

                      if (isSmallScreen) {
                        // Vertical layout for small screens
                        // Replace the Column in the small screen layout (around line 170) with this centered version:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.scale(
                                  scale: 0.9,
                                  child: Checkbox(
                                    value: rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Text(
                                  "Recordar sesión",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Horizontal layout for normal screens
                        return Row(
                          children: [
                            Transform.scale(
                              scale: 0.9,
                              child: Checkbox(
                                value: rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    rememberMe = value ?? false;
                                  });
                                },
                                activeColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Text(
                              "Recordar sesión",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón
                  ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.3),
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),

                  const SizedBox(height: 30),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "¿No tienes cuenta? ",
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Registrarse",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
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
}
