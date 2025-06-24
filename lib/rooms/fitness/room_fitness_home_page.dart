import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grow/rooms/fitness/screens/chat_list_screen.dart';
import 'package:grow/rooms/fitness/screens/mylikes_screen.dart';
import 'package:grow/rooms/fitness/screens/room_settings_screen.dart';
import 'dart:ui';

// Importamos las pestañas
import 'admin/workout_form_screen.dart';
import 'tabs/fitness_home_tab.dart';
import 'tabs/fitness_routines_tab.dart';
import 'tabs/fitness_progress_tab.dart';
import 'tabs/fitness_community_tab.dart';

class RoomFitnessHomePage extends StatefulWidget {
  final String roomId;
  final String userId;

  const RoomFitnessHomePage({
    required this.roomId,
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  _RoomFitnessHomePageState createState() => _RoomFitnessHomePageState();
}

class _RoomFitnessHomePageState extends State<RoomFitnessHomePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? roomData;
  bool isAdmin = false;
  bool isLoading = true;
  int _currentIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showAdminOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                width: 1.5,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pull indicator
                Container(
                  margin: const EdgeInsets.only(bottom: 16, top: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const Text(
                  'Opciones de administrador',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildAdminOption(
                  icon: Icons.add_circle_outline,
                  title: 'Añadir nueva rutina',
                  subtitle: 'Crear una rutina para los miembros',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => WorkoutFormScreen(
                              roomId: widget.roomId,
                              userId: widget.userId,
                            ),
                      ),
                    );
                  },
                ),
                _buildAdminOption(
                  icon: Icons.video_library,
                  title: 'Añadir contenido',
                  subtitle: 'Subir videos de entrenamiento',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSection('add_content');
                  },
                ),
                _buildAdminOption(
                  icon: Icons.campaign,
                  title: 'Crear anuncio',
                  subtitle: 'Publicar mensaje para todos los miembros',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSection('create_announcement');
                  },
                ),
                _buildAdminOption(
                  icon: Icons.event,
                  title: 'Programar evento',
                  subtitle: 'Crear un desafío o evento comunitario',
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSection('schedule_event');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.withOpacity(0.7),
                Colors.blue.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _loadRoomData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final roomDoc = await _firestore.collection('rooms').doc(widget.roomId).get();

      if (roomDoc.exists) {
        final data = roomDoc.data() as Map<String, dynamic>;

        // Check if user is in the admins array
        bool adminStatus = false;
        if (data.containsKey('admins') && data['admins'] is List) {
          List<dynamic> admins = data['admins'];
          adminStatus = admins.contains(widget.userId);
        } else {
          // If no admins field exists, only the creator is admin
          adminStatus = widget.userId == data['creatorUid'];
        }

        setState(() {
          roomData = data;
          isAdmin = adminStatus;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La sala no existe o fue eliminada')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error loading room data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los datos de la sala')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: label == 'Mis likes' ? 'my_likes' : 'room_settings',
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _navigateToSection(String section) {
    if (section == 'my_likes') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyLikesScreen()),
      );
      return;
    }


    if (section == 'room_settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomSettingsScreen(
            roomId: widget.roomId,
            userId: widget.userId,
            roomData: roomData!,
          ),
        ),
      );
      return;
    }

    // Mapea las secciones a los índices de las pestañas
    int tabIndex;
    switch (section) {
      case 'home':
        tabIndex = 0;
        break;
      case 'workouts':
      case 'routines':
        tabIndex = 1;
        break;
      // case 'progress':
      //   tabIndex = 2;
      //   break;
      case 'community':
        tabIndex = 2;
        break;
      default:
        // Mostrar SnackBar para secciones no implementadas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sección no implementada: $section'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white24, width: 1),
            ),
          ),
        );
        return;
    }

    // Actualiza el índice actual para cambiar la pestaña
    setState(() {
      _currentIndex = tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    final List<Widget> screens = [
      FitnessHomeTab(
        roomData: roomData!,
        navigateToSection: _navigateToSection,
        userId: widget.userId,
      ),
      FitnessRoutinesTab(
        roomData: roomData!,
        navigateToSection: _navigateToSection,
        userId: widget.userId,
      ),
      // FitnessProgressTab(
      //   roomData: roomData!,
      //   navigateToSection: _navigateToSection,
      // ),
      FitnessCommunityTab(
        roomData: roomData!,
        navigateToSection: _navigateToSection,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        title: Text(
          roomData?['name'] ?? 'Sala Fitness',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
          actions: [
            // Add admin options button here
            if (isAdmin)
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.grey[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _showAdminOptions,
                  tooltip: 'Opciones de administrador',
                  splashRadius: 24,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            // Add chat icon button
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatListScreen(
                        roomId: widget.roomId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                tooltip: 'Chats',
                splashRadius: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Colors.white),
                offset: const Offset(0, 40),
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                itemBuilder: (context) => [
                  _buildMenuItem(
                    icon: Icons.favorite_border,
                    label: 'Mis likes',
                  ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    label: 'Configuración',
                  ),
                ],
                onSelected: (value) => _navigateToSection(value),
              ),
            ),
          ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 80, // Slightly increased height
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ), // More vertical padding
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
                _buildNavItem(
                  1,
                  Icons.fitness_center_outlined,
                  Icons.fitness_center,
                  'Rutinas',
                ),
                _buildNavItem(
                  2,
                  Icons.people_outline,
                  Icons.people,
                  'Comunidad',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border:
              isSelected
                  ? Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)
                  : null,
        ),
        // Using SizedBox to set a fixed height
        child: SizedBox(
          height: 37, // Setting a fixed height that won't overflow
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : Colors.white38,
                size: 18, // Slightly smaller icon
              ),
              const SizedBox(height: 1), // Smaller gap
              Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 10 : 9, // Smaller text
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white38,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
