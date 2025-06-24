import 'package:flutter/material.dart';
// Importaciones necesarias para localización
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart'; // Importa intl
import 'package:intl/date_symbol_data_local.dart'; // Necesario para initializeDateFormatting

import 'screens/welcome_page.dart';
import 'screens/home_hub.dart';
import 'screens/add_room_page.dart';
import 'screens/notification_page.dart';
import 'screens/login_page.dart';
import 'firebase_options.dart';
import 'screens/bench_exercise_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grow/screens/profile_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa los datos de formato de fecha para el locale español
  // Esto es crucial para que DateFormat('...', 'es') funcione
  await initializeDateFormatting('es', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        focusColor: Colors.black,
        splashColor: Colors.black.withOpacity(0.1),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black),
            foregroundColor: Colors.black,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.all(Colors.black),
          checkColor: MaterialStateProperty.all(Colors.white),
        ),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          error: Colors.black,
          onError: Colors.white,
          background: Colors.white,
          onBackground: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      // Configuración de localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Define los locales que tu app soporta
      supportedLocales: const [
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español (necesario para DateFormat('...', 'es'))
        // Agrega otros locales que soportes si es necesario
      ],
      // Opcional: Lógica para resolver el locale si el del dispositivo no está soportado
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // Si el locale del dispositivo no está soportado, usa el primero de la lista (ej. inglés)
        return supportedLocales.first;
      },

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home_hub': (context) => const HomeHubPage(),
        '/add_room_page': (context) => const AddRoomPage(),
        '/notification_page': (context) => const NotificationsPage(),
        '/login': (context) => const LoginPage(),
        '/bench_exercises': (context) => const BenchExercisesPage(),
      },
    );
  }
}

// SplashScreen para decidir la página inicial
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<Widget> _getInitialPage() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Simula un pequeño retraso para que el splash screen sea visible
    await Future.delayed(const Duration(seconds: 1));

    if (rememberMe && currentUser != null) {
      return const HomeHubPage();
    } else {
      return const WelcomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Muestra un indicador de carga mientras se determina la página inicial
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          // Maneja errores si ocurren durante la determinación de la página
          print('Error determining initial page: ${snapshot.error}');
          return const WelcomePage(); // O una página de error
        }
        else if (snapshot.hasData) {
          // Navega a la página determinada sin usar rutas con Navigator
          // Esto reemplaza la pantalla actual (SplashScreen) con la nueva
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => snapshot.data!),
            );
          });
          // Muestra un contenedor vacío mientras se realiza la navegación
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else {
          // En caso de que no haya datos (aunque _getInitialPage siempre devuelve un Widget)
          return const WelcomePage();
        }
      },
    );
  }
}
