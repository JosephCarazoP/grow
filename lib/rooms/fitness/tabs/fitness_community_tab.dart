import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../components/community_post.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FitnessCommunityTab extends StatefulWidget {
  final Map<String, dynamic> roomData;
  final Function(String) navigateToSection;

  const FitnessCommunityTab({
    Key? key,
    required this.roomData,
    required this.navigateToSection,
  }) : super(key: key);

  @override
  State<FitnessCommunityTab> createState() => _FitnessCommunityTabState();
}

class _FitnessCommunityTabState extends State<FitnessCommunityTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _postController = TextEditingController();
  TextEditingController _searchController = TextEditingController();

  final int _postsPerPage = 10;
  DocumentSnapshot? _lastVisible;
  List<String> _postIds = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  // DocumentSnapshot? _lastDocument;
  bool _isSearchBarVisible = true;
  String _searchQuery = '';
  String _filterType = 'contenido'; // 'contenido' o 'usuario'
  Timer? _debounceTimer;
  bool _isScrollingDown = false;
  bool _isValidVideo = false;
  String _videoUrl = '';
  String _videoId = '';
  String _thumbnailUrl = '';
  final TextEditingController _videoUrlController = TextEditingController();
  final FocusNode _videoUrlFocusNode = FocusNode();
  Timer? _videoDebounceTimer;
  List<MediaItem> _mediaItems = []; // Added here as class field
  List<Map<String, dynamic>> _postsData = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postController.dispose();
    _searchController.dispose();
    _videoUrlController.dispose();
    _videoUrlFocusNode.dispose();
    _videoDebounceTimer?.cancel();
    super.dispose();
  }

  void _debounceVideoValidation(String url) {
    print("Debouncing video validation: $url");

    // Cancelar el timer anterior si está activo
    if (_videoDebounceTimer?.isActive ?? false) {
      _videoDebounceTimer!.cancel();
    }

    // Configurar un nuevo timer
    _videoDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (url.isNotEmpty) {
        _extractYouTubeInfo(url);
      } else {
        setState(() {
          _isValidVideo = false;
          _videoId = '';
          _thumbnailUrl = '';
        });
      }
    });
  }

  Future<void> _validateAndAddVideo() async {
    print("Validar button pressed");

    final url = _videoUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _extractYouTubeInfo(url);

      // Si la validación es exitosa, limpia el campo
      if (_isValidVideo) {
        _videoUrlController.clear();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _extractYouTubeInfo(String url) async {
    print("Extracting YouTube info from: $url");

    // Expresión regular mejorada que incluye soporte para Shorts
    RegExp regExp = RegExp(
      r"(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:shorts\/|watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})(?:\S*)?",
      caseSensitive: false,
    );

    final match = regExp.firstMatch(url);

    setState(() {
      if (match != null && match.groupCount >= 1) {
        _videoId = match.group(1)!;
        _videoUrl = url;
        _thumbnailUrl = 'https://img.youtube.com/vi/$_videoId/0.jpg';
        _isValidVideo = true;
        print("Valid YouTube URL: Video ID = $_videoId");

        // Limpiar el campo de texto después de validar correctamente
        _videoUrlController.clear();

        // Mostrar un mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video añadido correctamente')),
        );
      } else {
        _isValidVideo = false;
        print("Invalid YouTube URL");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL de YouTube no válida')),
        );
      }
    });
  }

  void _onScroll() {
    // Determinar la dirección del scroll
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      // Scroll hacia abajo - ocultar barras
      if (_isSearchBarVisible) {
        setState(() {
          _isSearchBarVisible = false;
          _isScrollingDown = true;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      // Scroll hacia arriba - mostrar barras
      if (!_isSearchBarVisible) {
        setState(() {
          _isSearchBarVisible = true;
          _isScrollingDown = false;
        });
      }
    }

    // Mostrar barras también cuando llegamos a la parte superior
    if (_scrollController.position.pixels <= 10 && !_isSearchBarVisible) {
      setState(() {
        _isSearchBarVisible = true;
        _isScrollingDown = false;
      });
    }

    // Carga infinita
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      _loadPosts();
      return;
    }

    setState(() {
      _isLoading = true;
      _postIds = [];
    });

    try {
      if (_filterType == 'usuario') {
        // Búsqueda por usuario usando el campo userData.name existente
        final userQuery =
            await _firestore
                .collection('posts')
                .where('roomId', isEqualTo: widget.roomData['id'])
                .get();

        // Filtramos manualmente los resultados por el nombre de usuario
        final filteredDocs =
            userQuery.docs.where((doc) {
              final userData = doc.data()['userData'] as Map<String, dynamic>?;
              final userName = userData?['name'] as String? ?? '';
              return userName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }).toList();

        setState(() {
          _postIds = filteredDocs.map((doc) => doc.id).toList();
          _lastVisible = filteredDocs.isNotEmpty ? filteredDocs.last : null;
          _isLoading = false;
        });

        print('Posts encontrados por usuario: ${_postIds.length}');
      } else if (_filterType == 'contenido') {
        // Obtener todos los posts y filtrar manualmente por contenido
        final contentQuery =
            await _firestore
                .collection('posts')
                .where('roomId', isEqualTo: widget.roomData['id'])
                .get();

        // Filtrar manualmente por contenido
        final filteredDocs =
            contentQuery.docs.where((doc) {
              final content = doc.data()['content'] as String? ?? '';
              return content.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

        setState(() {
          _postIds = filteredDocs.map((doc) => doc.id).toList();
          _lastVisible = filteredDocs.isNotEmpty ? filteredDocs.last : null;
          _isLoading = false;
        });

        print('Posts encontrados por contenido: ${_postIds.length}');
      } else if (_filterType == 'reciente') {
        // Primero obtenemos todos los posts ordenados por fecha
        final recentQuery =
            await _firestore
                .collection('posts')
                .where('roomId', isEqualTo: widget.roomData['id'])
                .orderBy('createdAt', descending: true)
                .get();

        // Luego filtramos manualmente por contenido
        final filteredDocs =
            recentQuery.docs.where((doc) {
              final content = doc.data()['content'] as String? ?? '';
              return content.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

        setState(() {
          _postIds = filteredDocs.map((doc) => doc.id).toList();
          _lastVisible = filteredDocs.isNotEmpty ? filteredDocs.last : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error en búsqueda: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la búsqueda: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _postIds = [];
      _postsData = []; // Añadimos esta lista para almacenar los datos completos
    });

    try {
      final String roomId = widget.roomData['roomId']?.toString() ?? '';

      if (roomId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final QuerySnapshot postsSnapshot =
          await _firestore
              .collection('posts')
              .where('roomId', isEqualTo: roomId)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();

      print('Found ${postsSnapshot.docs.length} posts for roomId: $roomId');

      final List<Map<String, dynamic>> loadedPosts = [];
      for (var doc in postsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedPosts.add({'id': doc.id, ...data});
      }

      if (mounted) {
        setState(() {
          loadedPosts.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          _postIds = loadedPosts.map((post) => post['id'] as String).toList();
          _postsData = loadedPosts; // Guardamos los datos completos
          _isLoading = false;
          _lastVisible =
              postsSnapshot.docs.isNotEmpty ? postsSnapshot.docs.last : null;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_lastVisible == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _firestore
          .collection('posts')
          .where('roomId', isEqualTo: widget.roomData['id']);

      if (_searchQuery.isNotEmpty && _filterType == 'contenido') {
        query = _firestore
            .collection('posts')
            .where('roomId', isEqualTo: widget.roomData['id'])
            .orderBy('content')
            .startAt([_searchQuery])
            .endAt([_searchQuery + '\uf8ff'])
            .orderBy('createdAt', descending: true)
            .startAfterDocument(_lastVisible!);
      } else {
        query = query
            .orderBy('createdAt', descending: true)
            .startAfterDocument(_lastVisible!);
      }

      final querySnapshot = await query.limit(_postsPerPage).get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _postIds.addAll(querySnapshot.docs.map((doc) => doc.id).toList());
          _lastVisible = querySnapshot.docs.last;
        });
      } else {
        setState(() {
          _hasMorePosts = false;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _showCreatePostModal() async {
    _postController.clear();
    List<MediaItem> _mediaItems = []; // Lista combinada de archivos multimedia
    final int maxMediaItems = 10; // Máximo de archivos multimedia permitidos

    // Fetch user data from the 'members' collection
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    String userName = 'Usuario';
    String? userPhoto;

    try {
      // Try to get member data from the top-level members collection
      final memberQuery =
          await _firestore
              .collection('members')
              .where('userId', isEqualTo: userId)
              .where('roomId', isEqualTo: widget.roomData['id'])
              .limit(1)
              .get();

      if (memberQuery.docs.isNotEmpty) {
        final memberData = memberQuery.docs.first.data();
        userName = memberData['userName'] ?? 'Usuario';
        userPhoto = memberData['userPhoto'];
      } else {
        // Fallback to users collection
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          userName =
              userData?['name'] ?? _auth.currentUser?.displayName ?? 'Usuario';
          userPhoto = userData?['photo'] ?? _auth.currentUser?.photoURL;
        } else {
          // Last resort: use Firebase Auth data
          userName = _auth.currentUser?.displayName ?? 'Usuario';
          userPhoto = _auth.currentUser?.photoURL;
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    // Show the modal with blur effect
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: StatefulBuilder(
              builder:
                  (context, setState) => Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade900,
                          Colors.black.withOpacity(0.95),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      child: Column(
                        children: [
                          // Handle bar
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 8,
                              ),
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),

                          // Header
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade800.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.grey.shade800,
                                    backgroundImage:
                                        userPhoto != null
                                            ? CachedNetworkImageProvider(
                                              userPhoto,
                                            )
                                            : null,
                                    child:
                                        userPhoto == null
                                            ? const Icon(
                                              Icons.person,
                                              color: Colors.white70,
                                              size: 26,
                                            )
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 17,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade700,
                                              Colors.purple.shade700,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: const Text(
                                          'Nueva publicación',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade800.withOpacity(
                                        0.7,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content area
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Post text field
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade800.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.black.withOpacity(0.3),
                                          Colors.grey.shade900.withOpacity(0.2),
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    child: TextField(
                                      controller: _postController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.3,
                                      ),
                                      maxLines: 7,
                                      minLines: 3,
                                      decoration: InputDecoration(
                                        hintText:
                                            '¿Qué quieres compartir con la comunidad?',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Mostrar archivos multimedia seleccionados
                                  if (_mediaItems.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Contador de archivos
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Text(
                                              'Archivos seleccionados: ${_mediaItems.length}/$maxMediaItems',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),

                                          // Grid de miniaturas
                                          GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                ),
                                            itemCount: _mediaItems.length,
                                            itemBuilder: (context, index) {
                                              final mediaItem =
                                                  _mediaItems[index];
                                              return Stack(
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withOpacity(0.1),
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      child:
                                                          mediaItem.type ==
                                                                  'image'
                                                              ? Image.file(
                                                                mediaItem
                                                                    .source,
                                                                fit:
                                                                    BoxFit
                                                                        .cover,
                                                                width:
                                                                    double
                                                                        .infinity,
                                                                height:
                                                                    double
                                                                        .infinity,
                                                              )
                                                              : Stack(
                                                                fit:
                                                                    StackFit
                                                                        .expand,
                                                                children: [
                                                                  Image.network(
                                                                    mediaItem
                                                                        .thumbnailUrl!,
                                                                    fit:
                                                                        BoxFit
                                                                            .cover,
                                                                  ),
                                                                  Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .play_circle_fill,
                                                                      color: Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.8,
                                                                          ),
                                                                      size: 30,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                    ),
                                                  ),

                                                  // Botón para eliminar
                                                  Positioned(
                                                    top: 5,
                                                    right: 5,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _mediaItems.removeAt(
                                                            index,
                                                          );
                                                        });
                                                      },
                                                      child: Container(
                                                        width: 26,
                                                        height: 26,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.6),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                  0.2,
                                                                ),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),

                                                  // Indicador de tipo
                                                  Positioned(
                                                    bottom: 5,
                                                    left: 5,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            mediaItem.type ==
                                                                    'image'
                                                                ? Colors.blue
                                                                    .withOpacity(
                                                                      0.7,
                                                                    )
                                                                : Colors.red
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        mediaItem.type ==
                                                                'image'
                                                            ? Icons.image
                                                            : Icons.videocam,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Botones para añadir contenido
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade800.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey.shade900,
                                          Colors.black,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              color: Colors.blue.shade300,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              "Añadir archivos multimedia",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Botones para añadir imágenes o videos
                                        Row(
                                          children: [
                                            // Botón para imágenes
                                            Expanded(
                                              child: InkWell(
                                                onTap:
                                                    _mediaItems.length <
                                                            maxMediaItems
                                                        ? () async {
                                                          final picker =
                                                              ImagePicker();
                                                          final pickedImages =
                                                              await picker
                                                                  .pickMultiImage();

                                                          if (pickedImages
                                                              .isNotEmpty) {
                                                            setState(() {
                                                              for (var image
                                                                  in pickedImages) {
                                                                if (_mediaItems
                                                                        .length <
                                                                    maxMediaItems) {
                                                                  _mediaItems.add(
                                                                    MediaItem(
                                                                      type:
                                                                          'image',
                                                                      source: File(
                                                                        image
                                                                            .path,
                                                                      ),
                                                                    ),
                                                                  );
                                                                } else {
                                                                  break;
                                                                }
                                                              }
                                                            });
                                                          }
                                                        }
                                                        : null,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.blue
                                                          .withOpacity(
                                                            _mediaItems.length <
                                                                    maxMediaItems
                                                                ? 0.3
                                                                : 0.1,
                                                          ),
                                                      width: 1.5,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    color:
                                                        _mediaItems.length <
                                                                maxMediaItems
                                                            ? null
                                                            : Colors
                                                                .grey
                                                                .shade800
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient:
                                                              LinearGradient(
                                                                colors: [
                                                                  Colors
                                                                      .blue
                                                                      .shade700,
                                                                  Colors
                                                                      .blue
                                                                      .shade900,
                                                                ],
                                                              ),
                                                          color: Colors.red.withOpacity(
                                                            _mediaItems.length <
                                                                    maxMediaItems
                                                                ? 1.0
                                                                : 0.5,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.photo_library,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Imágenes",
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                _mediaItems.length <
                                                                        maxMediaItems
                                                                    ? 1.0
                                                                    : 0.5,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Botón para videos
                                            Expanded(
                                              child: InkWell(
                                                onTap:
                                                    _mediaItems.length <
                                                            maxMediaItems
                                                        ? () {
                                                          // Mostrar diálogo para añadir URL de YouTube
                                                          _showYoutubeInputDialog(
                                                            context,
                                                            setState,
                                                            _mediaItems,
                                                          );
                                                        }
                                                        : null,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.red
                                                          .withOpacity(
                                                            _mediaItems.length <
                                                                    maxMediaItems
                                                                ? 0.3
                                                                : 0.1,
                                                          ),
                                                      width: 1.5,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    color:
                                                        _mediaItems.length <
                                                                maxMediaItems
                                                            ? null
                                                            : Colors
                                                                .grey
                                                                .shade800
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient:
                                                              LinearGradient(
                                                                colors: [
                                                                  Colors
                                                                      .red
                                                                      .shade700,
                                                                  Colors
                                                                      .red
                                                                      .shade900,
                                                                ],
                                                              ),
                                                          color: Colors.red.withOpacity(
                                                            _mediaItems.length <
                                                                    maxMediaItems
                                                                ? 1.0
                                                                : 0.5,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .play_circle_filled,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Videos",
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                _mediaItems.length <
                                                                        maxMediaItems
                                                                    ? 1.0
                                                                    : 0.5,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (_mediaItems.length >= maxMediaItems)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 12,
                                            ),
                                            child: Center(
                                              child: Text(
                                                "Límite de $maxMediaItems archivos alcanzado",
                                                style: TextStyle(
                                                  color: Colors.amber
                                                      .withOpacity(0.8),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Botones de acción
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              15,
                              20,
                              15 + MediaQuery.of(context).padding.bottom,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.shade800.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, -3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_postController.text
                                              .trim()
                                              .isNotEmpty ||
                                          _mediaItems.isNotEmpty) {
                                        // Procesar la publicación con los archivos multimedia
                                        _createPost(
                                          _postController.text,
                                          _mediaItems,
                                        );
                                        Navigator.pop(context);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Publicar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
  }

  void _showYoutubeInputDialog(
    BuildContext context,
    StateSetter setModalState,
    List<MediaItem> mediaItems,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Añadir video de YouTube',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _videoUrlController,
                  focusNode: _videoUrlFocusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Pega la URL de YouTube aquí',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _debounceVideoValidation,
                ),
                const SizedBox(height: 16),
                if (_isValidVideo)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_thumbnailUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.8),
                        size: 40,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (_isValidVideo) {
                    setModalState(() {
                      mediaItems.add(
                        MediaItem(
                          type: 'video',
                          source: _videoUrl,
                          videoId: _videoId,
                          thumbnailUrl: _thumbnailUrl,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL de video no válida')),
                    );
                  }
                },
                child: const Text(
                  'Añadir',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _createPost(String content, List<MediaItem> mediaItems) async {
    if ((content.isEmpty && mediaItems.isEmpty) || _auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay contenido para publicar')),
      );
      return;
    }

    // Debug: Imprimir información para ver qué contiene widget.roomData
    print("Debug - roomData: ${widget.roomData}");

    // Usar roomId, no id
    final dynamic roomIdValue = widget.roomData['roomId'];
    if (roomIdValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la sala: roomId es null'),
        ),
      );
      return;
    }

    final String roomId = roomIdValue.toString();
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la sala: roomId está vacío'),
        ),
      );
      return;
    }

    final String userId = _auth.currentUser!.uid;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Procesar los archivos multimedia
      List<String> imageUrls = [];
      List<Map<String, dynamic>> videoData = [];

      // Procesar cada ítem multimedia
      for (var item in mediaItems) {
        if (item.type == 'image' && item.source != null) {
          // Subir imagen a Firebase Storage
          final String fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${userId}.jpg';
          final Reference storageRef = _storage.ref().child(
            'posts/$roomId/$fileName',
          );

          await storageRef.putFile(item.source);
          final String downloadUrl = await storageRef.getDownloadURL();
          imageUrls.add(downloadUrl);
        } else if (item.type == 'video') {
          // Añadir datos del video (YouTube)
          videoData.add({
            'videoId': item.videoId ?? '',
            'thumbnailUrl': item.thumbnailUrl ?? '',
            'url': item.url ?? '',
          });
        }
      }

      // Obtener datos del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();

      // Crear el post directamente en la colección principal 'posts'
      final postData = {
        'content': content,
        'userId': userId,
        'roomId': roomId,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likedBy': [],
        'userData': userDoc.data(),
        'imageUrls': imageUrls,
        'videoData': videoData,
      };

      // Guardar directamente en la colección principal de posts
      final postRef = await _firestore.collection('posts').add(postData);

      // NO hacer esta referencia adicional que causa el error de permisos
      // await _firestore
      //     .collection('rooms')
      //     .doc(roomId)
      //     .collection('posts')
      //     .doc(postRef.id)
      //     .set({
      //   'postId': postRef.id,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Limpiar controlador de texto
      _postController.clear();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación creada con éxito')),
      );

      // Recargar posts
      await Future.delayed(const Duration(milliseconds: 500));
      _mediaItems.clear();
      await _loadPosts();
    } catch (e) {
      print('Error creating post: $e');

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la publicación: $e')),
      );
    }
  }

  void _onSearchQueryChanged(String query) {
    // Cancelar el timer anterior si existe
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    setState(() {
      _searchQuery = query;
    });

    // Debounce para no realizar búsquedas con cada tecla
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (query.isEmpty) {
        _loadPosts();
      } else {
        _performSearch();
      }
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fitness_community_tab',
        onPressed: _showCreatePostModal,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Barra de búsqueda con animación
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchBarVisible ? 80 : 0,
            child: Opacity(
              opacity: _isSearchBarVisible ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Buscar en comunidad...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchQueryChanged('');
                                      },
                                    )
                                    : null,
                          ),
                          onChanged: _onSearchQueryChanged,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filtros solo visibles cuando hay búsqueda y la barra está visible
          if (_searchQuery.isNotEmpty && _isSearchBarVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('contenido', 'Contenido'),
                    const SizedBox(width: 10),
                    _buildFilterChip('usuario', 'Usuario'),
                    const SizedBox(width: 10),
                    _buildFilterChip('reciente', 'Más recientes'),
                  ],
                ),
              ),
            ),

          // Prompt para crear publicación con animación
          // Prompt para crear publicación con animación
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchBarVisible ? 110 : 0, // Aumentado de 100 a 110
            child: Opacity(
              opacity: _isSearchBarVisible ? 1.0 : 0.0,
              child:
                  _isSearchBarVisible
                      ? _buildCreatePostPrompt()
                      : const SizedBox(),
            ),
          ),

          // Lista de posts o estado vacío
          Expanded(
            child: Column(
              children: [
                if (_isLoading)
                  _buildLoadingIndicator()
                else if (_postIds.isEmpty)
                  _buildEmptyState()
                else
                  Expanded(child: _buildPostList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = _filterType == value;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _filterType = value;
          });
          _performSearch();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(
                    colors: [Colors.purple, Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? Colors.transparent : Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _buildCreatePostPrompt() {
    return FutureBuilder<QuerySnapshot>(
      future:
          _firestore
              .collection('members')
              .where('userId', isEqualTo: _auth.currentUser?.uid)
              .where('roomId', isEqualTo: widget.roomData['id'])
              .limit(1)
              .get(),
      builder: (context, snapshot) {
        String? photoUrl;

        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.docs.isNotEmpty) {
          final memberData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>?;
          photoUrl = memberData?['userPhoto'];
        }

        photoUrl ??= _auth.currentUser?.photoURL;

        return GestureDetector(
          onTap: _showCreatePostModal,
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12,
            ), // Reducido el margen superior
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey[900]!, Colors.grey[850]!],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey[700]!.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'user-avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20, // Reducido de 22 a 20
                      backgroundColor: Colors.black.withOpacity(0.2),
                      backgroundImage:
                          photoUrl != null
                              ? CachedNetworkImageProvider(photoUrl)
                              : null,
                      child:
                          photoUrl == null
                              ? const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.white,
                              )
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12), // Reducido de 14 a 12
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14, // Aumentado de 12 a 14
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey[700]!.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '¿Qué quieres compartir?',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14, // Aumentado de 11 a 14
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 72,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay publicaciones aún',
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
              'Sé el primero en compartir algo con la comunidad',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePostModal,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Crear publicación'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 80), // Reduced top padding
      itemCount: _postIds.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _postIds.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.8),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cargando más publicaciones...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final roomId = widget.roomData['id'] as String? ?? '';
        final postId = _postIds[index];

        // Animation delay based on index for staggered effect
        final animationDelay = Duration(milliseconds: 40 * (index % 10)); // Slightly faster animations

        return FutureBuilder(
          future: Future.delayed(animationDelay, () => true),
          builder: (context, snapshot) {
            return AnimatedOpacity(
              opacity: snapshot.data == true ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: snapshot.data == true ? Offset.zero : const Offset(0, 0.1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('posts').doc(postId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return _buildPostPlaceholder();
                    }

                    final postData = snapshot.data!.data() as Map<String, dynamic>?;
                    if (postData == null) return const SizedBox.shrink();

                    final isRepost = postData['isRepost'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10), // Significantly reduced bottom padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRepost)
                            Padding(
                              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 4), // Reduced bottom padding
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6), // Slightly smaller padding
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.withOpacity(0.2),
                                          Colors.teal.withOpacity(0.2),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Icon(
                                      Icons.repeat_rounded,
                                      size: 16, // Slightly smaller icon
                                      color: Colors.greenAccent.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 8), // Reduced spacing
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: postData['userData']?['name'] ?? 'Usuario',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' reposteó esta publicación',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: const TextStyle(fontSize: 13), // Slightly smaller text
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: isRepost ? 12 : 16,
                              vertical: 0, // No vertical margin
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20), // Slightly reduced corner radius
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: CommunityPost(
                                  postId: postId,
                                  roomId: roomId,
                                  showFullContent: true,
                                  onCommentAdded: () {
                                    _loadPosts();
                                  },
                                  onLikeRemoved: () {},
                                  autoShowComments: false,
                                ),
                              ),
                            ),
                          ),

                          // Add a small divider between posts (optional)
                          if (index < _postIds.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                              child: Divider(
                                height: 1,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
// Helper method to show loading placeholder
  Widget _buildPostPlaceholder() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
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
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(
                child: Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ShimmerLoading(
                child: Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ShimmerLoading(
                child: Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MediaItem {
  final String type; // 'image' o 'video'
  final dynamic source; // File para imágenes
  final String? url; // URL para videos
  final String? videoId;
  final String? thumbnailUrl;

  MediaItem({
    required this.type,
    this.source,
    this.url,
    this.videoId,
    this.thumbnailUrl,
  });
}
