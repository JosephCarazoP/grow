import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../components/community_post.dart';

class MyLikesScreen extends StatefulWidget {
  const MyLikesScreen({Key? key}) : super(key: key);

  @override
  State<MyLikesScreen> createState() => _MyLikesScreenState();
}

class _MyLikesScreenState extends State<MyLikesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _likedPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreLikes = true;
  DocumentSnapshot? _lastVisible;
  final int _likesPerPage = 15;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreLikes) {
      _loadMoreLikedPosts();
    }
  }

  Future<void> _loadLikedPosts() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
      _likedPosts = [];
    });

    try {
      final userId = _auth.currentUser!.uid;

      // Query the likes collection for this user
      final likesQuery =
          await _firestore
              .collection('likes')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(_likesPerPage)
              .get();

      if (likesQuery.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMoreLikes = false;
        });
        return;
      }

      _lastVisible = likesQuery.docs.last;

      // For each like, get the associated post
      final likedPostsData = await Future.wait(
        likesQuery.docs.map((likeDoc) async {
          final likeData = likeDoc.data();
          final postId = likeData['postId'] as String;
          final likeTime = likeData['createdAt'] as Timestamp?;

          // Get the post data
          final postDoc =
              await _firestore.collection('posts').doc(postId).get();

          if (!postDoc.exists) return null;

          final postData = postDoc.data()!;
          return {
            'postId': postId,
            'postData': postData,
            'likeTime': likeTime,
            'roomId': likeData['roomId'] ?? '',
          };
        }),
      );

      setState(() {
        _likedPosts = likedPostsData.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading liked posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreLikedPosts() async {
    if (_auth.currentUser == null || _lastVisible == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final userId = _auth.currentUser!.uid;

      final likesQuery =
          await _firestore
              .collection('likes')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .startAfterDocument(_lastVisible!)
              .limit(_likesPerPage)
              .get();

      if (likesQuery.docs.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreLikes = false;
        });
        return;
      }

      _lastVisible = likesQuery.docs.last;

      final likedPostsData = await Future.wait(
        likesQuery.docs.map((likeDoc) async {
          final likeData = likeDoc.data();
          final postId = likeData['postId'] as String;
          final likeTime = likeData['createdAt'] as Timestamp?;

          final postDoc =
              await _firestore.collection('posts').doc(postId).get();

          if (!postDoc.exists) return null;

          final postData = postDoc.data()!;
          return {
            'postId': postId,
            'postData': postData,
            'likeTime': likeTime,
            'roomId': likeData['roomId'] ?? '',
          };
        }),
      );

      final newPosts =
          likedPostsData.whereType<Map<String, dynamic>>().toList();

      setState(() {
        _likedPosts.addAll(newPosts);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more liked posts: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _showPostModal(String postId, String roomId, int index) {
    // Añadir parámetro index
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Dialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Publicación',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: CommunityPost(
                            postId: postId,
                            roomId: roomId,
                            showFullContent: true,
                            onLikeRemoved: () {
                              // Eliminar el post de la lista cuando se quita el like
                              setState(() {
                                _likedPosts.removeAt(index);
                              });
                              // Cerrar el diálogo si está abierto
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  String _formatPostDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final format = DateFormat('d \'de\' MMMM \'de\' y', 'es');
    return format.format(date);
  }

  String _formatLikeDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final format = DateFormat('d \'de\' MMMM \'de\' y', 'es');
    return format.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mis Likes', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _likedPosts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadLikedPosts,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _likedPosts.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _likedPosts.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }

                    final item = _likedPosts[index];
                    final postData = item['postData'] as Map<String, dynamic>;
                    final userData =
                        postData['userData'] as Map<String, dynamic>?;
                    final postCreatedAt = postData['createdAt'] as Timestamp?;
                    final likeTime = item['likeTime'] as Timestamp?;
                    final roomId = item['roomId'] as String;

                    return _buildLikedPostItem(
                      postId: item['postId'],
                      roomId: roomId,
                      authorName: userData?['name'] ?? 'Usuario',
                      authorPhoto: userData?['photo'] ?? '',
                      postDate: postCreatedAt,
                      likeDate: likeTime,
                      content: postData['content'] ?? '',
                      index: index, // Pasa el índice aquí
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 72,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No has dado like a ninguna publicación',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Las publicaciones que te gusten aparecerán aquí',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedPostItem({
    required String postId,
    required String roomId,
    required String authorName,
    required String authorPhoto,
    required Timestamp? postDate,
    required Timestamp? likeDate,
    required String content,
    required int index, // Added missing parameter
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPostModal(postId, roomId, index),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade700,
                  backgroundImage:
                      authorPhoto.isNotEmpty
                          ? CachedNetworkImageProvider(authorPhoto)
                          : null,
                  child:
                      authorPhoto.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Publicado el: ${_formatPostDate(postDate)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Le diste like el: ${_formatLikeDate(likeDate)}',
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          content,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
