// lib/rooms/fitness/screens/chat_detail_screen.dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final String currentUserId;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}
class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _isTyping = false;
  bool isLoading = false; // Add this line
  String _typingText = "";
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final uuid = Uuid();

  final Color _pureBlack = Colors.black;
  final Color _pureWhite = Colors.white;
  final Color _darkGrey = Color(0xFF1C1C1E);
  final Color _mediumGrey = Color(0xFF2C2C2E);
  final Color _lightGrey = Color(0xFF3A3A3C);

  @override
  void initState() {
    super.initState();
    _updateChatParticipantInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pureBlack,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _pureBlack,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserPhoto)
                  : null,
              backgroundColor: _mediumGrey,
              child: widget.otherUserPhoto.isEmpty
                  ? Text(
                widget.otherUserName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _pureWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: TextStyle(
                    color: _pureWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_isTyping)
                  Text(
                    _typingText,
                    style: TextStyle(
                      color: _pureWhite.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: _pureWhite.withOpacity(0.8), size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función no implementada')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: _pureWhite.withOpacity(0.8), size: 22),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtle divider
          Container(height: 1, color: _pureWhite.withOpacity(0.05)),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _pureWhite.withOpacity(0.6),
                          )
                      )
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar los mensajes',
                      style: TextStyle(color: _pureWhite.withOpacity(0.5)),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: _pureWhite.withOpacity(0.12),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Envía el primer mensaje',
                          style: TextStyle(
                            color: _pureWhite.withOpacity(0.4),
                            fontSize: 16,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final messageId = messages[index].id;
                    final isMe = message['senderId'] == widget.currentUserId;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final dateTime = timestamp?.toDate() ?? DateTime.now();

                    // Check if this message shows date header
                    bool showDateHeader = false;
                    if (index == messages.length - 1) {
                      showDateHeader = true;
                    } else {
                      final nextMessage = messages[index + 1].data() as Map<String, dynamic>;
                      final nextTimestamp = nextMessage['timestamp'] as Timestamp?;
                      final nextDateTime = nextTimestamp?.toDate() ?? DateTime.now();

                      if (dateTime.day != nextDateTime.day ||
                          dateTime.month != nextDateTime.month ||
                          dateTime.year != nextDateTime.year) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateHeader) _buildDateHeader(dateTime),
                        _buildMessage(message, messageId, isMe, dateTime),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    String headerText;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      headerText = 'Hoy';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      headerText = 'Ayer';
    } else {
      headerText = DateFormat('d MMM, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _pureWhite.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pureWhite.withOpacity(0.07),
              width: 0.5,
            ),
          ),
          child: Text(
            headerText,
            style: TextStyle(
              color: _pureWhite.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateChatParticipantInfo() async {
    try {
      // Primero obtener los datos actuales del chat
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();

      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() ?? {};
      Map<String, dynamic> participantInfo = chatData['participantInfo'] ?? {};

      // Verificar si tenemos la información del usuario actual
      bool needsUpdate = false;

      // Si no tenemos información del usuario actual o está incompleta
      if (!participantInfo.containsKey(widget.currentUserId) ||
          participantInfo[widget.currentUserId]['name'] == null ||
          participantInfo[widget.currentUserId]['photo'] == null) {

        // Obtener información actual del usuario
        final userDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final userName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
          final userPhoto = userData['photoURL'] ?? userData['photoUrl'] ?? '';

          // Actualizar el mapa de participantInfo
          participantInfo[widget.currentUserId] = {
            'name': userName,
            'photo': userPhoto,
          };

          needsUpdate = true;
        }
      }

      // Si no tenemos información del otro usuario o está incompleta
      if (!participantInfo.containsKey(widget.otherUserId) ||
          participantInfo[widget.otherUserId]['name'] == null ||
          participantInfo[widget.otherUserId]['photo'] == null) {

        // Obtener información del otro usuario
        final userDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final userName = userData['displayName'] ?? userData['username'] ?? 'Usuario';
          final userPhoto = userData['photoURL'] ?? userData['photoUrl'] ?? '';

          // Actualizar el mapa de participantInfo
          participantInfo[widget.otherUserId] = {
            'name': userName,
            'photo': userPhoto,
          };

          needsUpdate = true;
        }
      }

      // Actualizar el documento si es necesario
      if (needsUpdate) {
        await _firestore.collection('chats').doc(widget.chatId).update({
          'participantInfo': participantInfo,
        });
        print('Información de participantes actualizada en el chat ${widget.chatId}');
      }
    } catch (e) {
      print('Error al actualizar información de participantes: $e');
    }
  }

  Widget _buildMessage(Map<String, dynamic> message, String messageId, bool isMe, DateTime timestamp) {
    final String messageType = message['messageType'] ?? 'text';
    final time = DateFormat('HH:mm').format(timestamp);
    final isRead = message['read'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: widget.otherUserPhoto.isNotEmpty
                    ? DecorationImage(
                  image: CachedNetworkImageProvider(widget.otherUserPhoto),
                  fit: BoxFit.cover,
                )
                    : null,
                color: _mediumGrey,
                border: Border.all(
                  color: _pureWhite.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: widget.otherUserPhoto.isEmpty
                  ? Center(
                  child: Text(
                    widget.otherUserName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: _pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ))
                  : null,
            ),
          ],

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: messageType == 'text'
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? _pureWhite : _mediumGrey,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : null,
                  bottomLeft: isMe ? null : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _pureBlack.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (messageType == 'text')
                    Text(
                      message['text'] ?? '',
                      style: TextStyle(
                        color: isMe ? _pureBlack : _pureWhite.withOpacity(0.95),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    )
                  else if (messageType == 'image')
                    _buildImageMessage(message, isMe)
                  else if (messageType == 'document')
                      _buildDocumentMessage(message, isMe)
                    else if (messageType == 'location')
                        _buildLocationMessage(message, isMe),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe
                              ? _pureBlack.withOpacity(0.5)
                              : _pureWhite.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead
                              ? _pureBlack.withOpacity(0.7)
                              : _pureBlack.withOpacity(0.4),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message, bool isMe) {
    final String imageUrl = message['mediaUrl'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => Container(
              height: 200,
              color: _pureBlack.withOpacity(0.1),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isMe ? _pureBlack.withOpacity(0.3) : _pureWhite.withOpacity(0.3),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 100,
              color: _pureBlack.withOpacity(0.1),
              child: Icon(
                Icons.error_outline,
                color: isMe ? _pureBlack.withOpacity(0.3) : _pureWhite.withOpacity(0.3),
              ),
            ),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentMessage(Map<String, dynamic> message, bool isMe) {
    final String fileName = message['fileName'] ?? 'Documento';
    final int fileSize = message['fileSize'] ?? 0;
    final String fileExt = message['fileExt'] ?? '';
    final String formattedSize = _formatFileSize(fileSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMe ? _pureBlack.withOpacity(0.05) : _pureWhite.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(fileExt),
              color: isMe ? _pureBlack.withOpacity(0.7) : _pureWhite.withOpacity(0.7),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: isMe ? _pureBlack : _pureWhite.withOpacity(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedSize,
                  style: TextStyle(
                    color: isMe ? _pureBlack.withOpacity(0.5) : _pureWhite.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: isMe ? _pureBlack.withOpacity(0.7) : _pureWhite.withOpacity(0.7),
              size: 20,
            ),
            onPressed: () {
              // Implementar descarga de archivo
              _downloadFile(message['mediaUrl'], fileName);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage(Map<String, dynamic> message, bool isMe) {
    final double latitude = message['latitude'] ?? 0.0;
    final double longitude = message['longitude'] ?? 0.0;
    final String address = message['address'] ?? 'Ubicación compartida';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isMe ? _pureBlack.withOpacity(0.05) : _pureWhite.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.map,
                    size: 60,
                    color: isMe ? _pureBlack.withOpacity(0.1) : _pureWhite.withOpacity(0.1),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.location_on,
                    size: 32,
                    color: Colors.red.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: isMe ? _pureBlack.withOpacity(0.6) : _pureWhite.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: isMe ? _pureBlack.withOpacity(0.8) : _pureWhite.withOpacity(0.8),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openMap(latitude, longitude),
            child: Text(
              'Abrir en Maps',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _downloadFile(String url, String fileName) {
    // Esta es una implementación simulada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando $fileName...')),
    );
    // Para implementar la descarga real, se necesitaría usar
    // paquetes como dio o http para descargar y path_provider para guardar
  }

  void _openMap(double latitude, double longitude) {
    final Uri uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _darkGrey,
        boxShadow: [
          BoxShadow(
            color: _pureBlack,
            blurRadius: 8,
            offset: const Offset(0, -1),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            icon: Icon(
              Icons.add_circle_outline,
              color: _pureWhite.withOpacity(0.5),
              size: 24,
            ),
            onPressed: () {
              _showAttachmentOptions();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _mediumGrey,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _pureWhite.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: _pureWhite),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(
                    color: _pureWhite.withOpacity(0.3),
                    fontWeight: FontWeight.w300,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                minLines: 1,
                maxLines: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isComposing
                  ? _pureWhite
                  : _mediumGrey,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isComposing
                    ? Colors.transparent
                    : _pureWhite.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isComposing
                  ? Icon(Icons.send_rounded, color: _pureBlack, size: 20)
                  : Icon(Icons.mic_rounded, color: _pureWhite.withOpacity(0.5), size: 22),
              onPressed: _isComposing ? _sendMessage : _startVoiceRecording,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Compartir',
                  style: TextStyle(
                    color: _pureWhite,
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galería',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Cámara',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.location_on_rounded,
                    label: 'Ubicación',
                    onTap: () {
                      Navigator.pop(context);
                      _shareLocation();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedImage == null) return;

      setState(() {
        isLoading = true;
      });

      // Subir la imagen a Firebase Storage
      final String fileName = uuid.v4();
      final Reference storageRef = _storage
          .ref()
          .child('chats/${widget.chatId}/images/$fileName.jpg');

      final File imageFile = File(pickedImage.path);
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Guardar mensaje con imagen en Firestore
      await _sendMediaMessage(downloadUrl, 'image');

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error al enviar imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar imagen: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _shareLocation() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los permisos de ubicación están permanentemente denegados'),
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Obtener ubicación actual
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Obtener dirección de la ubicación (opcional)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Ubicación desconocida';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        address = '${place.street}, ${place.locality}, ${place.country}';
      }

      // Guardar mensaje con ubicación en Firestore
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'messageType': 'location',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Actualizar último mensaje
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': '📍 Ubicación compartida',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentUserId,
      });

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error al compartir ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir ubicación: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendMediaMessage(String url, String type, {Map<String, dynamic>? additionalData}) async {
    try {
      final Map<String, dynamic> messageData = {
        'senderId': widget.currentUserId,
        'messageType': type,
        'mediaUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      // Añadir datos adicionales si existen
      if (additionalData != null) {
        messageData.addAll(additionalData);
      }

      // Añadir mensaje a Firestore
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      // Actualizar último mensaje
      String lastMessageText = '';
      if (type == 'image') {
        lastMessageText = '📷 Imagen';
      } else if (type == 'document') {
        lastMessageText = '📄 Documento';
      }

      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentUserId,
      });
    } catch (e) {
      print('Error enviando mensaje multimedia: $e');
      throw e;
    }
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _lightGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pureWhite.withOpacity(0.05),
                width: 0.5,
              ),
            ),
            child: Icon(
              icon,
              color: _pureWhite,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: _pureWhite.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _pureWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildOptionTile(
                icon: Icons.person_outline_rounded,
                title: 'Ver perfil',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ver perfil no implementado')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.notifications_off_outlined,
                title: 'Silenciar notificaciones',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Función no implementada')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.image_outlined,
                title: 'Archivos multimedia',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Función no implementada')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.search,
                title: 'Buscar',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Función no implementada')),
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Eliminar chat',
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat();
                },
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : _lightGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : _pureWhite,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : _pureWhite,
          fontWeight: isDestructive ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _deleteChat() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      // Obtener el documento del chat actual
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      final chatData = chatDoc.data() ?? {};

      // Obtener o inicializar el array deletedBy
      List<String> deletedBy = [];
      if (chatData.containsKey('deletedBy') && chatData['deletedBy'] is List) {
        deletedBy = List<String>.from(chatData['deletedBy']);
      }

      // Añadir al usuario actual al array si no está ya
      if (!deletedBy.contains(widget.currentUserId)) {
        deletedBy.add(widget.currentUserId);
      }

      // Obtener la lista de participantes
      final List<String> participants = List<String>.from(chatData['participants'] ?? []);

      // Si todos los participantes han eliminado el chat, marcarlo como completamente eliminado
      if (deletedBy.length >= participants.length) {
        // Eliminar mensajes (subcolección) - esto está permitido
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .get();

        // Crear batch para operaciones múltiples
        final batch = _firestore.batch();

        // Añadir eliminación de mensajes al batch
        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // En lugar de eliminar el chat, marcarlo como completamente eliminado
        await _firestore.collection('chats').doc(widget.chatId).update({
          'deletedBy': deletedBy,
          'fullyDeleted': true,
          'lastUpdate': FieldValue.serverTimestamp()
        });

        // Ejecutar el batch para eliminar los mensajes
        await batch.commit();
      } else {
        // Solo actualizar el campo deletedBy
        await _firestore.collection('chats').doc(widget.chatId).update({
          'deletedBy': deletedBy,
          'lastUpdate': FieldValue.serverTimestamp()
        });
      }

      // Cerrar diálogo de carga
      Navigator.pop(context);

      // Mostrar confirmación y volver a la lista
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat eliminado con éxito')),
      );

      // Volver a la pantalla anterior
      Navigator.pop(context);
    } catch (e) {
      // Cerrar diálogo de carga en caso de error
      Navigator.pop(context);

      print('Error eliminando chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar chat: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isComposing = false;
    });

    try {
      // Add the message to Firestore
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update last message in chat
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentUserId,
      });

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar el mensaje')),
      );
    }
  }

  void _startVoiceRecording() {
    // Placeholder for voice recording functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de grabación de voz no implementada')),
    );
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar chat?',
          style: TextStyle(color: _pureWhite, fontWeight: FontWeight.w500),
        ),
        content: Text(
          'Esta acción no se puede deshacer y eliminará todos los mensajes.',
          style: TextStyle(color: _pureWhite.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: _pureWhite.withOpacity(0.7)),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}