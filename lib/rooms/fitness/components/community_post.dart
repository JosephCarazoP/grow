import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:grow/screens/user_profile_page.dart';
import 'package:grow/rooms/fitness/screens/post_detail_page.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../screens/video_player_screen.dart';

class CommunityPost extends StatefulWidget {
  final String postId;
  final String roomId;
  final bool showFullContent;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onLikeRemoved;
  final bool autoShowComments;

  const CommunityPost({
    Key? key,
    required this.postId,
    required this.roomId,
    this.showFullContent = true,
    this.autoShowComments = false,
    this.onLikeRemoved,
    this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommunityPost> createState() => _CommunityPostState();
}

class _CommunityPostState extends State<CommunityPost> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  bool _isLiked = false;
  bool _isLoading = true;
  bool _isLoadingComments = false;
  bool _showComments = false;
  Map<String, dynamic>? _postData;
  List<Map<String, dynamic>> _comments = [];
  String? _replyToComment;
  String? _replyToUser;
  String? _activeReplyCommentId;

  @override
  @override
  @override
  void initState() {
    super.initState();
    _loadPostData();

    if (widget.autoShowComments) {
      _showComments = true;
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _loadComments();
        }
      });
    }
  }

  Future<void> _loadPostData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load post data from main posts collection
      final postDoc =
          await _firestore.collection('posts').doc(widget.postId).get();

      if (!postDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final postData = postDoc.data()!;
      final String currentUserId = _auth.currentUser?.uid ?? '';

      // Check if current user has liked this post
      final bool isLiked =
          (postData['likedBy'] as List<dynamic>?)?.contains(currentUserId) ??
          false;

      setState(() {
        _postData = postData;
        _isLiked = isLiked;
        _isLoading = false;
      });

      // Cargar comentarios automáticamente si autoShowComments es true
      if (widget.autoShowComments) {
        _loadComments();
      }
    } catch (e) {
      print('Error loading post data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      print('Cargando comentarios para postId: ${widget.postId}');

      final commentsSnapshot =
          await _firestore
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .orderBy('createdAt', descending: true)
              .get();

      print('Comentarios encontrados: ${commentsSnapshot.docs.length}');

      // Map para almacenar todos los comentarios por su ID
      Map<String, Map<String, dynamic>> commentsMap = {};
      // Lista para los comentarios principales
      List<Map<String, dynamic>> mainComments = [];

      // Primer paso: procesar todos los comentarios
      for (var doc in commentsSnapshot.docs) {
        final commentData = doc.data();
        final String userId = commentData['userId'] ?? '';
        final dynamic parentCommentId = commentData['parentCommentId'];

        // Obtener datos del usuario
        DocumentSnapshot? userDoc;
        try {
          userDoc = await _firestore.collection('users').doc(userId).get();
        } catch (e) {
          print('Error fetching user data for comment: $e');
        }

        String userName = 'Usuario';
        String userPhoto = '';

        if (userDoc != null && userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          userName = userData?['name'] ?? 'Usuario';
          userPhoto = userData?['photo'] ?? '';
        }

        // Crear objeto de comentario enriquecido
        final commentObject = {
          'id': doc.id,
          'userId': userId,
          'text': commentData['text'] ?? '',
          'createdAt': commentData['createdAt'],
          'likesCount': commentData['likesCount'] ?? 0,
          'likedBy': commentData['likedBy'] ?? [],
          'userName': userName,
          'userPhoto': userPhoto,
          'parentCommentId': parentCommentId,
          'replyTo': commentData['replyTo'],
          'replies': <Map<String, dynamic>>[],
        };

        // Guardar en el mapa por ID
        commentsMap[doc.id] = commentObject;

        // Si es un comentario principal (sin parentCommentId), añadirlo a la lista principal
        if (parentCommentId == null) {
          mainComments.add(commentObject);
        }
      }

      // Segundo paso: organizar respuestas bajo sus comentarios principales
      for (var commentId in commentsMap.keys) {
        final comment = commentsMap[commentId]!;
        final parentId = comment['parentCommentId'];

        // Si tiene un padre, añadirlo como respuesta
        if (parentId != null && commentsMap.containsKey(parentId)) {
          commentsMap[parentId]!['replies'].add(comment);
        }
      }

      // Ordenar comentarios principales por fecha
      mainComments.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Más recientes primero
      });

      print(
        'Total comentarios principales organizados: ${mainComments.length}',
      );

      if (mounted) {
        setState(() {
          _comments = mainComments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para dar like')),
      );
      return;
    }

    final String currentUserId = _auth.currentUser!.uid;
    final DocumentReference postRef = _firestore
        .collection('posts')
        .doc(widget.postId);

    try {
      // Crear referencia al documento de like
      final likeRef = _firestore
          .collection('likes')
          .doc('${widget.postId}_$currentUserId');

      final likeDoc = await likeRef.get();

      if (_isLiked) {
        // Eliminar like
        if (likeDoc.exists) {
          await likeRef.delete();
        }

        // Actualizar contador en el post
        await postRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });

        setState(() {
          _isLiked = false;
          if (_postData != null) {
            _postData!['likesCount'] = (_postData!['likesCount'] ?? 1) - 1;
            final likedBy = _postData!['likedBy'] as List<dynamic>? ?? [];
            _postData!['likedBy'] =
                likedBy.where((id) => id != currentUserId).toList();
          }
        });

        // Llamar al callback cuando se quita el like
        if (widget.onLikeRemoved != null) {
          widget.onLikeRemoved!();
        }
      } else {
        // Agregar like
        await likeRef.set({
          'postId': widget.postId,
          'userId': currentUserId,
          'roomId': widget.roomId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Actualizar contador en el post
        await postRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });

        setState(() {
          _isLiked = true;
          if (_postData != null) {
            _postData!['likesCount'] = (_postData!['likesCount'] ?? 0) + 1;
            final likedBy = List<dynamic>.from(
              _postData!['likedBy'] as List<dynamic>? ?? [],
            );
            if (!likedBy.contains(currentUserId)) {
              likedBy.add(currentUserId);
              _postData!['likedBy'] = likedBy;
            }
          }
        });
      }
    } catch (e) {
      print('Error al actualizar like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el like')),
      );
    }
  }

  Future<void> _toggleCommentLike(String commentId, bool isLiked) async {
    if (_auth.currentUser == null) return;

    final String currentUserId = _auth.currentUser!.uid;
    final DocumentReference commentRef = _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    try {
      if (isLiked) {
        // Quitar like
        await commentRef.update({
          'likesCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });

        // Actualizar estado local
        setState(() {
          for (var i = 0; i < _comments.length; i++) {
            if (_comments[i]['id'] == commentId) {
              _comments[i]['likesCount'] =
                  (_comments[i]['likesCount'] ?? 1) - 1;
              List<dynamic> likedBy = List.from(_comments[i]['likedBy'] ?? []);
              likedBy.remove(currentUserId);
              _comments[i]['likedBy'] = likedBy;
              break;
            }

            // Buscar en respuestas
            final replies =
                _comments[i]['replies'] as List<Map<String, dynamic>>;
            for (var j = 0; j < replies.length; j++) {
              if (replies[j]['id'] == commentId) {
                replies[j]['likesCount'] = (replies[j]['likesCount'] ?? 1) - 1;
                List<dynamic> replyLikedBy = List.from(
                  replies[j]['likedBy'] ?? [],
                );
                replyLikedBy.remove(currentUserId);
                replies[j]['likedBy'] = replyLikedBy;
                break;
              }
            }
          }
        });
      } else {
        // Agregar like
        await commentRef.update({
          'likesCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });

        // Actualizar estado local
        setState(() {
          bool found = false;
          for (var i = 0; i < _comments.length; i++) {
            if (_comments[i]['id'] == commentId) {
              _comments[i]['likesCount'] =
                  (_comments[i]['likesCount'] ?? 0) + 1;
              List<dynamic> likedBy = List.from(_comments[i]['likedBy'] ?? []);
              if (!likedBy.contains(currentUserId)) {
                likedBy.add(currentUserId);
              }
              _comments[i]['likedBy'] = likedBy;
              found = true;
              break;
            }

            // Buscar en respuestas
            if (!found) {
              final replies =
                  _comments[i]['replies'] as List<Map<String, dynamic>>;
              for (var j = 0; j < replies.length; j++) {
                if (replies[j]['id'] == commentId) {
                  replies[j]['likesCount'] =
                      (replies[j]['likesCount'] ?? 0) + 1;
                  List<dynamic> replyLikedBy = List.from(
                    replies[j]['likedBy'] ?? [],
                  );
                  if (!replyLikedBy.contains(currentUserId)) {
                    replyLikedBy.add(currentUserId);
                  }
                  replies[j]['likedBy'] = replyLikedBy;
                  found = true;
                  break;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error toggling comment like: $e');
    }
  }

  Future<void> _addComment() async {
    final String text = _commentController.text.trim();
    if (text.isEmpty || _auth.currentUser == null) return;

    final String currentUserId = _auth.currentUser!.uid;

    try {
      // Si es una respuesta a un comentario
      if (_replyToComment != null && _replyToUser != null) {
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
              'userId': currentUserId,
              'text': text,
              'createdAt': FieldValue.serverTimestamp(),
              'likesCount': 0,
              'likedBy': [],
              'parentCommentId': _replyToComment,
              'replyTo': _replyToUser,
            });

        // Resetear variables de respuesta
        _replyToComment = null;
        _replyToUser = null;
      } else {
        // Si es un comentario principal
        await _firestore
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
              'userId': currentUserId,
              'text': text,
              'createdAt': FieldValue.serverTimestamp(),
              'likesCount': 0,
              'likedBy': [],
              'parentCommentId': null,
            });
      }

      _commentController.clear();

      // Recargar comentarios y actualizar contadores
      await _loadComments();

      // Actualizar contador de comentarios en el post
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      if (widget.onCommentAdded != null) {
        widget.onCommentAdded!();
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
    }
  }

  Future<void> _addReply(
    String parentCommentId,
    String replyTo,
    String text,
  ) async {
    if (text.isEmpty || _auth.currentUser == null) return;

    final String currentUserId = _auth.currentUser!.uid;

    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'userId': currentUserId,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
            'likesCount': 0,
            'likedBy': [],
            'parentCommentId': parentCommentId,
            'replyTo': replyTo,
          });

      // Reload comments
      await _loadComments();

      // Update post comment count in the top-level posts collection
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      if (widget.onCommentAdded != null) {
        widget.onCommentAdded!();
      }
    } catch (e) {
      print('Error adding reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar la respuesta: $e')),
      );
    }
  }

  void _showUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfilePage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_postData == null) {
      return const SizedBox.shrink();
    }

    // Si estamos en la vista detallada (autoShowComments), no añadimos navegación
    if (widget.autoShowComments) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            _buildPostContent(),
            _buildInteractionBar(),
            if (_showComments) _buildCommentSection(),
          ],
        ),
      );
    }

    // Si estamos en el feed, añadimos navegación al contenedor
    return GestureDetector(
      onTap: () => _navigateToPostDetail(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            _buildPostContent(),
            _buildInteractionBar(),
            if (_showComments) _buildCommentSection(),
          ],
        ),
      ),
    );
  }

  // Función para navegar al detalle del post
  void _navigateToPostDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PostDetailPage(
              postId: widget.postId,
              roomId: widget.roomId,
              onLikeRemoved: widget.onLikeRemoved,
            ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerLoading(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(
                    child: Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShimmerLoading(
                    child: Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerLoading(
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    final userData = _postData?['userData'] ?? {};
    final timestamp = _postData?['createdAt'] as Timestamp?;
    final String timeAgo =
        timestamp != null
            ? timeago.format(timestamp.toDate(), locale: 'es')
            : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showUserProfile(_postData?['userId']),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade700,
              backgroundImage:
                  userData['photo'] != null
                      ? CachedNetworkImageProvider(userData['photo'])
                      : null,
              child:
                  userData['photo'] == null
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showUserProfile(_postData?['userId']),
                  child: Text(
                    userData['name'] ?? 'Usuario',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.7)),
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: Colors.orange[300],
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Reportar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (_postData?['userId'] == _auth.currentUser?.uid)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                ],
              onSelected: (value) async {
                if (value == 'delete') {
                  await _deletePost();
                } else if (value == 'report') {
                  // Implement report functionality
                }
              },
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    // Mostrar diálogo de confirmación
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Eliminar publicación',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro que deseas eliminar esta publicación? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.blue.shade300),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Eliminar el post
      await _firestore.collection('posts').doc(widget.postId).delete();

      // Eliminar todos los comentarios del post
      final commentsSnapshot = await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();

      for (var doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Eliminar todos los likes del post
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('postId', isEqualTo: widget.postId)
          .get();

      for (var doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Eliminar todos los reposts de este post
      final repostsSnapshot = await _firestore
          .collection('reposts')
          .where('originalPostId', isEqualTo: widget.postId)
          .get();

      for (var doc in repostsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publicación eliminada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la pantalla anterior si es necesario
      if (widget.autoShowComments) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      print('Error al eliminar post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar la publicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMediaGrid(List<Map<String, dynamic>> allMedia) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: allMedia.length > 4 ? 3 : 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount:
            allMedia.length > 6
                ? 6
                : allMedia.length, // Limitar a 6 elementos visibles
        itemBuilder: (context, index) {
          // Si es el último elemento y hay más elementos no mostrados
          if (index == 5 && allMedia.length > 6) {
            return Stack(
              children: [
                _buildSingleMediaItem(allMedia[index]),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+${allMedia.length - 6}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }
          return _buildSingleMediaItem(allMedia[index]);
        },
      ),
    );
  }

  Widget _buildPostContent() {
    final String content = _postData?['content'] ?? '';
    final List<dynamic>? imageUrls = _postData?['imageUrls'] ?? [];
    final List<dynamic>? videoData = _postData?['videoData'] ?? [];
    final bool isRepost = _postData?['isRepost'] ?? false;

    // If it's a repost, show special UI
    if (isRepost && _postData?['originalPostData'] != null) {
      final originalData = _postData!['originalPostData'];
      final originalUserData = originalData['userData'] ?? {};
      final originalPostId = originalData['id'] ?? '';
      final String originalRoomId = originalData['roomId'] ?? widget.roomId;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Additional repost content if any
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

          // Original post container with enhanced design
          GestureDetector(
            onTap: () {
              final originalPostId = _postData?['originalPostId'];
              if (originalPostId != null && originalPostId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PostDetailPage(
                          postId: originalPostId,
                          roomId: widget.roomId,
                        ),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade800.withOpacity(0.8),
                    Colors.black.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Content area
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Original post header with better spacing and alignment
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      originalUserData['photo'] != null
                                          ? CachedNetworkImageProvider(
                                            originalUserData['photo'],
                                          )
                                          : null,
                                  backgroundColor: Colors.grey[850],
                                  child:
                                      originalUserData['photo'] == null
                                          ? const Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                            size: 18,
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      originalUserData['name'] ?? 'Usuario',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (originalData['createdAt'] != null)
                                      Text(
                                        _getTimeAgo(originalData['createdAt']),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Original post content with better typography
                          if (originalData['content']?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                originalData['content'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  height: 1.4,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),

                          // Media from original post
                          if ((originalData['imageUrls']?.isNotEmpty == true) ||
                              (originalData['videoData']?.isNotEmpty == true))
                            _buildMediaGallery(
                              originalData['imageUrls'] ?? [],
                              originalData['videoData'] ?? [],
                            ),
                        ],
                      ),
                    ),

                    // Subtle visual indicator for clickable post
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // For normal posts (not reposts)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post content with improved typography
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
          ),

        // Media gallery
        if ((imageUrls != null && imageUrls.isNotEmpty) ||
            (videoData != null && videoData.isNotEmpty))
          _buildMediaGallery(imageUrls!, videoData!),
      ],
    );
  }

  // Helper method to format time ago
  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Hace un momento';

    if (timestamp is Timestamp) {
      final now = DateTime.now();
      final date = timestamp.toDate();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return 'Hace ${(difference.inDays / 365).floor()} año(s)';
      } else if (difference.inDays > 30) {
        return 'Hace ${(difference.inDays / 30).floor()} mes(es)';
      } else if (difference.inDays > 0) {
        return 'Hace ${difference.inDays} día(s)';
      } else if (difference.inHours > 0) {
        return 'Hace ${difference.inHours} hora(s)';
      } else if (difference.inMinutes > 0) {
        return 'Hace ${difference.inMinutes} minuto(s)';
      } else {
        return 'Hace un momento';
      }
    }

    return 'Hace un momento';
  }

  Widget _buildMediaGallery(List<dynamic> imageUrls, List<dynamic> videoData) {
    // Combinar todos los archivos multimedia para mostrarlos
    List<Map<String, dynamic>> allMedia = [];

    // Añadir imágenes
    for (String url in imageUrls) {
      allMedia.add({'type': 'image', 'url': url});
    }

    // Añadir videos
    for (var video in videoData) {
      allMedia.add({
        'type': 'video',
        'videoId': video['videoId'],
        'thumbnailUrl': video['thumbnailUrl'],
        'url': video['url'],
      });
    }

    // Si hay un solo archivo multimedia
    if (allMedia.length == 1) {
      return _buildSingleMediaItem(allMedia[0]);
    }

    // Si hay múltiples archivos, mostrar un grid
    return _buildMediaGrid(allMedia);
  }

  Widget _buildSingleMediaItem(Map<String, dynamic> mediaItem) {
    if (mediaItem['type'] == 'image') {
      return _buildSingleImage(mediaItem['url']);
    } else {
      return _buildSingleVideo(
        mediaItem['videoId'],
        mediaItem['thumbnailUrl'],
        mediaItem['url'],
      );
    }
  }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Implementar vista de imagen a pantalla completa si lo deseas
        // Por ejemplo, abrir un diálogo o navegar a una pantalla de visualización
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder:
              (context, url) => Container(
                color: Colors.grey.shade900,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.7),
                    ),
                    strokeWidth: 2,
                  ),
                ),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey.shade900,
                child: const Icon(Icons.error, color: Colors.red),
              ),
        ),
      ),
    );
  }

  Widget _buildSingleVideo(String videoId, String thumbnailUrl, String url) {
    return GestureDetector(
      onTap: () {
        // Navegar a la pantalla de reproducción de video
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoId: videoId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Miniatura del video
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder:
                  (context, url) => Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
            ),

            // Overlay con ícono de reproducción
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.7, 1.0],
                ),
              ),
            ),

            // Ícono de reproducción y duración
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

            // Indicador de YouTube
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> _repostContent() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para repostear')),
      );
      return;
    }

    final String currentUserId = _auth.currentUser!.uid;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Primero comprobamos si el usuario ya ha reposteado este contenido
      final existingReposts =
          await _firestore
              .collection('reposts')
              .where('originalPostId', isEqualTo: widget.postId)
              .where('userId', isEqualTo: currentUserId)
              .limit(1)
              .get();

      if (existingReposts.docs.isNotEmpty) {
        // Si ya existe un repost, cerramos el diálogo de carga
        Navigator.of(context, rootNavigator: true).pop();

        // Informamos al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya has reposteado esta publicación')),
        );
        return;
      }

      // Obtener datos del usuario actual
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      // 1. Crear el documento en la colección reposts
      await _firestore.collection('reposts').add({
        'userId': currentUserId,
        'originalPostId': widget.postId,
        'roomId': widget.roomId,
        'createdAt': FieldValue.serverTimestamp(),
        'userData': userDoc.data(),
      });

      // 2. También crear un nuevo post que aparecerá en el feed principal
      await _firestore.collection('posts').add({
        'content': '', // El repost no tiene contenido propio
        'userId': currentUserId,
        'roomId': widget.roomId,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likedBy': [],
        'userData': userDoc.data(),
        'imageUrls': [], // No tiene imágenes propias
        'videoData': [], // No tiene videos propios
        'isRepost': true,
        'originalPostId': widget.postId,
        'originalPostData': _postData, // Guardamos una copia del post original
      });

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publicación reposteada con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      print('Error al repostear: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al repostear: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _doRepost() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para repostear')),
      );
      return;
    }

    final String currentUserId = _auth.currentUser!.uid;

    // No permitir repostear nuestro propio post
    if (_postData?['userId'] == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes repostear tu propia publicación'),
        ),
      );
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final String roomId = _postData?['roomId'] ?? '';

      // Verificar si el usuario es miembro de la sala o tiene permisos especiales
      bool canPost = false;

      // Primero verificar si es owner o admin (más eficiente)
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      final userRole = userDoc.data()?['role'];
      if (userRole == 'owner' || userRole == 'admin') {
        canPost = true;
      } else {
        // Si no es owner/admin, verificar membresía
        // Opción 1: Si los IDs de members están en formato roomId_userId
        try {
          final memberDoc = await _firestore
              .collection('members')
              .doc('${roomId}_$currentUserId')
              .get();

          if (memberDoc.exists) {
            canPost = true;
          }
        } catch (e) {
          // Si falla, intentar con una consulta
          final memberQuery = await _firestore
              .collection('members')
              .where('roomId', isEqualTo: roomId)
              .where('userId', isEqualTo: currentUserId)
              .limit(1)
              .get();

          if (memberQuery.docs.isNotEmpty) {
            canPost = true;
          }
        }
      }

      if (!canPost) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes ser miembro de la sala para repostear'),
          ),
        );
        return;
      }

      // 1. Crear entrada en la colección reposts
      final repostData = {
        'userId': currentUserId,
        'originalPostId': widget.postId,
        'roomId': roomId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final repostDoc = await _firestore.collection('reposts').add(repostData);

      // 2. Crear nuevo post con la referencia al original
      final newPostData = {
        'content': '',
        'userId': currentUserId,
        'roomId': roomId,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'repostsCount': 0,
        'likedBy': [],
        'userData': userDoc.data(),
        'imageUrls': [],
        'videoData': [],
        'isRepost': true,
        'originalPostId': widget.postId,
        'originalPostData': _postData,
        'repostId': repostDoc.id,
      };

      await _firestore.collection('posts').add(newPostData);

      // 3. Actualizar SOLO el contador de reposts
      await _firestore.collection('posts').doc(widget.postId).update({
        'repostsCount': FieldValue.increment(1),
      });

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación reposteada con éxito')),
      );

      // Recargar datos del post
      _loadPostData();
    } catch (e) {
      print('Error al repostear: $e');

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al repostear: $e')),
      );
    }
  }

  Future<void> _undoRepost() async {
    if (_auth.currentUser == null) return;

    final String currentUserId = _auth.currentUser!.uid;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // 1. Encontrar el documento de repost
      final repostQuery =
          await _firestore
              .collection('reposts')
              .where('userId', isEqualTo: currentUserId)
              .where('originalPostId', isEqualTo: widget.postId)
              .limit(1)
              .get();

      if (repostQuery.docs.isEmpty) {
        throw Exception('No se encontró el repost');
      }

      final repostId = repostQuery.docs.first.id;

      // 2. Encontrar el post que es un repost
      final repostPostQuery =
          await _firestore
              .collection('posts')
              .where('userId', isEqualTo: currentUserId)
              .where('isRepost', isEqualTo: true)
              .where('originalPostId', isEqualTo: widget.postId)
              .limit(1)
              .get();

      if (repostPostQuery.docs.isEmpty) {
        throw Exception('No se encontró la publicación de repost');
      }

      final repostPostId = repostPostQuery.docs.first.id;

      // 3. Eliminar ambos documentos
      await _firestore.collection('reposts').doc(repostId).delete();
      await _firestore.collection('posts').doc(repostPostId).delete();

      // 4. Decrementar el contador de reposts (SOLO ese campo, respetando reglas)
      await _firestore.collection('posts').doc(widget.postId).update({
        'repostsCount': FieldValue.increment(-1),
      });

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Repost eliminado')));

      // Refrescar datos del post
      _loadPostData();
    } catch (e) {
      print('Error al eliminar repost: $e');

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar repost: $e')));
    }
  }

  Future<bool> _checkIfRepostedByUser() async {
    if (_auth.currentUser == null) return false;

    final String currentUserId = _auth.currentUser!.uid;

    final repostQuery =
        await _firestore
            .collection('reposts')
            .where('userId', isEqualTo: currentUserId)
            .where('originalPostId', isEqualTo: widget.postId)
            .limit(1)
            .get();

    return repostQuery.docs.isNotEmpty;
  }

  Widget _buildInteractionBar() {
    final int likes = _postData?['likesCount'] ?? 0;
    final int comments = _postData?['commentsCount'] ?? 0;
    final int reposts = _postData?['repostsCount'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _buildInteractionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: likes.toString(),
            color: _isLiked ? Colors.red : Colors.white.withOpacity(0.7),
            onTap: _toggleLike,
          ),
          const SizedBox(width: 24),
          _buildInteractionButton(
            icon: Icons.chat_bubble_outline,
            label: comments.toString(),
            color: Colors.white.withOpacity(0.7),
            onTap: () {
              if (widget.autoShowComments) {
                // Ya estamos en la vista detallada, solo mostramos los comentarios
                setState(() {
                  _showComments = !_showComments;
                  if (_showComments) {
                    _loadComments();
                  }
                });
              } else {
                // Navegamos a la vista detallada
                _navigateToPostDetail();
              }
            },
          ),
          const Spacer(),
          FutureBuilder<bool>(
            future: _checkIfRepostedByUser(),
            builder: (context, snapshot) {
              final bool hasReposted = snapshot.data ?? false;

              return _buildInteractionButton(
                icon: Icons.repeat,
                label: _postData?['repostsCount']?.toString() ?? '0',
                color:
                    hasReposted ? Colors.green : Colors.white.withOpacity(0.7),
                onTap: () {
                  hasReposted ? _undoRepost() : _doRepost();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    String? label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          if (label != null) const SizedBox(width: 4),
          if (label != null)
            Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Área para agregar comentarios
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de respuesta
              if (_replyToUser != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Respondiendo a @$_replyToUser',
                        style: TextStyle(
                          color: Colors.blue.shade400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyToComment = null;
                            _replyToUser = null;
                            _commentController.clear();
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              // Campo de comentario
              Row(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream:
                        _firestore
                            .collection('users')
                            .doc(_auth.currentUser?.uid)
                            .snapshots(),
                    builder: (context, snapshot) {
                      String? photoURL;

                      // First try to get photo from Firestore user document
                      if (snapshot.hasData && snapshot.data != null) {
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        photoURL = userData?['photo'];
                      }

                      // Fall back to Auth photoURL if Firestore photo not available
                      photoURL ??= _auth.currentUser?.photoURL;

                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade700,
                        backgroundImage:
                            photoURL != null ? NetworkImage(photoURL) : null,
                        child:
                            photoURL == null
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                )
                                : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),

                      decoration: InputDecoration(
                        hintText: 'Añadir un comentario...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.blue.withOpacity(0.6),
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue, size: 20),
                    onPressed: _addComment,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista de comentarios o mensaje de vacío
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(
              child: Text(
                'Sé el primero en comentar',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                _comments.map((comment) => _buildCommentItem(comment)).toList(),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final String commentId = comment['id'];
    final String userId = comment['userId'];
    final String userName = comment['userName'];
    final String userPhoto = comment['userPhoto'];
    final String text = comment['text'] ?? '';
    final int likesCount = comment['likesCount'] ?? 0;
    final List<dynamic> likedBy = comment['likedBy'] ?? [];
    final Timestamp? timestamp = comment['createdAt'] as Timestamp?;
    final String timeAgo =
        timestamp != null
            ? timeago.format(timestamp.toDate(), locale: 'es')
            : '';

    final List<Map<String, dynamic>> replies = List<Map<String, dynamic>>.from(
      comment['replies'] ?? [],
    );
    final bool isLiked = likedBy.contains(_auth.currentUser?.uid);
    final bool isCommentOwner = userId == _auth.currentUser?.uid;

    // Only make dismissible if user is the comment owner
    Widget commentContent = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showUserProfile(userId),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade700,
              backgroundImage:
                  userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
              child:
                  userPhoto.isEmpty
                      ? const Icon(Icons.person, size: 14, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showUserProfile(userId),
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleCommentLike(commentId, isLiked),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color:
                            isLiked
                                ? Colors.red
                                : Colors.white.withOpacity(0.5),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      likesCount.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          // Si ya estamos respondiendo a este comentario, cancelar
                          if (_activeReplyCommentId == commentId) {
                            _activeReplyCommentId = null;
                            _replyToComment = null;
                            _replyToUser = null;
                          } else {
                            // Configurar estado para responder
                            _activeReplyCommentId = commentId;
                            _replyToComment = commentId;
                            _replyToUser = userName;
                          }
                        });
                      },
                      child: Text(
                        'Responder',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Make the comment dismissible only if the current user is the author
        isCommentOwner
            ? Dismissible(
              key: Key('comment-$commentId'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Eliminar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                // Show confirmation dialog
                return await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        title: const Text(
                          'Eliminar comentario',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          '¿Estás seguro que deseas eliminar este comentario?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.blue.shade300),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
              onDismissed: (direction) {
                // Delete the comment
                _deleteComment(commentId);
              },
              child: commentContent,
            )
            : commentContent,

        // 3. Campo de respuesta cuando este comentario está siendo respondido
        if (_activeReplyCommentId == commentId)
          _buildReplyField(commentId, userName),

        // Mostrar respuestas anidadas
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Column(
              children: replies.map((reply) => _buildReplyItem(reply)).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      // First update the local state to immediately remove the comment
      setState(() {
        // Remove the main comment if it matches
        _comments.removeWhere((comment) => comment['id'] == commentId);

        // Also check replies in all comments
        for (var comment in _comments) {
          final replies = comment['replies'] as List<Map<String, dynamic>>;
          replies.removeWhere((reply) => reply['id'] == commentId);
        }
      });

      // Then update the database
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Update comment count in the post
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentsCount': FieldValue.increment(-1),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comentario eliminado'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar comentario: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // 4. Añade este método para construir el campo de respuesta
  Widget _buildReplyField(String parentCommentId, String replyToUser) {
    final FocusNode focusNode = FocusNode()..requestFocus();

    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _replyController, // Use reply controller here
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Responder a $replyToUser...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: () {
                    setState(() {
                      _activeReplyCommentId = null;
                      _replyToComment = null;
                      _replyToUser = null;
                      _replyController.clear(); // Clear the reply controller
                    });
                  },
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: () async {
              if (_replyController.text.isEmpty) return;

              // Use the reply controller text for adding replies
              await _addReply(
                parentCommentId,
                replyToUser,
                _replyController.text,
              );

              setState(() {
                _activeReplyCommentId = null;
                _replyToComment = null;
                _replyToUser = null;
                _replyController.clear();
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> reply) {
    final String replyId = reply['id'];
    final String userId = reply['userId'];
    final String userName = reply['userName'];
    final String userPhoto = reply['userPhoto'];
    final String text = reply['text'] ?? '';
    final int likesCount = reply['likesCount'] ?? 0;
    final List<dynamic> likedBy = reply['likedBy'] ?? [];
    final Timestamp? timestamp = reply['createdAt'] as Timestamp?;
    final String timeAgo =
        timestamp != null
            ? timeago.format(timestamp.toDate(), locale: 'es')
            : '';
    final String replyTo = reply['replyTo'] ?? '';
    final bool isLiked = likedBy.contains(_auth.currentUser?.uid);
    final String parentCommentId = reply['parentCommentId'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showUserProfile(userId),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade700,
                  backgroundImage:
                      userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                  child:
                      userPhoto.isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.white,
                          )
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showUserProfile(userId),
                          child: Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        children: [
                          if (replyTo.isNotEmpty)
                            TextSpan(
                              text: '@$replyTo ',
                              style: TextStyle(
                                color: Colors.blue.shade300,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          TextSpan(
                            text: text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleCommentLike(replyId, isLiked),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color:
                                isLiked
                                    ? Colors.red
                                    : Colors.white.withOpacity(0.5),
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likesCount.toString(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              // Si ya estamos respondiendo a esta respuesta, cancelar
                              if (_activeReplyCommentId == replyId) {
                                _activeReplyCommentId = null;
                                _replyToComment = null;
                                _replyToUser = null;
                              } else {
                                // Configurar estado para responder a esta respuesta
                                _activeReplyCommentId = replyId;
                                _replyToComment =
                                    parentCommentId; // Mantiene la estructura de árbol
                                _replyToUser = userName;
                              }
                            });
                          },
                          child: Text(
                            'Responder',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Campo de respuesta cuando esta respuesta está siendo respondida
        if (_activeReplyCommentId == replyId)
          _buildReplyField(parentCommentId, userName),
      ],
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({Key? key, required this.child, this.isLoading = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.2),
          ],
          stops: const [0.1, 0.3, 0.4],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width * 3, bounds.height));
      },
      child: child,
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenCarousel({required this.imageUrls, this.initialIndex = 0});

  @override
  State<_FullScreenCarousel> createState() => _FullScreenCarouselState();
}

class _FullScreenCarouselState extends State<_FullScreenCarousel> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image carousel
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: Hero(
                    tag: 'postImage-fullscreen-$index',
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 30,
                          ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Image counter
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.imageUrls.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
