// lib/rooms/fitness/screens/post_detail_page.dart
import 'package:flutter/material.dart';
import 'package:grow/rooms/fitness/components/community_post.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String roomId;
  final VoidCallback? onLikeRemoved;

  const PostDetailPage({
    Key? key,
    required this.postId,
    required this.roomId,
    this.onLikeRemoved,
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Publicación',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Establecemos heroTag único para evitar conflictos
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_detail_fab',
        onPressed: () {
          // Puedes implementar alguna acción aquí
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comparte esta publicación'),
            ),
          );
        },
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
        children: [
          // El post completo con sus comentarios siempre visibles
          CommunityPost(
            postId: widget.postId,
            roomId: widget.roomId,
            showFullContent: true,
            autoShowComments: true,
            onLikeRemoved: widget.onLikeRemoved,
          ),
        ],
      ),
    );
  }
}