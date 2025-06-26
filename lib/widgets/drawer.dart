import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grow/rooms/fitness/room_fitness_home_page.dart';
import 'package:rxdart/rxdart.dart';
import '../screens/room_detail_page.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  Future<List<Map<String, dynamic>>> _getSalasUnidas() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

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

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Stream<int> _getNotificationCountStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    // Always include personal notifications for all users
    final notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    // First get the user's role
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .switchMap((userSnapshot) {
      final userData = userSnapshot.data();
      final userRole = userData?['role'] ?? 'usuario';

      // Only include pending rooms in count for owner accounts
      if (userRole == 'owner') {
        final pendingRoomsStream = FirebaseFirestore.instance
            .collection('pendingRooms')
            .snapshots()
            .map((snapshot) => snapshot.docs.length);

        return CombineLatestStream.list([notificationsStream, pendingRoomsStream])
            .map((counts) => counts.fold<int>(0, (p, c) => p + c));
      } else {
        // For regular users, only show their unread notifications
        return notificationsStream;
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo with flexible height
              Center(
                child: Image.asset(
                  'assets/grow_baja_calidad_blanco.png',
                  height: MediaQuery.of(context).size.height * 0.15, // Responsive height
                  fit: BoxFit.contain,
                ),
              ),
              _buildSearchBar(),
              const SizedBox(height: 16), // Reduced spacing

              // Make the rest of the content scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _drawerItem(context, Icons.home, 'Inicio', '/home_hub'),
                      _drawerItem(context, Icons.add, 'Crear sala', '/add_room_page'),

                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data?.data() != null) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            final userRole = userData['role'] ?? 'usuario';

                            if (userRole == 'owner') {
                              return _drawerItem(
                                  context,
                                  Icons.fitness_center,
                                  'Banco de Ejercicios',
                                  '/bench_exercises'
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      StreamBuilder<int>(
                        stream: _getNotificationCountStream(),
                        builder: (context, snapshot) {
                          int notificationCount = snapshot.data ?? 0;
                          return _drawerItemWithBadge(
                            context,
                            Icons.notifications,
                            'Notificaciones',
                            '/notification_page',
                            notificationCount,
                          );
                        },
                      ),
                      const Divider(color: Colors.white30, height: 32), // Reduced height
                      const Text(
                        'SALAS A LAS QUE TE HAS UNIDO',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12), // Reduced spacing

                      // Salas unidas with constrained height
                      SizedBox(
                        height: 200, // Fixed height for the list
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getSalasUnidas(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No estás unido a ninguna sala.',
                                  style: TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final sala = snapshot.data![index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: sala['logo'] != null && sala['logo'].toString().isNotEmpty
                                        ? CachedNetworkImageProvider(sala['logo'])
                                        : null,
                                    backgroundColor: Colors.grey[800],
                                    child: sala['logo'] == null || sala['logo'].toString().isEmpty
                                        ? Text(sala['nombre']?[0] ?? 'S', style: TextStyle(color: Colors.white))
                                        : null,
                                  ),
                                  title: Text(sala['nombre'] ?? '', style: const TextStyle(color: Colors.white)),
                                  onTap: () {
                                    Navigator.pop(context);

                                    if (sala['categoria']?.toLowerCase() == 'fitness') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RoomFitnessHomePage(
                                            roomId: sala['id'], userId: '',
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RoomDetailsPage(
                                            roomId: sala['id'],
                                            roomData: sala,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(color: Colors.white30, height: 20),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.white),
                        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar',
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _drawerItemWithBadge(
      BuildContext context,
      IconData icon,
      String label,
      String route,
      int notificationCount,
      ) {
    return ListTile(
      leading: SizedBox(
        width: 15,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            if (notificationCount > 0)
              Positioned(
                right: -2,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    notificationCount > 99 ? '99+' : '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}