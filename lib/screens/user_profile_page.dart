import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:grow/screens/room_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../rooms/fitness/room_fitness_home_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({required this.userId, Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  Offset _coverImageOffset = Offset.zero;
  Offset _profileImageOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  bool _hasSocialLinks() {
    if (userData == null || userData!['socials'] == null) return false;

    final socials = userData!['socials'];
    return (socials['facebook'] != null && socials['facebook'].toString().isNotEmpty) ||
        (socials['instagram'] != null && socials['instagram'].toString().isNotEmpty) ||
        (socials['twitter'] != null && socials['twitter'].toString().isNotEmpty) ||
        (socials['whatsapp'] != null && socials['whatsapp'].toString().isNotEmpty);
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;

          // Load saved image offsets
          if (userData?['coverOffset'] != null) {
            _coverImageOffset = Offset(
              userData!['coverOffset']['dx'] ?? 0.0,
              userData!['coverOffset']['dy'] ?? 0.0,
            );
          }

          if (userData?['profileOffset'] != null) {
            _profileImageOffset = Offset(
              userData!['profileOffset']['dx'] ?? 0.0,
              userData!['profileOffset']['dy'] ?? 0.0,
            );
          }
        });
      } else {
        setState(() {
          userData = null;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        userData = null;
        isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return 'Se unió el ${DateFormat('d \'de\' MMMM \'de\' y', 'es').format(date)}';
    }

    return 'Fecha desconocida';
  }

  void _openUrl(String url) async {
    // Add a basic check for URL scheme, defaulting to https if missing
    String formattedUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';

    if (await canLaunchUrl(Uri.parse(formattedUrl))) {
      await launchUrl(
        Uri.parse(formattedUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $formattedUrl')),
      );
    }
  }

  Widget _buildSocialButtonsEnhanced() {
    if (!_hasSocialLinks()) {
      return const SizedBox.shrink();
    }

    final socials = userData!['socials'];
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (socials['facebook'] != null && socials['facebook'].isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.facebook,
              color: const Color(0xFF1877F2),
              onTap: () => _openUrl(socials['facebook']),
            ),
          if (socials['instagram'] != null && socials['instagram'].isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.instagram,
              color: const Color(0xFFE1306C),
              onTap: () => _openUrl(socials['instagram']),
            ),
          if (socials['twitter'] != null && socials['twitter'].isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.twitter,
              color: const Color(0xFF1DA1F2),
              onTap: () => _openUrl(socials['twitter']),
            ),
          if (socials['whatsapp'] != null && socials['whatsapp'].isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.whatsapp,
              color: const Color(0xFF25D366),
              onTap: () => _openUrl(socials['whatsapp']),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButtonProfessional({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.9),
                color,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FaIcon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildInfoSectionEnhanced({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Image.asset('assets/grow_baja_calidad_negro.png', height: 110),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/grow_baja_calidad_negro.png', height: 60),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      )
          : userData == null
          ? const Center(child: Text('No se encontró el perfil del usuario'))
          : CustomScrollView(
        slivers: [
          // Cover image and profile picture section
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover image with applied offset
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                  ),
                  child: Stack(
                    children: [
                      // Cover image with offset
                      if (userData?['coverPhoto'] != null)
                        ClipRect(
                          child: OverflowBox(
                            maxHeight: double.infinity,
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: _coverImageOffset,
                              child: Image.network(
                                userData!['coverPhoto'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )
                      else
                      // Fallback to placeholder image
                        Image(
                          image: AssetImage('assets/grow_baja_calidad_negro.png'),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          color: Colors.grey.withOpacity(0.7),
                          colorBlendMode: BlendMode.saturation,
                          opacity: const AlwaysStoppedAnimation(0.1),
                        ),

                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom profile container
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                  ),
                ),

                // Profile image
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userData?['photo'] != null
                            ? NetworkImage(userData!['photo'])
                            : null,
                        child: userData?['photo'] == null
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 20),
              child: Column(
                children: [
                  // User name
                  Text(
                    userData?['name'] ?? 'Usuario',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Join date
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      _formatDate(userData?['createdAt']),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // Email if available
                  if (userData?['email'] != null)
                    Text(
                      userData!['email'],
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Social media buttons
          SliverToBoxAdapter(
            child: _buildSocialButtonsEnhanced(),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                height: 1,
                color: Colors.grey[200],
              ),
            ),
          ),

          // Description section if available
          if (userData?['description'] != null && userData!['description'].isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: _buildInfoSectionEnhanced(
                  title: 'ACERCA DE MÍ',
                  icon: Icons.person_outline,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      userData!['description'],
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Rooms section - add to the existing SliverToBoxAdapter list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: _buildInfoSectionEnhanced(
                title: 'SALAS',
                icon: Icons.meeting_room_outlined,
                child: _buildRoomsListProfessional(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsListProfessional() {
    // Verificar si el usuario permite mostrar sus salas unidas
    final bool showJoinedRooms = userData?['showJoinedRooms'] ?? false;

    // Si el usuario no permite ver sus salas, mostrar mensaje de privacidad
    if (!showJoinedRooms && FirebaseAuth.instance.currentUser?.uid != widget.userId) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 42,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Este usuario ha configurado sus salas como privadas',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Only continue to load rooms if user allows it
    final String userId = widget.userId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSalasUnidas(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.meeting_room_outlined,
                    size: 42,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Este usuario no se ha unido a ninguna sala',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final rooms = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final sala = rooms[index];
            final String roomId = sala['id'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Si la categoría es Fitness, dirigir a room_fitness_homepage
                      if (sala['categoria']?.toLowerCase() == 'fitness') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomFitnessHomePage(
                              roomId: roomId,
                              userId: userId,
                            ),
                          ),
                        );
                      } else {
                        // Para otras categorías, usar la página general de detalle de sala
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailsPage(
                              roomId: roomId,
                              roomData: sala,
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        // Room image
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(sala['logo'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Room info
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sala['nombre'] ?? 'Sala sin nombre',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sala['descripcion'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getSalasUnidas(String userId) async {
    if (userId.isEmpty) return [];

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      // If viewing your own profile, you always have access
      if (currentUser.uid == userId) {
        final snapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .collection('salasUnidas')
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {...data, 'id': doc.id};
        }).toList();
      }
      // If viewing someone else's profile, check their privacy settings first
      else {
        // First check if the user allows others to view their joined rooms
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final userData = userDoc.data();
        final showJoinedRooms = userData?['showJoinedRooms'] ?? false;

        if (showJoinedRooms) {
          final snapshot = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(userId)
              .collection('salasUnidas')
              .get();

          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();
        } else {
          // User doesn't allow others to see their rooms
          return [];
        }
      }
    } catch (e) {
      print('Error fetching joined rooms: $e');
      return [];
    }
  }
}