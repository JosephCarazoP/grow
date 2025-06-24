import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class ManageAdminsScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final List<String> admins;

  const ManageAdminsScreen({
    Key? key,
    required this.roomId,
    required this.currentUserId,
    required this.admins,
  }) : super(key: key);

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> roomMembers = [];
  List<String> currentAdmins = [];
  bool isLoading = true;
  String? roomCreatorId;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    currentAdmins = [...widget.admins];
    _loadRoomData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get room details to find the creator and admin list
      final roomDoc = await _firestore.collection('rooms').doc(widget.roomId).get();
      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        roomCreatorId = roomData['creatorUid'];

        // Ensure currentAdmins is properly initialized
        if (roomData.containsKey('admins') && roomData['admins'] is List) {
          currentAdmins = List<String>.from(roomData['admins']);
        } else {
          // If no admins field exists, initialize with creator
          currentAdmins = [roomCreatorId!];
        }

        // Get all room members from the members collection
        final membersSnapshot = await _firestore
            .collection('members')
            .where('roomId', isEqualTo: widget.roomId)
            .get();

        // Debug information
        print('Found ${membersSnapshot.docs.length} members for room ${widget.roomId}');

        // Process each member document
        for (final memberDoc in membersSnapshot.docs) {
          final memberData = memberDoc.data();
          final memberId = memberData['userId'] as String;

          print('Processing member: $memberId');

          // Get user details from users collection
          try {
            final userDoc = await _firestore.collection('users').doc(memberId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;

              // Debug the user data to see what's available
              print('User data for $memberId: ${userData.keys.join(', ')}');
              print('Photo URL: ${userData['photoUrl']}');

              roomMembers.add({
                'id': memberId,
                'name': userData['name'] ?? 'Usuario',
                'photoUrl': userData['photo'] ?? '',
                'isAdmin': currentAdmins.contains(memberId),
                'isCreator': memberId == roomCreatorId,
                'email': userData['email'] ?? '',
                'memberSince': memberData['joinedAt'] ?? Timestamp.now(),
              });
            } else {
              print('User document not found for ID: $memberId');
              // Add a placeholder for users without documents
              roomMembers.add({
                'id': memberId,
                'name': 'Usuario $memberId',
                'photoUrl': '',
                'isAdmin': currentAdmins.contains(memberId),
                'isCreator': memberId == roomCreatorId,
                'email': '',
                'memberSince': memberData['joinedAt'] ?? Timestamp.now(),
              });
            }
          } catch (e) {
            print('Error fetching user data for $memberId: $e');
          }
        }

        // Sort members: creator first, then admins, then regular members
        roomMembers.sort((a, b) {
          if (a['isCreator'] == true) return -1;
          if (b['isCreator'] == true) return 1;
          if (a['isAdmin'] == true && b['isAdmin'] != true) return -1;
          if (b['isAdmin'] == true && a['isAdmin'] != true) return 1;
          return a['name'].toString().compareTo(b['name'].toString());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar miembros: $e')),
      );
      print('Error loading members: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Filter members based on search query
  List<Map<String, dynamic>> get filteredMembers {
    if (searchQuery.isEmpty) return roomMembers;

    return roomMembers.where((member) {
      return member['name'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          member['email'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          );
    }).toList();
  }

  Future<void> _updateAdminStatus(String userId, bool makeAdmin) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
    );

    try {
      // Update local state first
      setState(() {
        if (makeAdmin && !currentAdmins.contains(userId)) {
          currentAdmins.add(userId);
        } else if (!makeAdmin && currentAdmins.contains(userId)) {
          currentAdmins.remove(userId);
        }

        // Update the user in the list
        for (var i = 0; i < roomMembers.length; i++) {
          if (roomMembers[i]['id'] == userId) {
            roomMembers[i]['isAdmin'] = makeAdmin;
            break;
          }
        }
      });

      // Make sure creator is always in the admin list
      if (!currentAdmins.contains(roomCreatorId)) {
        currentAdmins.add(roomCreatorId!);
      }

      // Update Firestore
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'admins': currentAdmins,
      });

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              makeAdmin
                  ? 'Administrador añadido con éxito'
                  : 'Administrador eliminado con éxito',
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      print('Error updating admin status: $e');
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
          'Administrar administradores',
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
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info text
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'Los administradores pueden crear rutinas, subir contenido y gestionar la sala.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Admin count
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Text(
                      'Administradores actuales: ${currentAdmins.length}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar miembros...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        suffixIcon:
                            searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                                : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white24),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.withOpacity(0.7),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Toca el interruptor para agregar o eliminar administradores.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Members list
                  Expanded(
                    child:
                        filteredMembers.isEmpty
                            ? Center(
                              child: Text(
                                'No se encontraron miembros',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = filteredMembers[index];
                                final bool isCreator =
                                    member['isCreator'] == true;
                                final bool isAdmin = member['isAdmin'] == true;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isAdmin
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isAdmin
                                              ? Colors.blue.withOpacity(0.5)
                                              : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    // Update the CircleAvatar in the ListTile within the build method
// Then in your ListTile:
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey[800],
                                      radius: 24,
                                      child: ClipOval(
                                        child: (member['photoUrl'] != null && member['photoUrl'].toString().isNotEmpty)
                                            ? CachedNetworkImage(
                                          imageUrl: member['photoUrl'].toString(),
                                          fit: BoxFit.cover,
                                          width: 48,
                                          height: 48,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => const Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                            size: 24,
                                          ),
                                        )
                                            : const Icon(Icons.person, color: Colors.white70, size: 24),
                                      ),
                                    ),
                                    title: Text(
                                      member['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (member['email'] != null &&
                                            member['email']
                                                .toString()
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              member['email'],
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.6,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (isCreator)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Colors.purple,
                                                          Colors.blue,
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'Creador',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              )
                                            else if (isAdmin)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'Admin',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing:
                                        isCreator
                                            ? const Tooltip(
                                              message:
                                                  "No se puede modificar el creador",
                                              child: Icon(
                                                Icons.lock,
                                                color: Colors.white30,
                                                size: 20,
                                              ),
                                            )
                                            : Switch(
                                              value: isAdmin,
                                              onChanged: (value) {
                                                _updateAdminStatus(
                                                  member['id'],
                                                  value,
                                                );
                                              },
                                              activeColor: Colors.blue,
                                              activeTrackColor: Colors.blue
                                                  .withOpacity(0.3),
                                              inactiveThumbColor: Colors.grey,
                                              inactiveTrackColor: Colors.grey
                                                  .withOpacity(0.3),
                                            ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
