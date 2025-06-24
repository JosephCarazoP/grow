import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../admin/manage_admins_screen.dart';
import 'archived_workouts_screen.dart';
import 'manage_room_discount_screen.dart';

class RoomSettingsScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final Map<String, dynamic> roomData;

  const RoomSettingsScreen({
    Key? key,
    required this.roomId,
    required this.userId,
    required this.roomData,
  }) : super(key: key);

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isAdmin = false;
  bool isLoading = true;
  List<String> admins = [];

  @override
  void initState() {
    super.initState();
    _loadRoomDetails();
  }

  Future<void> _loadRoomDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get admins list
      if (widget.roomData.containsKey('admins') &&
          widget.roomData['admins'] is List) {
        admins = List<String>.from(widget.roomData['admins']);

        // Check if current user is in the admins array
        isAdmin = admins.contains(widget.userId);
      } else {
        // If there's no admins field, initialize it with the creator
        // and only the creator is admin
        admins = [widget.roomData['creatorUid']];
        isAdmin = widget.userId == widget.roomData['creatorUid'];
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Room info section
                  _buildSectionTitle('Información de la sala'),
                  _buildSettingsTile(
                    icon: Icons.notifications_none,
                    title: 'Notificaciones',
                    subtitle: 'Administra las notificaciones de la sala',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función no implementada'),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.language,
                    title: 'Idioma',
                    subtitle: 'Cambia el idioma de la aplicación',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función no implementada'),
                        ),
                      );
                    },
                  ),

                  // Admin options section - only shown to creator
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Opciones de administrador'),
                    _buildSettingsTile(
                      icon: Icons.admin_panel_settings,
                      title: 'Administradores',
                      subtitle: 'Añadir o eliminar administradores',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ManageAdminsScreen(
                                  roomId: widget.roomId,
                                  currentUserId: widget.userId,
                                  admins: admins,
                                ),
                          ),
                        );
                      },
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.discount_outlined,
                      title: 'Descuento en sala',
                      subtitle: 'Configurar descuento para esta sala',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ManageRoomDiscountScreen(
                                  roomId: widget.roomId,
                                ),
                          ),
                        );
                      },
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.amber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ],

                  // General settings
                  const SizedBox(height: 24),
                  _buildSectionTitle('General'),
                  _buildSettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacidad',
                    subtitle: 'Administra la configuración de privacidad',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función no implementada'),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.archive_outlined,
                    title: 'Rutinas archivadas',
                    subtitle: 'Ver rutinas que has ocultado',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArchivedWorkoutsScreen(
                            roomId: widget.roomId,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Ayuda',
                    subtitle: 'Centro de ayuda y soporte',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función no implementada'),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'Acerca de',
                    subtitle: 'Información sobre la aplicación',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función no implementada'),
                        ),
                      );
                    },
                  ),
                ],
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Gradient? gradient,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient:
                gradient ??
                LinearGradient(
                  colors: [Colors.grey[800]!, Colors.grey[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
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
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white54,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
