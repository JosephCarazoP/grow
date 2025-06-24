import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grow/screens/profile_page.dart';
import 'package:grow/screens/room_detail_page.dart';
import 'package:grow/screens/user_profile_page.dart';
import 'package:rxdart/rxdart.dart';

import '../widgets/drawer.dart';

class HomeHubPage extends StatefulWidget {
  const HomeHubPage({super.key});

  @override
  State<HomeHubPage> createState() => _HomeHubPageState();
}

class _HomeHubPageState extends State<HomeHubPage> {
  String selectedCategory = '';
  String searchQuery = '';
  bool sortByPriceDescending = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Stream<int> _getTotalNotificationCount() {
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
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          leading: StreamBuilder<int>(
            stream: _getTotalNotificationCount(),
            builder: (context, snapshot) {
              final notificationCount = snapshot.data ?? 0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 8,
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
              );
            },
          ),
          title: Image.asset('assets/grow_baja_calidad_negro.png', height: 100),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🔍 Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar salas o creadores...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 16),

              // 🎯 Categories
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('Fitness'),
                    _buildCategoryChip('Educación'),
                    _buildCategoryChip('Negocios'),
                    _buildCategoryChip('Desarrollo personal'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🔽 Sorting Options
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Ordenar por precio:'),
                  IconButton(
                    icon: Icon(
                      sortByPriceDescending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                    ),
                    onPressed: () {
                      setState(() {
                        sortByPriceDescending = !sortByPriceDescending;
                      });
                    },
                  ),
                ],
              ),

              // 🛍️ Filtered Room List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('rooms')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No hay salas disponibles"),
                      );
                    }

                    // Apply filters
                    var salas =
                        snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return {'id': doc.id, ...data};
                        }).toList();

                    if (selectedCategory.isNotEmpty) {
                      salas = salas.where(
                            (sala) =>
                        (sala['category'] ?? '').toString().toLowerCase().trim() ==
                            selectedCategory.toLowerCase().trim(),
                      ).toList();
                    }

                    if (searchQuery.isNotEmpty) {
                      salas =
                          salas.where((sala) {
                            final name = sala['name']?.toLowerCase() ?? '';
                            final creator =
                                sala['creatorName']?.toLowerCase() ?? '';
                            return name.contains(searchQuery) ||
                                creator.contains(searchQuery);
                          }).toList();
                    }

                    if (sortByPriceDescending) {
                      salas.sort(
                        (a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0),
                      );
                    } else {
                      salas.sort(
                        (a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0),
                      );
                    }

                    return ListView.builder(
                      itemCount: salas.length,
                      itemBuilder: (context, index) {
                        final data = salas[index];

                        return ComunidadCard(
                          imageUrl: data['coverImage'] ?? '',
                          nombre: data['name'] ?? '',
                          descripcion: data['shortDescription'] ?? '',
                          creadorNombre:
                              data['creatorName'] ?? 'Creador desconocido',
                          creadorAvatar:
                              data['creatorPhoto'] ??
                              'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png',
                          precio: (data['price'] ?? 0).toDouble(),
                          descuento: (data['discount'] ?? 0).toDouble(),
                          categoria: data['category'] ?? 'Sin categoría',
                          imagePosition:
                              (data['imagePosition'] ?? 0.0) as double,
                          roomData: data,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(category),
        selected: selectedCategory == category,
        onSelected: (isSelected) {
          setState(() {
            selectedCategory = isSelected ? category : '';
          });
        },
      ),
    );
  }
}

class ComunidadCard extends StatelessWidget {
  final String imageUrl;
  final String nombre;
  final String descripcion;
  final String creadorNombre;
  final String creadorAvatar;
  final double precio;
  final double descuento;
  final String categoria;
  final double imagePosition;
  final Map<String, dynamic> roomData;

  const ComunidadCard({
    required this.imageUrl,
    required this.nombre,
    required this.descripcion,
    required this.creadorNombre,
    required this.creadorAvatar,
    required this.precio,
    required this.descuento,
    required this.categoria,
    this.imagePosition = 0.0,
    required this.roomData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final precioFinal = precio * (1 - (descuento / 100));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomDetailsPage(
              roomId: roomData['id'],
              roomData: roomData,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment(0, imagePosition),
                    memCacheWidth: 360,  // Limitar tamaño en caché
                    memCacheHeight: 240,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      print('Error cargando imagen tarjeta: $error');
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      );
                    },
                  ),
                ),
                if (descuento > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${descuento.toInt()}%',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(descripcion),
                  const SizedBox(height: 8),
                  Text(
                    'Categoría: $categoria',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navegar al perfil del usuario al hacer clic en su avatar
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfilePage(userId: roomData['creatorUid']),
                        ),
                      );
                    },
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(roomData['creatorUid'])
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[200],
                          );
                        }

                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          final photoUrl = userData?['photo'] as String?;

                          return CircleAvatar(
                            radius: 20,
                            backgroundImage: photoUrl != null &&
                                photoUrl.isNotEmpty &&
                                photoUrl.startsWith('http')
                                ? CachedNetworkImageProvider(photoUrl)
                                : const AssetImage('assets/default_avatar.png') as ImageProvider,
                          );
                        }

                        return CircleAvatar(
                          radius: 20,
                          backgroundImage: const AssetImage('assets/default_avatar.png'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(userId: roomData['creatorUid']),
                          ),
                        );
                      },
                      child: Text(
                        creadorNombre,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '₡${precioFinal.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}