// lib/rooms/fitness/screens/chat_list_screen.dart
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String roomId;
  final String userId;

  const ChatListScreen({
    Key? key,
    required this.roomId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> chatList = [];
  bool _isLoadingMembers = false;
  List<Map<String, dynamic>> _roomMembers = [];


  @override
  void initState() {
    super.initState();
    _loadRoomMembers();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('Loading chats for user: ${widget.userId} in room: ${widget.roomId}');

      // Get all chats where the current user is a participant
      final chatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.userId)
          .where('roomId', isEqualTo: widget.roomId)
          .get();

      print('Found ${chatQuery.docs.length} chats in the initial query');

      final List<Map<String, dynamic>> loadedChats = [];

      for (var chatDoc in chatQuery.docs) {
        final chatData = chatDoc.data();
        print('Processing chat: ${chatDoc.id}');

        // Verificar si el usuario actual ha eliminado este chat
        List<String> deletedBy = [];
        if (chatData.containsKey('deletedBy') && chatData['deletedBy'] is List) {
          deletedBy = List<String>.from(chatData['deletedBy']);
          print('Chat has deletedBy: $deletedBy');
        }

        // Si el usuario actual ha eliminado este chat, omitirlo
        if (deletedBy.contains(widget.userId)) {
          print('Skipping chat ${chatDoc.id} - deleted by current user');
          continue;
        }

        if (chatData.containsKey('fullyDeleted') &&
            chatData['fullyDeleted'] == true &&
            deletedBy.contains(widget.userId)) {
          print('Skipping chat ${chatDoc.id} - fully deleted and deleted by current user');
          continue;
        }

        final participants = List<String>.from(chatData['participants'] ?? []);
        print('Chat participants: $participants');

        // Filter out current user to get the other participant
        participants.remove(widget.userId);
        String otherUserId = participants.isNotEmpty
            ? participants.first
            : 'unknown';

        print('Other user ID: $otherUserId');

        String otherUserName = 'Usuario';
        String otherUserPhoto = '';

        // Intentar obtener información del participante desde el documento del chat
        if (chatData.containsKey('participantInfo') &&
            chatData['participantInfo'] is Map) {

          final participantInfo = chatData['participantInfo'] as Map<String, dynamic>;

          // Intentar obtener información del otro usuario
          if (participantInfo.containsKey(otherUserId)) {
            final otherUserInfo = participantInfo[otherUserId];
            if (otherUserInfo is Map<String, dynamic>) {
              otherUserName = otherUserInfo['name'] ?? 'Usuario';
              otherUserPhoto = otherUserInfo['photo'] ?? '';
              print('Encontrada info del usuario en participantInfo: $otherUserName');
            }
          }

          // Si no se encuentra información o está incompleta, buscar en users
          if (otherUserName == 'Usuario' || otherUserPhoto.isEmpty) {
            print('Buscando información adicional del usuario: $otherUserId');
            final userDoc = await _firestore.collection('users')
                .doc(otherUserId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data() ?? {};

              if (otherUserName == 'Usuario') {
                otherUserName = userData['displayName'] ??
                    userData['username'] ??
                    userData['name'] ?? 'Usuario';
              }

              if (otherUserPhoto.isEmpty) {
                otherUserPhoto = userData['photoURL'] ??
                    userData['photoUrl'] ??
                    userData['profilePic'] ?? '';
              }

              // Actualizar el documento del chat con la nueva información
              Map<String, dynamic> updatedParticipantInfo = {...participantInfo};
              updatedParticipantInfo[otherUserId] = {
                'name': otherUserName,
                'photo': otherUserPhoto
              };

              await _firestore.collection('chats').doc(chatDoc.id).update({
                'participantInfo': updatedParticipantInfo
              });

              print('Actualizada información del usuario en el chat: $otherUserName');
            }
          }
        } else {
          // Si el chat no tiene participantInfo, buscarlo en users y actualizar
          print('El chat no tiene participantInfo, buscando en users');
          final userDoc = await _firestore.collection('users')
              .doc(otherUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            otherUserName = userData['displayName'] ?? 'Usuario';
            otherUserPhoto = userData['photoURL'] ?? '';

            // Crear un nuevo campo participantInfo
            Map<String, dynamic> participantInfo = {
              otherUserId: {
                'name': otherUserName,
                'photo': otherUserPhoto
              }
            };

            // También incluir la información del usuario actual
            final currentUserDoc = await _firestore.collection('users')
                .doc(widget.userId)
                .get();

            if (currentUserDoc.exists) {
              final currentUserData = currentUserDoc.data() ?? {};
              participantInfo[widget.userId] = {
                'name': currentUserData['displayName'] ?? 'Usuario',
                'photo': currentUserData['photoURL'] ?? ''
              };
            }

            // Actualizar el documento del chat
            await _firestore.collection('chats').doc(chatDoc.id).update({
              'participantInfo': participantInfo
            });

            print('Creado campo participantInfo en el chat');
          }
        }

        // Get last message
        final lastMessageQuery = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        Map<String, dynamic> lastMessageData = {};
        if (lastMessageQuery.docs.isNotEmpty) {
          lastMessageData = lastMessageQuery.docs.first.data();
          print('Found last message: ${lastMessageData['text']}');
        } else {
          print('No messages found for chat ${chatDoc.id}');
        }

        loadedChats.add({
          'chatId': chatDoc.id,
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'otherUserPhoto': otherUserPhoto,
          'lastMessage': lastMessageData['text'] ?? '',
          'lastMessageTime': lastMessageData['timestamp'] ?? Timestamp.now(),
          'unreadCount': 0, // You can implement this logic later
        });

        print('Added chat to list: ${chatDoc.id}');
      }

      print('Final loaded chats count: ${loadedChats.length}');

      setState(() {
        chatList = loadedChats;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading chats: $e');
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
        title: const Text(
          'Mensajes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implement search functionality later
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () {
              _showMembersDialog();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : chatList.isEmpty
          ? _buildEmptyState()
          : _buildChatList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes conversaciones',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Inicia una conversación con otro miembro',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              _showMembersDialog();
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nuevo mensaje'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: chatList.length,
      itemBuilder: (context, index) {
        final chat = chatList[index];
        final timestamp = chat['lastMessageTime'] as Timestamp;
        final dateTime = timestamp.toDate();
        final now = DateTime.now();

        // Check if user is admin
        final bool isAdmin = _roomMembers.any((member) =>
        member['id'] == chat['otherUserId'] && member['role'] == 'admin');

        String timeText;
        if (now.difference(dateTime).inDays == 0) {
          // Today - show time
          final hour = dateTime.hour.toString().padLeft(2, '0');
          final minute = dateTime.minute.toString().padLeft(2, '0');
          timeText = '$hour:$minute';
        } else if (now.difference(dateTime).inDays < 7) {
          // This week - show day name
          final List<String> days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
          timeText = days[dateTime.weekday - 1];
        } else {
          // Older - show date
          final day = dateTime.day.toString().padLeft(2, '0');
          final month = dateTime.month.toString().padLeft(2, '0');
          timeText = '$day/$month';
        }

        return Dismissible(
          key: Key(chat['chatId']),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade800.withOpacity(0.8),
                  Colors.red.shade600.withOpacity(0.9),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmation(chat['chatId']);
          },
          onDismissed: (direction) {
            setState(() {
              chatList.removeAt(index);
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[900]!.withOpacity(0.7),
                  Colors.grey[850]!.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isAdmin ?
              Colors.blue.withOpacity(0.3) :
              Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        chatId: chat['chatId'],
                        otherUserId: chat['otherUserId'],
                        otherUserName: chat['otherUserName'],
                        otherUserPhoto: chat['otherUserPhoto'],
                        currentUserId: widget.userId,
                      ),
                    ),
                  ).then((_) => _loadChats());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Avatar with admin badge
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isAdmin ?
                                Colors.blue.withOpacity(0.4) :
                                Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isAdmin ?
                                  Colors.blue.withOpacity(0.2) :
                                  Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: chat['otherUserPhoto'].isNotEmpty
                                  ? CachedNetworkImageProvider(chat['otherUserPhoto'])
                                  : null,
                              child: chat['otherUserPhoto'].isEmpty
                                  ? Text(
                                chat['otherUserName'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                                  : null,
                            ),
                          ),
                          // Admin verification badge
                          if (isAdmin)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          // Unread indicator
                          if (chat['unreadCount'] > 0)
                            Positioned(
                              right: isAdmin ? 15 : 0,
                              top: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Message content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          chat['otherUserName'],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isAdmin)
                                        const SizedBox(width: 4),
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    timeText,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat['lastMessage'] != ''
                                        ? chat['lastMessage']
                                        : 'Sin mensajes',
                                    style: TextStyle(
                                      color: chat['unreadCount'] > 0
                                          ? Colors.white.withOpacity(0.9)
                                          : Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                      fontWeight: chat['unreadCount'] > 0
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (chat['unreadCount'] > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      chat['unreadCount'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmation(String chatId) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '¿Eliminar chat?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Esta acción no se puede deshacer y eliminará todos los mensajes.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
        child: const Text('CANCELAR', style: TextStyle(color: Colors.white)),
                    ),
            TextButton(
              onPressed: () {
                _deleteChat(chatId);
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('ELIMINAR'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Obtener el documento del chat actual
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data() ?? {};

      // Obtener o inicializar el array deletedBy
      List<String> deletedBy = [];
      if (chatData.containsKey('deletedBy') && chatData['deletedBy'] is List) {
        deletedBy = List<String>.from(chatData['deletedBy']);
      }

      // Añadir al usuario actual al array si no está ya
      if (!deletedBy.contains(widget.userId)) {
        deletedBy.add(widget.userId);
      }

      // Obtener la lista de participantes
      final List<String> participants = List<String>.from(chatData['participants'] ?? []);

      // Si todos los participantes han eliminado el chat, marcarlo como completamente eliminado
      if (deletedBy.length == participants.length) {
        // Mark as fully deleted ONLY if ALL participants have deleted it
        await _firestore.collection('chats').doc(chatId).update({
          'deletedBy': deletedBy,
          'fullyDeleted': true,
          'lastUpdate': FieldValue.serverTimestamp()
        });
      }else {
        // Solo actualizar el campo deletedBy
        await _firestore.collection('chats').doc(chatId).update({
          'deletedBy': deletedBy,
          'lastUpdate': FieldValue.serverTimestamp()
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat eliminado con éxito')),
      );
    } catch (e) {
      print('Error eliminando chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar chat: $e')),
      );
    }
  }

  Future<void> _loadRoomMembers() async {
    setState(() {
      _isLoadingMembers = true;
      _roomMembers = []; // Limpiar lista antes de cargar
    });

    try {
      // Obtener documento de la sala
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (!roomDoc.exists) {
        print('Error: La sala con ID ${widget.roomId} no existe');
        setState(() {
          _isLoadingMembers = false;
        });
        return;
      }

      // Obtener datos de la sala y lista de administradores
      final roomData = roomDoc.data() ?? {};
      final List<dynamic> adminsList = roomData['admins'] ?? [];
      final String creatorId = roomData['creatorUid'] ?? '';
      final String creatorPhoto = roomData['creatorPhoto'] ?? '';

      print('ID del creador: $creatorId, Foto del creador: ${creatorPhoto.isNotEmpty ? "existe" : "vacía"}');
      print('Admins encontrados: ${adminsList.length}');

      // Set para almacenar todos los IDs de admins (incluyendo usuario actual)
      final Set<String> adminIds = Set.from(
        adminsList.where((id) => id is String).cast<String>(),
      );

      // Procesar admins primero
      for (var adminId in adminIds) {
        if (adminId != widget.userId) {
          try {
            String adminName = 'Admin sin nombre';
            String photoUrl = '';

            // Verificar si el admin es el creador
            final bool isCreator = (adminId == creatorId);
            print('Procesando admin: $adminId (Es creador: $isCreator)');

            if (isCreator && creatorPhoto.isNotEmpty) {
              // Si es el creador, usar la foto del creador del documento de la sala
              photoUrl = creatorPhoto;
              print('Usando foto del creador para: $adminId');
            }

            // IMPORTANTE: Buscar siempre en los dos lugares, independientemente de si es creador
            // 1. Primero buscar en members con ID compuesto
            final String memberId = '${widget.roomId}_$adminId';
            print('Buscando admin en members: $memberId');

            final memberDoc = await FirebaseFirestore.instance
                .collection('members')
                .doc(memberId)
                .get();

            if (memberDoc.exists) {
              final memberData = memberDoc.data() ?? {};
              print('Datos encontrados en members: $memberData');

              // Intentar obtener foto de members
              if (photoUrl.isEmpty) {
                // Intentar todos los posibles campos de foto
                final photoFields = ['userPhoto', 'photoURL', 'photoUrl', 'profilePic', 'image'];
                for (var field in photoFields) {
                  if (memberData.containsKey(field) &&
                      memberData[field] != null &&
                      memberData[field].toString().isNotEmpty) {
                    photoUrl = memberData[field];
                    print('Foto encontrada en campo $field: $photoUrl');
                    break;
                  }
                }
              }

              // Obtener nombre
              adminName = memberData['userName'] ?? adminName;
            } else {
              print('No se encontró documento members para: $memberId');
            }

            // 2. Si la foto aún está vacía, buscar en users
// 2. Si la foto aún está vacía o el nombre es el default, buscar en users
            if (photoUrl.isEmpty || adminName == 'Admin sin nombre') {
              print('Intentando buscar en users: $adminId');
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(adminId)
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};

                // Intentar obtener nombre si no lo tenemos aún
                if (adminName == 'Admin sin nombre') {
                  adminName = userData['displayName'] ??
                      userData['username'] ??
                      userData['name'] ??
                      'Admin sin nombre';
                  print('Nombre encontrado en users: $adminName');
                }

                // Intentar todos los posibles campos de foto solo si aún no tenemos foto
                if (photoUrl.isEmpty) {
                  final photoFields = ['photoURL', 'photoUrl', 'profilePic', 'photo', 'image'];
                  for (var field in photoFields) {
                    if (userData.containsKey(field) &&
                        userData[field] != null &&
                        userData[field].toString().isNotEmpty) {
                      photoUrl = userData[field];
                      print('Foto encontrada en users campo $field: $photoUrl');
                      break;
                    }
                  }
                }
              }
            }

            print('Añadiendo admin con photoUrl: $photoUrl');
            _roomMembers.add({
              'id': adminId,
              'name': adminName,
              'photoUrl': photoUrl,
              'role': 'admin',
            });
          } catch (e) {
            print('Error al obtener información del admin $adminId: $e');
          }
        }
      }
      // Procesar miembros regulares...
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'active')
          .get();

      print('Regular members found: ${membersSnapshot.docs.length}');

      for (var memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        final String userId = memberData['userId'];

        // Skip if already added as admin
        if (_roomMembers.any((m) => m['id'] == userId)) {
          continue;
        }

        final String memberName = memberData['userName'] ?? 'Unnamed User';
        String photoUrl = '';

        // Check if member is creator
        if (userId == creatorId && creatorPhoto.isNotEmpty) {
          photoUrl = creatorPhoto;
          print('Using creator photo for member: $memberName');
        } else {
          photoUrl = memberData['userPhoto'] ?? '';
        }

        // Check if member is admin
        final String role = adminIds.contains(userId) ? 'admin' : 'member';

        _roomMembers.add({
          'id': userId,
          'name': memberName,
          'photoUrl': photoUrl,
          'role': role,
        });
      }

      // Add current user if admin but not found yet
      if (adminIds.contains(widget.userId) &&
          !_roomMembers.any((m) => m['id'] == widget.userId)) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final String userName = userData['displayName'] ??
              userData['username'] ??
              userData['name'] ??
              'You';

          // Determine photo URL based on creator status
          String photoUrl = '';
          if (widget.userId == creatorId && creatorPhoto.isNotEmpty) {
            photoUrl = creatorPhoto;
            print('Using creator photo for current user: $userName');
          } else {
            photoUrl = userData['photoURL'] ?? userData['photoUrl'] ?? '';
          }

          _roomMembers.add({
            'id': widget.userId,
            'name': userName,
            'photoUrl': photoUrl,
            'role': 'admin',
          });
        }
      }

      setState(() {
        _isLoadingMembers = false;
      });
    } catch (e) {
      print('Error loading members and admins: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading members: $e')),
      );
      setState(() {
        _isLoadingMembers = false;
      });
    }
  }

  void _showMembersDialog() {
    // Reload members before showing the dialog
    _loadRoomMembers().then((_) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.85),
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              // Separate admins and regular members
              final admins = _roomMembers.where((m) => m['role'] == 'admin').toList();
              final regularMembers = _roomMembers.where((m) => m['role'] != 'admin').toList();

              return Dialog(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900]?.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people_alt_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Miembros de la sala",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70),
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Members counter
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${_roomMembers.length} miembros en total",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Divider
                          Divider(
                            color: Colors.white.withOpacity(0.1),
                            height: 1,
                          ),

                          // Members List
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.6,
                              maxWidth: double.infinity,
                            ),
                            child: _isLoadingMembers
                                ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Cargando miembros...',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                : _roomMembers.isEmpty
                                ? _buildEmptyMembersList()
                                : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Admins section
                                  if (admins.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 12),
                                      child: Text(
                                        "Administradores",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ...admins.map((admin) => _buildMemberTile(admin, dialogContext)),

                                    // Divider between sections
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Divider(
                                        color: Colors.white.withOpacity(0.1),
                                        height: 1,
                                      ),
                                    ),
                                  ],

                                  // Regular members section
                                  if (regularMembers.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 12),
                                      child: Text(
                                        "Miembros",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ...regularMembers.map((member) => _buildMemberTile(member, dialogContext)),
                                  ],
                                ],
                              ),
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
    });
  }

  Widget _buildMemberTile(Map<String, dynamic> member, BuildContext dialogContext) {
    final bool isAdmin = member['role'] == 'admin';
    final String memberName = member['name'] ?? 'Usuario sin nombre';
    final String memberId = member['id'] ?? '';
    final String memberPhoto = member['photoUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(
          color: isAdmin
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pop(dialogContext);
            _startChatWithMember(member);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with effects for admins
                Stack(
                  children: [
                    Container(
                      padding: isAdmin ? const EdgeInsets.all(2) : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isAdmin
                            ? Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[900],
                        backgroundImage: memberPhoto.isNotEmpty
                            ? CachedNetworkImageProvider(memberPhoto)
                            : null,
                        child: memberPhoto.isEmpty
                            ? Text(
                          memberName.isNotEmpty
                              ? memberName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                            : null,
                      ),
                    ),
                    if (isAdmin)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isAdmin ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAdmin ? 'Administrador' : 'Miembro',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chat button
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMembersList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade900.withOpacity(0.4),
                    Colors.purple.shade900.withOpacity(0.4),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.group_off_rounded,
                size: 48,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay miembros disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Invita miembros a esta sala para poder iniciar conversaciones',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Implement functionality to invite members
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Invitar miembros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _startChatWithMember(Map<String, dynamic> member) async {
    final String memberId = member['id'] ?? '';
    final String memberName = member['name'] ?? 'Usuario';
    final String memberPhoto = member['photoUrl'] ?? '';

    setState(() {
      isLoading = true;
    });

    try {
      // Obtener información del usuario actual de manera más robusta
      String currentUserName = '';
      String currentUserPhoto = '';

      // Primero intentar obtener los datos de _roomMembers si el usuario está ahí
      final currentMember = _roomMembers.firstWhere(
            (m) => m['id'] == widget.userId,
        orElse: () => {},
      );

      if (currentMember.isNotEmpty) {
        currentUserName = currentMember['name'] ?? '';
        currentUserPhoto = currentMember['photoUrl'] ?? '';
      }

      // Si no se encontró en _roomMembers, buscar en users
      if (currentUserName.isEmpty) {
        final currentUserDoc = await _firestore.collection('users').doc(widget.userId).get();
        final currentUserData = currentUserDoc.data() ?? {};
        currentUserName = currentUserData['displayName'] ??
            currentUserData['username'] ??
            currentUserData['name'] ?? 'Usuario';
        currentUserPhoto = currentUserData['photoURL'] ??
            currentUserData['photoUrl'] ??
            currentUserData['profilePic'] ?? '';
      }

      // Find all possible chats between these users (including deleted ones)
      final existingChatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.userId)
          .where('roomId', isEqualTo: widget.roomId)
          .get();

      String chatId = '';
      bool needToRestore = false;

      // Check all existing chats
      for (var doc in existingChatQuery.docs) {
        List<String> participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(memberId)) {
          // Chat exists, check if it was deleted
          List<String> deletedBy = [];
          if (doc.data().containsKey('deletedBy') && doc.data()['deletedBy'] is List) {
            deletedBy = List<String>.from(doc.data()['deletedBy']);
          }

          if (deletedBy.contains(widget.userId)) {
            // This chat was deleted by current user, but we can restore it
            chatId = doc.id;
            needToRestore = true;
          } else if (!doc.data().containsKey('fullyDeleted') || doc.data()['fullyDeleted'] != true) {
            // Active chat found
            chatId = doc.id;
          }
          break;
        }
      }

      if (chatId.isNotEmpty && needToRestore) {
        await _firestore.collection('chats').doc(chatId).update({
          'deletedBy': FieldValue.arrayRemove([widget.userId]),
          'fullyDeleted': false,
          'lastUpdate': FieldValue.serverTimestamp(),
          'participantInfo': {
            widget.userId: {
              'name': currentUserName,
              'photo': currentUserPhoto,
            },
            memberId: {
              'name': memberName,
              'photo': memberPhoto,
            }
          }
        });
        print('Restored and updated chat info: $chatId');
      } else if (chatId.isEmpty) {
        // Crear nuevo chat con información completa de participantes
        final newChatRef = _firestore.collection('chats').doc();
        await newChatRef.set({
          'participants': [widget.userId, memberId],
          'roomId': widget.roomId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdate': FieldValue.serverTimestamp(),
          'participantInfo': {
            widget.userId: {
              'name': currentUserName,
              'photo': currentUserPhoto,
            },
            memberId: {
              'name': memberName,
              'photo': memberPhoto,
            }
          }
        });
        chatId = newChatRef.id;
        print('Created new chat with complete participant info: $chatId');
      }

      setState(() {
        isLoading = false;
      });

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: memberId,
            otherUserName: memberName,
            otherUserPhoto: memberPhoto,
            currentUserId: widget.userId,
          ),
        ),
      ).then((_) => _loadChats());
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar el chat: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }
}