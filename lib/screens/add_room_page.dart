import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:grow/screens/home_hub.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart';

Future<File?> _compressInBackground(Map<String, dynamic> params) async {
  File file = params['file'];
  int quality = params['quality'];
  String targetPath = params['targetPath'];

  // FlutterImageCompress devuelve XFile?, necesitamos convertirlo a File
  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    quality: quality,
    minWidth: 720,
    minHeight: 720,
    format: CompressFormat.webp,
  );

  // Convertir XFile a File
  return result != null ? File(result.path) : null;
}

// Función modificada
Future<File?> compressImage(File file, {int quality = 85}) async {
  final dir = await getTemporaryDirectory();
  final targetPath = p.join(
    dir.path,
    '${DateTime.now().millisecondsSinceEpoch}.webp',
  );

  try {
    print('Iniciando compresión a WebP: ${file.path}');
    // Usa compute para mover el trabajo pesado fuera del hilo principal
    var result = await compute(_compressInBackground, {
      'file': file,
      'quality': quality,
      'targetPath': targetPath,
    }).catchError((e) {
      print('Error en la compresión: $e');
      return null; // En caso de error, retornar null
    });

    return result;
  } catch (e) {
    print('Error al comprimir imagen: $e');
    return null;
  }
}

// Helper function for input decoration style (kept as is)
InputDecoration _inputStyle(String label) {
  return InputDecoration(labelText: label, border: const OutlineInputBorder());
}

// Slide 1: Introducción (kept as is)
class Slide1 extends StatelessWidget {
  final VoidCallback onNext;

  const Slide1({required this.onNext, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/grow_baja_calidad_negro.png',
            height: 200,
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported, size: 150),
          ),
          const Text(
            '¡Bienvenido! Para crear tu sala, necesitamos que nos brindes algunos datos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // Reemplazar la navegación actual para evitar que la app se cierre
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const HomeHubPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 30,
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

// Slide 2: Información de la sala (Updated with Category)
class Slide2 extends StatefulWidget {
  final TextEditingController nombreController;
  final TextEditingController descripcionCortaController;
  final TextEditingController descripcionController;
  final TextEditingController precioController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final List<Map<String, dynamic>> mediaItems;
  final Function(List<Map<String, dynamic>>) onMediaItemsChanged;
  final VoidCallback onNext;

  const Slide2({
    required this.nombreController,
    required this.descripcionCortaController,
    required this.descripcionController,
    required this.precioController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.mediaItems,
    required this.onMediaItemsChanged,
    required this.onNext,
    super.key,
  });

  @override
  State<Slide2> createState() => _Slide2State();
}

class _Slide2State extends State<Slide2> {
  final List<String> categories = const [
    'Fitness',
    'Negocios',
    'Educación',
    'Desarrollo Personal',
    'Otro',
  ];

  final TextEditingController _urlController = TextEditingController();
  bool _isVideo = true; // Por defecto, agregar video

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // Seleccionar imagen con selección de fuente
  Future<File?> selectImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      // Comprimir la imagen
      File? compressedFile = await compressImage(file);
      return compressedFile ?? file;
    } else {
      return null;
    }
  }

  // Mostrar opciones para seleccionar imagen
  Future<void> _mostrarOpcionesDeImagen() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Seleccionar desde galería'),
                  onTap: () async {
                    Navigator.pop(context);
                    final file = await selectImage(ImageSource.gallery);
                    if (file != null) {
                      _addImageFromFile(file);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Tomar una foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final file = await selectImage(ImageSource.camera);
                    if (file != null) {
                      _addImageFromFile(file);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Diálogo para ingresar URL de imagen
  Future<void> _mostrarDialogoURL() async {
    String urlTemp = '';
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pegar URL de imagen'),
            content: TextField(
              decoration: const InputDecoration(
                hintText: 'https://',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => urlTemp = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (urlTemp.isNotEmpty && _isValidUrl(urlTemp)) {
                    final newItems = List<Map<String, dynamic>>.from(
                      widget.mediaItems,
                    );
                    newItems.add({
                      'type': 'image',
                      'url': urlTemp,
                      'isLocal': false,
                      'verticalPosition': 0.0,
                    });
                    widget.onMediaItemsChanged(newItems);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL inválida')),
                    );
                  }
                },
                child: const Text('Añadir'),
              ),
            ],
          ),
    );
  }

  void _showMediaManagementDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Text(
                              "Gestionar contenido multimedia",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: widget.mediaItems.length,
                          itemBuilder: (context, index) {
                            final item = widget.mediaItems[index];
                            return Dismissible(
                              key: ValueKey(index),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) {
                                setState(() {
                                  final newItems =
                                      List<Map<String, dynamic>>.from(
                                        widget.mediaItems,
                                      );
                                  newItems.removeAt(index);
                                  widget.onMediaItemsChanged(newItems);
                                });
                              },
                              child: ListTile(
                                leading: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child:
                                      item['type'] == 'video'
                                          ? _buildVideoThumbnail(item)
                                          : _buildImageThumbnail(item),
                                ),
                                title: Text(
                                  item['type'] == 'video'
                                      ? 'Video de YouTube'
                                      : 'Imagen',
                                ),
                                subtitle:
                                    item['type'] == 'image'
                                        ? Text(
                                          item['isLocal'] == true
                                              ? 'Imagen local'
                                              : 'Imagen de URL',
                                        )
                                        : null,
                                trailing:
                                    item['type'] == 'image'
                                        ? IconButton(
                                          icon: const Icon(Icons.tune),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showAdjustPositionDialog(
                                              item,
                                              index,
                                            );
                                          },
                                        )
                                        : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildImageThumbnail(Map<String, dynamic> item) {
    final double verticalPosition = item['verticalPosition'] ?? 0.0;

    return item['isLocal'] == true
        ? Image.file(
          item['file'],
          fit: BoxFit.cover,
          alignment: Alignment(0, verticalPosition),
        )
        : CachedNetworkImage(
          imageUrl: item['url'],
          fit: BoxFit.cover,
          alignment: Alignment(0, verticalPosition),
          placeholder:
              (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        );
  }

  Widget _buildVideoThumbnail(Map<String, dynamic> item) {
    final String youtubeId = item['youtubeId'] ?? '';

    // Usar un placeholder hasta que sea necesario
    return Stack(
      fit: StackFit.expand,
      children: [
        // Usar memoria caché con tamaños específicos
        CachedNetworkImage(
          imageUrl: "https://img.youtube.com/vi/$youtubeId/0.jpg",
          fit: BoxFit.cover,
          memCacheWidth: 300, // Limitar el tamaño de memoria caché
          memCacheHeight: 200,
          fadeInDuration: const Duration(milliseconds: 100),
          placeholder:
              (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 35),
        ),
      ],
    );
  }

  // Extraer ID de YouTube
  String? _getYoutubeId(String url) {
    RegExp regExp = RegExp(
      r"^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*",
      caseSensitive: false,
    );

    RegExpMatch? match = regExp.firstMatch(url);
    return (match != null && match.groupCount >= 7) ? match.group(7) : null;
  }

  // Validar URL
  bool _isValidUrl(String url) {
    if (_isVideo) {
      return _getYoutubeId(url) != null;
    } else {
      final Uri? uri = Uri.tryParse(url);
      return uri != null &&
          uri.hasScheme &&
          (uri.isScheme('http') || uri.isScheme('https'));
    }
  }

  // Agregar item a la lista desde URL
  void _addMediaItem() {
    if (_urlController.text.isEmpty) return;

    if (!_isValidUrl(_urlController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVideo ? 'URL de YouTube inválida' : 'URL de imagen inválida',
          ),
        ),
      );
      return;
    }

    final newItems = List<Map<String, dynamic>>.from(widget.mediaItems);
    newItems.add({
      'type': _isVideo ? 'video' : 'image',
      'url': _urlController.text,
      'youtubeId': _isVideo ? _getYoutubeId(_urlController.text) : null,
      'isLocal': false,
      'verticalPosition': 0.0,
    });

    widget.onMediaItemsChanged(newItems);
    _urlController.clear();
  }

  void _showAdjustPositionDialog(Map<String, dynamic> item, int index) {
    // Crear una variable local para el estado
    double currentPosition = item['verticalPosition'] ?? 0.0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ajustar posición vertical',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Visualización de la imagen con posición aplicada
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          item['isLocal']
                              ? Image.file(
                                item['file'],
                                fit: BoxFit.cover,
                                alignment: Alignment(0, currentPosition),
                              )
                              : CachedNetworkImage(
                                imageUrl: item['url'],
                                fit: BoxFit.cover,
                                alignment: Alignment(0, currentPosition),
                              ),
                    ),

                    const SizedBox(height: 20),
                    Text('Valor: ${currentPosition.toStringAsFixed(2)}'),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _updateImagePosition(index, currentPosition);
                            Navigator.of(context).pop();
                          },
                          child: Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Añadir imagen desde archivo
  void _addImageFromFile(File file) {
    final newItems = List<Map<String, dynamic>>.from(widget.mediaItems);
    newItems.add({
      'type': 'image',
      'file': file,
      'isLocal': true,
      'verticalPosition': 0.0,
    });
    widget.onMediaItemsChanged(newItems);
  }

  // Eliminar item de la lista
  void _removeMediaItem(int index) {
    final newItems = List<Map<String, dynamic>>.from(widget.mediaItems);
    newItems.removeAt(index);
    widget.onMediaItemsChanged(newItems);
  }

  // Actualizar posición vertical de una imagen
  void _updateImagePosition(int index, double position) {
    final newItems = List<Map<String, dynamic>>.from(widget.mediaItems);
    newItems[index]['verticalPosition'] = position;
    widget.onMediaItemsChanged(newItems);
  }

  // Widgets para previsualización de YouTube
  Widget _buildYoutubePreview(String youtubeId) {
    return InkWell(
      onTap: () {
        final controller = YoutubePlayerController.fromVideoId(
          videoId: youtubeId,
          params: const YoutubePlayerParams(
            showFullscreenButton: true,
            mute: false,
            showControls: true,
          ),
        );

        showDialog(
          context: context,
          barrierColor: Colors.black87,
          barrierDismissible: true,
          builder:
              (dialogContext) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          // Detener y disponer el controlador antes de cerrar
                          controller.close();
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: YoutubePlayer(
                          controller: controller,
                          aspectRatio: 16 / 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ).then((_) {
          // Asegurarnos de que el controlador se cierre si el diálogo
          // se cierra por cualquier otro método (como tocar fuera)
          try {
            controller.close();
          } catch (e) {
            print('Error closing YouTube player: $e');
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: "https://img.youtube.com/vi/$youtubeId/0.jpg",
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget:
                  (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  // Widget para previsualización de imágenes
  Widget _buildImagePreview(Map<String, dynamic> item, int itemIndex) {
    // Obtener la posición vertical (o usar 0.0 por defecto)
    final double verticalPosition = item['verticalPosition'] ?? 0.0;

    if (item['isLocal'] == true) {
      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Image.file(
                item['file'],
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment(0, verticalPosition),
              ),
            ),
          ),
          // Modificación aquí - usando el parámetro itemIndex recibido
          if (item['type'] == 'image')
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text(
                      'Ajustar posición',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      _showAdjustPositionDialog(item, itemIndex);
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: CachedNetworkImage(
                imageUrl: item['url'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                alignment: Alignment(0, verticalPosition),
                errorWidget:
                    (context, url, error) => Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
              ),
            ),
          ),
          if (item['type'] == 'image') // Solo para imágenes
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text(
                      'Ajustar posición',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      _showAdjustPositionDialog(item, itemIndex);
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  void _showYoutubePlayer(String youtubeId) {
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );

    try {
      controller.loadVideoById(videoId: youtubeId);

      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder:
            (context) => OrientationBuilder(
              builder: (context, orientation) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      controller.close();
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Reproducción de video',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 48,
                                  ), // Balanceo para centrar el título
                                ],
                              ),
                            ),
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: YoutubePlayer(
                                controller: controller,
                                aspectRatio: 16 / 9,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'ID del video: $youtubeId',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
    } catch (e) {
      print('Error al cargar video de YouTube: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar video: $e')));
    }
  }

  void _showDraggableImageAdjustment(Map<String, dynamic> item) {
    double position = item['verticalPosition'] ?? 0.0;
    double initialPosition = position;
    double dragStartY = 0.0;

    showDialog(
      context: context,
      builder:
          (context) => OrientationBuilder(
            builder: (context, orientation) {
              final isLandscape = orientation == Orientation.landscape;

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 8 : 16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Expanded(
                                child: Text(
                                  'Ajustar posición de imagen',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  final int index = widget.mediaItems.indexOf(
                                    item,
                                  );
                                  if (index != -1) {
                                    _updateImagePosition(index, position);
                                  }
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Guardar',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Image preview container with exact dimensions
                        StatefulBuilder(
                          builder: (context, setState) {
                            return Container(
                              height:
                                  250, // Misma altura que en RoomDetailsPage
                              width:
                                  isLandscape
                                      ? MediaQuery.of(context).size.width * 0.6
                                      : MediaQuery.of(context).size.width - 32,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: GestureDetector(
                                onVerticalDragStart: (details) {
                                  dragStartY = details.localPosition.dy;
                                },
                                onVerticalDragUpdate: (details) {
                                  final dragCurrentY = details.localPosition.dy;
                                  final dragDeltaY = dragCurrentY - dragStartY;
                                  final positionDelta =
                                      (dragDeltaY / 250.0) * 0.3;
                                  setState(() {
                                    position = (position + positionDelta).clamp(
                                      -1.0,
                                      1.0,
                                    );
                                  });
                                },
                                child:
                                    item['isLocal'] == true
                                        ? Image.file(
                                          item['file'],
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0, position),
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            print(
                                              'Error al mostrar imagen local: $error',
                                            );
                                            return const Center(
                                              child: Icon(
                                                Icons.error,
                                                color: Colors.red,
                                                size: 50,
                                              ),
                                            );
                                          },
                                        )
                                        : CachedNetworkImage(
                                          imageUrl: item['url'],
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0, position),
                                          memCacheWidth: 720,
                                          memCacheHeight: 720,
                                          fadeInDuration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          errorWidget: (context, url, error) {
                                            print(
                                              'Error al cargar imagen: $error',
                                            );
                                            return const Center(
                                              child: Icon(
                                                Icons.error,
                                                color: Colors.red,
                                                size: 50,
                                              ),
                                            );
                                          },
                                          placeholder:
                                              (context, url) => const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white70,
                                                    ),
                                              ),
                                        ),
                              ),
                            );
                          },
                        ),

                        // Slider control para ajuste fino
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'Desliza para ajustar la posición vertical',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildPositionButton(
    StateSetter setState,
    double currentPosition,
    double targetPos,
    IconData icon,
    String label,
  ) {
    return GestureDetector(
      onTap: () => setState(() => currentPosition = targetPos),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  currentPosition == targetPos ? Colors.blue : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
                  currentPosition == targetPos ? Colors.blue : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar la vista previa del carrusel completo
  void _showCarouselPreview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text(
                      'Vista previa del carrusel',
                      style: TextStyle(color: Colors.white),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Preview explanation
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Así se verá el carrusel en tu sala:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),

                  // Carousel preview
                  Expanded(
                    child: PageView.builder(
                      itemCount: widget.mediaItems.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child:
                              widget.mediaItems[index]['type'] == 'video'
                                  ? _buildCarouselVideoPreview(
                                    widget.mediaItems[index],
                                  )
                                  : _buildCarouselImagePreview(
                                    widget.mediaItems[index],
                                  ),
                        );
                      },
                    ),
                  ),

                  // Instructions footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swipe, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          'Desliza para ver todas las imágenes y videos',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPreviewImageItem(Map<String, dynamic> item) {
    final double verticalPosition = item['verticalPosition'] ?? 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child:
          item['isLocal']
              ? Image.file(
                item['file'],
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment(0, verticalPosition),
              )
              : CachedNetworkImage(
                imageUrl: item['url'],
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment(0, verticalPosition),
                errorWidget:
                    (context, url, error) => Container(
                      height: 250,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
              ),
    );
  }

  Widget _buildPreviewVideoItem(Map<String, dynamic> item) {
    final String youtubeId = item['youtubeId'] ?? '';

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: "https://img.youtube.com/vi/$youtubeId/0.jpg",
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget:
                (context, url, error) => Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.video_library,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            // Mostrar video en pantalla completa
            showDialog(
              context: context,
              barrierColor: Colors.black87,
              builder:
                  (context) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        YoutubePlayer(
                          controller: YoutubePlayerController.fromVideoId(
                            videoId: youtubeId,
                            params: const YoutubePlayerParams(
                              showControls: true,
                              mute: false,
                            ),
                          ),
                          aspectRatio: 16 / 9,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselImagePreview(Map<String, dynamic> item) {
    final double verticalPosition = item['verticalPosition'] ?? 0.0;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child:
            item['isLocal']
                ? Image.file(
                  item['file'],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  alignment: Alignment(0, verticalPosition),
                )
                : CachedNetworkImage(
                  imageUrl: item['url'],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  alignment: Alignment(0, verticalPosition),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 250,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                ),
      ),
    );
  }

  Widget _buildCarouselVideoPreview(Map<String, dynamic> item) {
    final String youtubeId = item['youtubeId'] ?? '';

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: "https://img.youtube.com/vi/$youtubeId/0.jpg",
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              errorWidget:
                  (context, url, error) => Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.video_library,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder:
                    (_) => Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          YoutubePlayer(
                            controller: YoutubePlayerController.fromVideoId(
                              videoId: youtubeId,
                              params: const YoutubePlayerParams(
                                showFullscreenButton: true,
                                showControls: true,
                                mute: false,
                              ),
                            ),
                            aspectRatio: 16 / 9,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/grow_baja_calidad_negro.png',
              height: 150,
              fit: BoxFit.contain,
              errorBuilder:
                  (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported,
                    size: 80,
                    color: Colors.grey,
                  ),
            ),

            const Text(
              'Detalles de la Sala',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: widget.nombreController,
                decoration: _inputStyle('Nombre de la sala *'),
                maxLength: 50,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: widget.descripcionCortaController,
                decoration: _inputStyle('Descripción corta *'),
                maxLength: 100,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: widget.descripcionController,
                decoration: _inputStyle('Descripción detallada *'),
                maxLines: 4,
                maxLength: 1000,
              ),
            ),

            // Sección para agregar videos/imágenes (opcional)
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            const Text(
              'Contenido multimedia (opcional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            const Text(
              'Puedes agregar videos de YouTube o imágenes para mostrar más detalles de tu sala o presentarla aún mejor.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText:
                          _isVideo ? 'URL de YouTube...' : 'URL de imagen...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addMediaItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Añadir',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Video'),
                      selected: _isVideo,
                      onSelected: (selected) {
                        setState(() => _isVideo = selected);
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Imagen'),
                      selected: !_isVideo,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _isVideo = false);
                        }
                      },
                    ),
                  ],
                ),
                if (!_isVideo)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: _mostrarOpcionesDeImagen,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Subir desde el dispositivo'),
                    ),
                  ),
              ],
            ),

            if (widget.mediaItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with preview button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_library, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Multimedia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          // Make preview button more visible
                          ElevatedButton.icon(
                            onPressed: () => _showCarouselPreview(context),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Vista previa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Instructions banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Toca una imagen para ajustar su posición o un video para verlo',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Carousel items
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          for (int i = 0; i < widget.mediaItems.length; i++)
                            GestureDetector(
                              onTap: () {
                                if (widget.mediaItems[i]['type'] == 'image') {
                                  _showDraggableImageAdjustment(
                                    widget.mediaItems[i],
                                  );
                                } else if (widget.mediaItems[i]['type'] ==
                                    'video') {
                                  final String youtubeId =
                                      widget.mediaItems[i]['youtubeId'] ?? '';
                                  if (youtubeId.isNotEmpty) {
                                    _showYoutubePlayer(youtubeId);
                                  }
                                }
                              },
                              child: Container(
                                height: 140,
                                width: 180,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child:
                                          widget.mediaItems[i]['type'] ==
                                                  'video'
                                              ? _buildVideoThumbnail(
                                                widget.mediaItems[i],
                                              )
                                              : _buildImageThumbnail(
                                                widget.mediaItems[i],
                                              ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              widget.mediaItems[i]['type'] ==
                                                      'image'
                                                  ? Colors.blue.withOpacity(0.8)
                                                  : Colors.red.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              widget.mediaItems[i]['type'] ==
                                                      'image'
                                                  ? Icons.tune
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.mediaItems[i]['type'] ==
                                                      'image'
                                                  ? 'Ajustar'
                                                  : 'Ver',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
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
            ],
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: widget.precioController,
                decoration: _inputStyle('Precio mensual (₡) *'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                decoration: _inputStyle('Categoría *'),
                value: widget.selectedCategory,
                items:
                    categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: widget.onCategoryChanged,
              ),
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeHubPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: widget.onNext,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

// Slide 3: Redes Sociales (No changes needed)
class Slide3 extends StatelessWidget {
  final TextEditingController instagramController;
  final TextEditingController facebookController;
  final TextEditingController youtubeController;
  final TextEditingController xController;
  final TextEditingController whatsappController;
  final VoidCallback onNext;

  const Slide3({
    required this.instagramController,
    required this.facebookController,
    required this.youtubeController,
    required this.xController,
    required this.whatsappController,
    required this.onNext,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Redes Sociales de la Sala',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa la información de tus redes sociales para que los usuarios puedan encontrarte',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: instagramController,
                decoration: InputDecoration(
                  labelText: 'Instagram',
                  hintText: 'Solo el nombre de usuario (sin @)',
                  helperText: 'Ejemplo: usuario123',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.camera_alt_outlined),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: facebookController,
                decoration: InputDecoration(
                  labelText: 'Facebook',
                  hintText: 'URL completa o nombre de usuario',
                  helperText: 'Ejemplo: facebook.com/usuario o usuario',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.facebook),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: youtubeController,
                decoration: InputDecoration(
                  labelText: 'YouTube',
                  hintText: 'URL completa del canal',
                  helperText: 'Ejemplo: youtube.com/c/nombrecanal',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.video_library),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: xController,
                decoration: InputDecoration(
                  labelText: 'X (antes Twitter)',
                  hintText: 'Solo el nombre de usuario (sin @)',
                  helperText: 'Ejemplo: usuario123',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: whatsappController,
                decoration: InputDecoration(
                  labelText: 'WhatsApp',
                  hintText: 'Número con código de país',
                  helperText: 'Ejemplo: 506 8123 4567',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeHubPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            // Espacio adicional para que el teclado no oculte contenido
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }
}

// Helper function to select an image (kept as is)
Future<File?> selectImage() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
  ); // o ImageSource.camera

  if (pickedFile != null) {
    return File(pickedFile.path);
  } else {
    return null;
  }
}

class Slide4 extends StatefulWidget {
  final File? portadaImageFile;
  final String? portadaImageUrl;
  final Function(dynamic) onSelectImage;
  final Function(double) onPositionChanged;
  final VoidCallback onNext;
  final double verticalPosition;

  const Slide4({
    this.portadaImageFile,
    this.portadaImageUrl,
    required this.onSelectImage,
    required this.onPositionChanged,
    required this.onNext,
    this.verticalPosition = 0.0,
    super.key,
  });

  @override
  State<Slide4> createState() => _Slide4State();
}

class _Slide4State extends State<Slide4> {
  double _verticalOffset = 0.0;
  final double _containerHeight = 150.0;

  Future<void> _mostrarOpcionesDeImagen() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Seleccionar desde galería'),
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      widget.onSelectImage(File(picked.path));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Tomar una foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (picked != null) {
                      widget.onSelectImage(File(picked.path));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Pegar URL de imagen'),
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoURL();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _mostrarDialogoURL() async {
    String urlTemp = '';
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pegar URL de imagen'),
            content: TextField(
              decoration: const InputDecoration(hintText: 'https://...'),
              onChanged: (value) => urlTemp = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_isValidUrl(urlTemp)) {
                    Navigator.pop(context);
                    widget.onSelectImage(urlTemp);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL inválida')),
                    );
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
  }

  bool _isValidUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.isScheme('http') || uri.isScheme('https'));
  }

  void _quitarImagen() {
    widget.onSelectImage(null);
    setState(() {
      _verticalOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        widget.portadaImageFile != null ||
        (widget.portadaImageUrl != null && widget.portadaImageUrl!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Selecciona una Imagen de Portada',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _mostrarOpcionesDeImagen,
            child: Container(
              height: _containerHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    hasImage
                        ? LayoutBuilder(
                          builder: (context, constraints) {
                            final Widget imageWidget =
                                widget.portadaImageFile != null
                                    ? Image.file(
                                      widget.portadaImageFile!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment(
                                        0,
                                        widget.verticalPosition,
                                      ),
                                    )
                                    : CachedNetworkImage(
                                      imageUrl: widget.portadaImageUrl!,
                                      fit: BoxFit.cover,
                                      alignment: Alignment(
                                        0,
                                        widget.verticalPosition,
                                      ),
                                      errorWidget:
                                          (context, url, error) => Container(
                                            height: 250,
                                            width: double.infinity,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 50,
                                            ),
                                          ),
                                    );
                            return GestureDetector(
                              onVerticalDragUpdate: (details) {
                                setState(() {
                                  final delta =
                                      details.delta.dy /
                                      constraints.maxHeight *
                                      10;
                                  final newOffset =
                                      widget.verticalPosition + delta;
                                  widget.onPositionChanged(
                                    newOffset.clamp(-1.0, 1.0),
                                  );
                                });
                              },
                              child: imageWidget,
                            );
                          },
                        )
                        : const Center(
                          child: Text(
                            'Presiona acá para añadir\nuna imagen de portada.',
                            style: TextStyle(letterSpacing: -.2, fontSize: 16),
                          ),
                        ),
              ),
            ),
          ),
          if (hasImage)
            TextButton.icon(
              onPressed: _quitarImagen,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text(
                'Quitar imagen',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // Reemplazar la navegación actual para evitar que la app se cierre
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const HomeHubPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: widget.onNext,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 30,
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

class Slide4B extends StatelessWidget {
  final TextEditingController sinpePhoneController;
  final TextEditingController sinpeNameController;
  final VoidCallback onNext;

  const Slide4B({
    Key? key,
    required this.sinpePhoneController,
    required this.sinpeNameController,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with elegant styling
            const Text(
              'Información de SINPE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            // Information box with gradient background
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¿Para qué necesitamos estos datos?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Estos datos serán utilizados para transferir los pagos cuando los miembros se unan a tu sala. La información debe coincidir exactamente con la registrada en tu entidad bancaria.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Trust indicators
            Container(
              margin: const EdgeInsets.only(top: 20, bottom: 24),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 20,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu información está segura. Solo utilizaremos tu número de SINPE para poder enviarte el dinero que genere tu sala.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section header for payment info
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Detalles de Pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            // Phone input with refined styling
            TextField(
              controller: sinpePhoneController,
              decoration: InputDecoration(
                labelText: 'Número telefónico para SINPE *',
                hintText: '8888-8888',
                helperText: 'Este número recibirá los pagos de los miembros',
                helperStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.phone, color: Colors.black),
                floatingLabelStyle: const TextStyle(color: Colors.black),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),

            const SizedBox(height: 20),

            // Name input with consistent styling
            TextField(
              controller: sinpeNameController,
              decoration: InputDecoration(
                labelText: 'Nombre para SINPE *',
                hintText: 'Nombre como aparece en tu cuenta bancaria',
                helperText: 'Exactamente como aparece en tu entidad bancaria',
                helperStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.person, color: Colors.black),
                floatingLabelStyle: const TextStyle(color: Colors.black),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 20),

            // FAQ Section
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ExpansionTile(
                leading: Icon(Icons.help_outline, color: Colors.blue.shade700),
                title: const Text(
                  'Preguntas Frecuentes',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFaqItem(
                          '¿Es seguro ingresar mi información SINPE?',
                          'Sí. No almacenamos información sensible.',
                        ),
                        _buildFaqItem(
                          '¿Debo usar mi número principal?',
                          'Debes usar el número que tienes registrado con tu entidad bancaria para SINPE Móvil, de lo contrario los pagos no podrán procesarse correctamente.',
                        ),
                        _buildFaqItem(
                          '¿Cuándo recibiré los pagos?',
                          'Verás los pagos en tu cuenta en un tiempo máximo de 7 a 15 días. Serás notificado cada vez que recibas un pago.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Required fields note
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 24),
              child: Row(
                children: [
                  Text(
                    '* ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red.shade500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Campos obligatorios',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Continue button with elegant styling
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeHubPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class Slide4C extends StatelessWidget {
  final String sinpePhone;
  final String sinpeName;
  final VoidCallback onNext;

  const Slide4C({
    Key? key,
    required this.sinpePhone,
    required this.sinpeName,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con estilo mejorado y badge de verificación
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Confirmación de datos SINPE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info, color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Verificando',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Subtítulo informativo
            Text(
              'Revisamos estos datos para realizar las transferencias',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 30),

            // Información SINPE con diseño destacado
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado del contenedor con gradiente
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF000000), Color(0xFF333333)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Detalles de tu cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido con los datos SINPE
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Número SINPE con destacado
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.phone_android,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Número SINPE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          sinpePhone,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
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

                        const SizedBox(height: 20),

                        // Nombre SINPE con destacado
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nombre del titular',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sinpeName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Información de proceso de pago
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado con gradiente
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF000000), Color(0xFF333333)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Proceso de pagos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pasos del proceso de pago
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProcessStep(
                          1,
                          "Pago inicial",
                          "El usuario solicita unirse a la sala y hace el pago correspondiente a GROW.",
                          Colors.black,
                        ),
                        const SizedBox(height: 20),
                        _buildProcessStep(
                          2,
                          "Verificación",
                          "El equipo de GROW verifica y aprueba la solicitud de ingreso a tu sala y el pago.",
                          Colors.black,
                        ),
                        const SizedBox(height: 20),
                        _buildProcessStep(
                          3,
                          "Transferencia",
                          "Una vez aprobada, el equipo de GROW transfiere el monto correspondiente a tu cuenta SINPE.",
                          Colors.green.shade400,
                        ),
                        const SizedBox(height: 20),

                        // Destacar la seguridad
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.security,
                                  size: 20,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Este proceso nos ayuda a prevenir fraudes y garantizar que todas las transacciones sean seguras.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Botón de continuar con estilo mejorado y sombra
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeHubPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method para construir cada paso del proceso con colores personalizados
  Widget _buildProcessStep(
    int number,
    String title,
    String description,
    Color accentColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Slide 5: Resumen y Confirmación (Updated with Category display and explanation for onCreate)
class Slide5 extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController descripcionCortaController;
  final TextEditingController descripcionController;
  final TextEditingController precioController;
  final TextEditingController instagramController;
  final TextEditingController facebookController;
  final TextEditingController youtubeController;
  final TextEditingController xController;
  final TextEditingController whatsappController;
  final double imageVerticalPosition;
  final List<Map<String, dynamic>> mediaItems;
  final bool isSubmitting;

  final String? selectedCategory;

  final File? portadaImageFile;
  final String? portadaImageUrl;
  final String sinpePhone;
  final String sinpeName;
  final VoidCallback onCreate;

  const Slide5({
    required this.nombreController,
    required this.descripcionCortaController,
    required this.descripcionController,
    required this.precioController,
    required this.instagramController,
    required this.facebookController,
    required this.youtubeController,
    required this.xController,
    required this.whatsappController,
    required this.selectedCategory,
    required this.portadaImageFile,
    required this.portadaImageUrl,
    required this.imageVerticalPosition,
    required this.isSubmitting,
    required this.mediaItems,
    required this.onCreate,
    required this.sinpePhone,
    required this.sinpeName,
    super.key,
  });

  Widget _buildSocialMediaCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(6), // Reducido de 10 a 6
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22), // Reducido de 28 a 22
            const SizedBox(height: 4), // Reducido de 8 a 4
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ), // Reducido tamaño
            ),
            const SizedBox(height: 2), // Reducido de 4 a 2
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10), // Reducido de 12 a 10
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselImagePreview(Map<String, dynamic> item) {
    final double verticalPosition = item['verticalPosition'] ?? 0.0;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child:
            item['isLocal']
                ? Image.file(
                  item['file'],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  alignment: Alignment(0, verticalPosition),
                )
                : CachedNetworkImage(
                  imageUrl: item['url'],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  alignment: Alignment(0, verticalPosition),
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
                ),
      ),
    );
  }

  Widget _buildCarouselVideoPreview(String youtubeId, BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: "https://img.youtube.com/vi/$youtubeId/0.jpg",
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder:
                  (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showYoutubePlayer(context, youtubeId);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showYoutubePlayer(BuildContext context, String youtubeId) {
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );

    try {
      controller.loadVideoById(videoId: youtubeId);

      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder:
            (context) => OrientationBuilder(
              builder: (context, orientation) {
                return Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: orientation == Orientation.landscape ? 24 : 80,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: YoutubePlayer(controller: controller),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'ID del video: $youtubeId',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
    } catch (e) {
      print('Error al cargar video de YouTube: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar video: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        portadaImageFile != null ||
        (portadaImageUrl != null && portadaImageUrl!.isNotEmpty);

    // Helper to check if a social media field has content
    bool hasSocialMedia =
        instagramController.text.isNotEmpty ||
        facebookController.text.isNotEmpty ||
        youtubeController.text.isNotEmpty ||
        xController.text.isNotEmpty ||
        whatsappController.text.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo Grow
          // Make sure the path 'assets/grow_baja_calidad_negro.png' is correct
          // and the image is included in your pubspec.yaml assets section.
          Image.asset(
            'assets/grow_baja_calidad_negro.png',
            height: 110,
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) => const Icon(
                  Icons.image_not_supported,
                  size: 110,
                ), // Fallback icon
          ),

          const SizedBox(height: 20),

          const Text(
            'Este es el resumen de tu sala. Revísalo.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // SECCIÓN: Portada
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Portada de la Sala',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Esta será la imagen principal que representará visualmente la sala.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 10),
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 150.0,
                width: double.infinity,
                child:
                    portadaImageFile != null
                        ? Image.file(
                          portadaImageFile!,
                          fit: BoxFit.cover,
                          alignment: Alignment(0, imageVerticalPosition),
                        )
                        : Image.network(
                          portadaImageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment(0, imageVerticalPosition),
                          errorBuilder:
                              (context, error, stackTrace) => const Center(
                                child: Icon(Icons.error, color: Colors.red),
                              ),
                        ),
              ),
            )
          else
            const Text(
              'No se ha seleccionado imagen de portada',
              style: TextStyle(color: Colors.black54),
            ),

          const SizedBox(height: 30),

          // SECCIÓN: Información General
          const Align(
            alignment: Alignment.center,
            child: Text(
              'INFORMACIÓN GENERAL',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          _buildInfoCard(
            'Nombre de la Sala',
            'Nombre visible para los usuarios.',
            nombreController.text,
          ),
          _buildInfoCard(
            'Descripción Corta',
            'Se muestra como resumen o subtítulo.',
            descripcionCortaController.text,
          ),
          _buildInfoCard(
            'Descripción Detallada',
            'Explica a fondo de qué trata la sala.',
            descripcionController.text,
          ),
          _buildInfoCard(
            'Precio (₡)',
            'Costo de acceso mensual (en colones) a esta sala.',
            precioController.text.isNotEmpty ? precioController.text : '0.00',
          ), // Display 0.00 if empty
          // New: Display Category
          _buildInfoCard(
            'Categoría',
            'Clasifica la sala según su temática principal.',
            selectedCategory ?? 'No especificado',
          ),

          const SizedBox(height: 30),

          // Container para la información SINPE
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del contenedor
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Detalles de tu cuenta SINPE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido con los datos SINPE
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Número SINPE
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.phone_android,
                              color: Colors.black,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Número SINPE',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sinpePhone,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Nombre SINPE
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nombre del titular',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sinpeName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
          const SizedBox(height: 30),
          if (mediaItems.isNotEmpty) ...[
            const SizedBox(height: 30),

            const Align(
              alignment: Alignment.center,
              child: Text(
                'CONTENIDO MULTIMEDIA',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),

            // Carrusel de imágenes y videos
            Container(
              height: 250,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: PageView.builder(
                itemCount: mediaItems.length,
                itemBuilder: (context, index) {
                  final item = mediaItems[index];

                  // Si es un video de YouTube
                  if (item['type'] == 'video') {
                    final youtubeId = item['youtubeId'] ?? '';
                    return _buildCarouselVideoPreview(youtubeId, context);
                  }
                  // Si es una imagen
                  else {
                    return _buildCarouselImagePreview(item);
                  }
                },
              ),
            ),

            // Indicador de cantidad de elementos
            Text(
              '${mediaItems.length} elementos multimedia',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // SECCIÓN: Redes Sociales
          const Align(
            alignment: Alignment.center,
            child: Text(
              'REDES SOCIALES',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          if (hasSocialMedia) ...[
            // Grid de redes sociales
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3, // Aumentado de 2 a 3 columnas
              mainAxisSpacing: 8, // Reducido de 10 a 8
              crossAxisSpacing: 8, // Reducido de 10 a 8
              childAspectRatio: 1.5, // Aumentado de 1.3 a 1.5
              children: [
                if (instagramController.text.isNotEmpty)
                  _buildSocialMediaCard(
                    'Instagram',
                    instagramController.text,
                    Icons.camera_alt,
                    Colors.purple.shade400,
                  ),
                if (facebookController.text.isNotEmpty)
                  _buildSocialMediaCard(
                    'Facebook',
                    facebookController.text,
                    Icons.facebook,
                    Colors.blue.shade700,
                  ),
                if (youtubeController.text.isNotEmpty)
                  _buildSocialMediaCard(
                    'YouTube',
                    youtubeController.text,
                    Icons.play_circle_fill,
                    Colors.red,
                  ),
                if (xController.text.isNotEmpty)
                  _buildSocialMediaCard(
                    'X',
                    xController.text,
                    FontAwesomeIcons.xTwitter,
                    Colors.black,
                  ),
                if (whatsappController.text.isNotEmpty)
                  _buildSocialMediaCard(
                    'WhatsApp',
                    whatsappController.text,
                    FontAwesomeIcons.whatsapp,
                    Colors.green,
                  ),
              ],
            ),
          ] else
            const Text(
              'No se han especificado redes sociales.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),

          const SizedBox(height: 30),

          // SECCIÓN: Acción Final
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Confirmar y Crear Sala',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Si ha revisado toda la información y está listo para crear la sala, haga clic en el botón de abajo.\nUna vez confirmada, será enviada para aprobación.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // The onCreate callback is triggered here.
          // The parent widget must implement the logic to save to Firebase.
          Stack(
            alignment: Alignment.center,
            children: [
              // The button
              GestureDetector(
                onTap: isSubmitting ? null : onCreate,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSubmitting ? Colors.grey : Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      isSubmitting
                          ? const SizedBox(width: 30, height: 30)
                          : const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          ),
                ),
              ),
              // Loading spinner overlay
              if (isSubmitting)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40), // Add some space at the bottom
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            // Display "No especificado" if value is null or empty
            value.isNotEmpty ? value : 'No especificado',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class Slide5b extends StatefulWidget {
  final VoidCallback onContinue;
  final Function(File) onProcessRoom;

  const Slide5b({
    required this.onContinue,
    required this.onProcessRoom,
    Key? key,
  }) : super(key: key);

  @override
  State<Slide5b> createState() => _Slide5bState();
}

class _Slide5bState extends State<Slide5b> {
  File? _comprobanteFile;
  bool _isUploading = false;

  Future<void> _selectComprobante() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _comprobanteFile = File(pickedFile.path);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se seleccionó ningún archivo')),
      );
    }
  }

  Future<void> _updateFinancialData(Map<String, dynamic> paymentData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get current date for month/year filtering
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    try {
      // Check if a payment record already exists for this room and type
      final existingPaymentQuery =
          await FirebaseFirestore.instance
              .collection('payments')
              .where('roomId', isEqualTo: paymentData['roomId'])
              .where('paymentType', isEqualTo: 'room_creation')
              .limit(1)
              .get();

      // Only create the payment record if no existing record found
      if (existingPaymentQuery.docs.isEmpty) {
        // 1. Add payment record with month and year fields
        final paymentRef = await FirebaseFirestore.instance
            .collection('payments')
            .add({
              'amount': paymentData['amount'],
              'roomId': paymentData['roomId'],
              'roomName': paymentData['roomName'],
              'userId': currentUser.uid,
              'userName': paymentData['userName'],
              'userPhoto': paymentData['userPhoto'] ?? '',
              'timestamp': paymentData['timestamp'],
              'status': 'received',
              'paymentType': 'room_creation',
              'month': month,
              'year': year,
            });

        // 2. Create finance notification
        await FirebaseFirestore.instance.collection('finance_notifications').add({
          'title': 'Nuevo pago recibido',
          'body':
              'Se ha recibido ₡${paymentData['amount']} por la creación de la sala "${paymentData['roomName']}"',
          'userId': currentUser.uid,
          'userName': paymentData['userName'],
          'userPhoto': paymentData['userPhoto'] ?? '',
          'amount': paymentData['amount'],
          'roomId': paymentData['roomId'],
          'roomName': paymentData['roomName'],
          'timestamp': paymentData['timestamp'],
          'read': false,
          'type': 'payment_received',
        });

        // 3. Update finance summary
        final financesRef = FirebaseFirestore.instance
            .collection('finances')
            .doc('summary');
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final financeSnapshot = await transaction.get(financesRef);

          if (financeSnapshot.exists) {
            final financeData = financeSnapshot.data() as Map<String, dynamic>;

            // Get current values
            double ganancias =
                (financeData['ganancias'] as num?)?.toDouble() ?? 0;

            // Update values
            transaction.update(financesRef, {
              'ganancias': ganancias + paymentData['amount'],
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            // Create initial document if it doesn't exist
            transaction.set(financesRef, {
              'ganancias': paymentData['amount'],
              'porDevolver': 0,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        });

        // 4. Add to earnings history
        await FirebaseFirestore.instance.collection('earnings_history').add({
          'amount': paymentData['amount'],
          'description':
              'Pago por creación de sala: ${paymentData['roomName']}',
          'userId': currentUser.uid,
          'userName': paymentData['userName'],
          'userPhoto': paymentData['userPhoto'] ?? '',
          'roomId': paymentData['roomId'],
          'roomName': paymentData['roomName'],
          'timestamp': paymentData['timestamp'],
          'type': 'income',
          'category': 'room_creation',
          'month': month, // Add month field for filtering
          'year': year, // Add year field for filtering
        });
      } else {
        print(
          'Payment record already exists for this room. Skipping creation.',
        );
      }
    } catch (e) {
      print('Error updating financial data: $e');
      throw e; // Re-throw to allow handling in the calling function
    }
  }

  Future<void> _uploadComprobanteAndContinue() async {
    // Check if file exists
    if (_comprobanteFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un comprobante primero'),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      print('Iniciando carga de comprobante: ${_comprobanteFile!.path}');
      print('Tamaño original: ${await _comprobanteFile!.length()} bytes');

      // Comprimir imagen - maneja el caso en que la compresión falle
      print('Comprimiendo imagen...');
      final compressedComprobante = await compressImage(_comprobanteFile!);
      final fileToUpload = compressedComprobante ?? _comprobanteFile!;
      print(
        'Tamaño después de compresión: ${await fileToUpload.length()} bytes',
      );

      // Verificar que el archivo existe y es accesible
      if (!await fileToUpload.exists()) {
        throw 'El archivo no existe o no es accesible';
      }

      // Usar .webp en lugar de .jpg para mantener consistencia con el formato de compresión
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
      print('Subiendo a Firebase Storage: comprobantes/$fileName');

      // Subir a Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'comprobantes/$fileName',
      );

      // Usar putData en lugar de putFile para evitar problemas de acceso al archivo
      final bytes = await fileToUpload.readAsBytes();
      print('Bytes leídos: ${bytes.length}');

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/webp'),
      );

      final comprobanteUrl = await uploadTask.ref.getDownloadURL();
      print('URL obtenida: $comprobanteUrl');

      if (comprobanteUrl.isEmpty) throw 'Error al obtener URL del comprobante';

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'Usuario no autenticado';

      // Obtener datos de usuario
      print('Obteniendo datos de usuario...');
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) throw 'Perfil de usuario no encontrado';
      final userData = userDoc.data() ?? {};

      // En lugar de buscar una sala existente, procesamos la sala nueva
      widget.onProcessRoom(_comprobanteFile!);

      // Continuamos al siguiente slide
      widget.onContinue();

      print('Proceso completado con éxito');
    } catch (e) {
      print('Error en _uploadComprobanteAndContinue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el comprobante: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Mostrar diálogo de confirmación
        bool shouldPop =
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Cancelar proceso'),
                    content: const Text(
                      '¿Deseas cancelar el proceso de creación de sala?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Sí'),
                      ),
                    ],
                  ),
            ) ??
            false;

        return shouldPop;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pago de Suscripción',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Para activar tu sala, es necesario realizar un ',
                  ),
                  TextSpan(
                    text: 'pago único de ₡10,000',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            const Text(
              'INSTRUCCIONES DE PAGO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Realiza una transferencia o SINPE Móvil a:\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Nombre: '),
                  TextSpan(
                    text: 'Joseph Carazo Pena\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Cédula: '),
                  TextSpan(
                    text: '504490109\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Cuenta IBAN: '),
                  TextSpan(
                    text: 'CR53015102420010234812\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: 'Teléfono: '),
                  TextSpan(
                    text: '+506 8662 2488',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text.rich(
              TextSpan(
                text: 'Banco Nacional de Costa Rica',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Añade el nombre '),
                  TextSpan(
                    text: '"SALA GROW"',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' en el detalle del pago'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Una vez realizado el pago, sube el comprobante:\n',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        '(Puede ser una captura de pantalla del recibo o comprobante)',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Divider(height: 0, thickness: 1, color: Colors.black),
            const SizedBox(height: 20),
            const Text.rich(
              TextSpan(
                text:
                    'IMPORTANTE: Tu sala será revisada y aprobada en un plazo máximo de 24 horas.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_comprobanteFile != null) ...[
              Container(
                width: double.infinity,
                height: 420, // Increased from likely 100-150px to 250px
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_comprobanteFile!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Selecciona una imagen desde tu galería:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _selectComprobante,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar Comprobante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12), // Espacio entre botones
                ElevatedButton.icon(
                  onPressed:
                      _isUploading || _comprobanteFile == null
                          ? null
                          : _uploadComprobanteAndContinue,
                  icon:
                      _isUploading
                          ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                          : const Icon(Icons.check_circle),
                  label: Text(_isUploading ? 'Enviando...' : 'Confirmar Pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Slide6 extends StatefulWidget {
  final VoidCallback onFinish;

  const Slide6({required this.onFinish, super.key});

  @override
  _Slide6State createState() => _Slide6State();
}

class _Slide6State extends State<Slide6> {
  late int _remainingSeconds;
  late double _progress;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 300; // 5 minutes in seconds
    _progress = 1.0; // Full progress
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _progress = _remainingSeconds / 300; // Update progress
        });
      } else {
        _timer.cancel();
        widget.onFinish(); // Call the finish callback when time is up
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _clearImageCache(); // Clear image cache when disposing
    super.dispose();
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, size: 100, color: Colors.orange),
          const SizedBox(height: 20),
          const Text(
            '¡Tu sala está en revisión!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'El proceso puede tardar hasta 5 minutos. Una vez aprobada, recibirás una notificación.',
            style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white,
            color: Colors.green,
            minHeight: 10,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: widget.onFinish,
            label: const Text('Finalizar', style: TextStyle(fontSize: 17)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// This is the main PageView widget managing the state and slides
class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  _AddRoomPageState createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  late final PageController _pageController;
  final _pageViewKey = GlobalKey();
  int _currentPage = 0;
  double _imageVerticalPosition = 0.0;
  bool _isSubmitting = false;
  bool _isRequestSent = false;
  File? _comprobanteFile;
  List<Map<String, dynamic>> _mediaItems = [];

  String _sinpePhone = '';
  String _sinpeName = '';

  // Controllers for text fields
  final TextEditingController _sinpePhoneController = TextEditingController();
  final TextEditingController _sinpeNameController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionCortaController =
      TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();

  String? _selectedCategory;
  File? _portadaImageFile;
  String? _portadaImageUrl;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  bool _validateSlide2() {
    if (_nombreController.text.isEmpty ||
        _descripcionCortaController.text.isEmpty ||
        _descripcionController.text.isEmpty ||
        _precioController.text.isEmpty ||
        _selectedCategory == null) {
      return false;
    }
    return double.tryParse(_precioController.text) != null;
  }

  bool _validateSlide3() => true;

  bool _validateSlide4() {
    return _portadaImageFile != null ||
        (_portadaImageUrl != null && _portadaImageUrl!.isNotEmpty);
  }

  bool _validateSlide1() => true;

  bool _validateSlide4B() {
    // Validate SINPE information (both fields are required)
    return _sinpePhoneController.text.isNotEmpty &&
        _sinpeNameController.text.isNotEmpty;
  }

  void _nextPage(int currentPage) {
    bool isValid = true;

    switch (currentPage) {
      case 1:
        isValid = _validateSlide2();
        break;
      case 2:
        isValid = _validateSlide3();
        break;
      case 3:
        isValid = _validateSlide4();
        break;
      case 4:
        isValid = _validateSlide4B();
        // Update the SINPE values when validated
        if (isValid) {
          _sinpePhone = _sinpePhoneController.text;
          _sinpeName = _sinpeNameController.text;
        }
        break;
    }

    if (isValid) {
      if (_currentPage < 8) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
        setState(() {
          _currentPage++;
        });
      }
    } else {
      _showErrorMessage();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  void _showErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Por favor, complete todos los campos obligatorios.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _handleImageSelection(dynamic image) {
    setState(() {
      if (image == null) {
        _portadaImageFile = null;
        _portadaImageUrl = null;
      } else if (image is File) {
        _portadaImageFile = image;
        _portadaImageUrl = null;
      } else if (image is String) {
        _portadaImageUrl = image;
        _portadaImageFile = null;
      }
    });
  }

  Future<String?> uploadImageToFirebase(File imageFile) async {
    try {
      // Comprime la imagen antes de subirla
      File? compressedFile = await compressImage(imageFile);
      final fileToUpload = compressedFile ?? imageFile;

      // Muestra en consola la información del tamaño para comparar
      final originalSize = await imageFile.length();
      final compressedSize = await fileToUpload.length();
      print('Tamaño original: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      print(
        'Tamaño comprimido: ${(compressedSize / 1024).toStringAsFixed(2)} KB',
      );
      print(
        'Reducción: ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(2)}%',
      );

      // Sube la imagen comprimida
      final storageRef = FirebaseStorage.instance.ref().child(
        'room_covers/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadTask = await storageRef.putFile(fileToUpload);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error al comprimir/subir imagen: $e');
      return null;
    }
  }

  Future<void> _sendNotification({
    required String title,
    required String body,
    required String userId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> _updateFinancialData(Map<String, dynamic> paymentData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get current date for month/year filtering
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    try {
      // 1. Add month and year fields to payment data
      final enhancedPaymentData = {
        ...paymentData,
        'month': month,
        'year': year,
      };

      // 2. Create payment record
      final paymentRef = await FirebaseFirestore.instance
          .collection('payments')
          .add(enhancedPaymentData);

      // 3. Create finance notification
      await FirebaseFirestore.instance.collection('finance_notifications').add({
        'type': 'payment_received',
        'paymentId': paymentRef.id,
        'userId': currentUser.uid,
        'userName': paymentData['userName'] ?? 'Usuario',
        'userPhoto': paymentData['userPhoto'] ?? '',
        'roomId': paymentData['roomId'],
        'roomName': paymentData['roomName'],
        'amount': paymentData['amount'],
        'timestamp': paymentData['timestamp'],
        'read': false,
        'month': month,
        'year': year,
      });

      // 4. Update finance summary
      final financesRef = FirebaseFirestore.instance
          .collection('finances')
          .doc('summary');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final financeSnapshot = await transaction.get(financesRef);

        final amount = paymentData['amount'] ?? 0.0;

        if (financeSnapshot.exists) {
          final data = financeSnapshot.data() as Map<String, dynamic>;
          final currentGanancias =
              (data['ganancias'] as num?)?.toDouble() ?? 0.0;
          final currentIngresos =
              (data['ingresosTotales'] as num?)?.toDouble() ?? 0.0;

          transaction.update(financesRef, {
            'ganancias': currentGanancias + amount,
            'ingresosTotales': currentIngresos + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(financesRef, {
            'ganancias': amount,
            'ingresosTotales': amount,
            'porDevolver': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // 5. Add to earnings history
      await FirebaseFirestore.instance.collection('earnings_history').add({
        'amount': paymentData['amount'],
        'description': 'Pago por creación de sala: ${paymentData['roomName']}',
        'userId': currentUser.uid,
        'userName': paymentData['userName'],
        'userPhoto': paymentData['userPhoto'] ?? '',
        'roomId': paymentData['roomId'],
        'roomName': paymentData['roomName'],
        'timestamp': paymentData['timestamp'],
        'type': 'income',
        'category': 'room_creation',
        'month': month,
        'year': year,
      });
    } catch (e) {
      print('Error updating financial data: $e');
      // You can rethrow or handle the error as needed
    }
  }

  Future<void> _onCreateRoomApproval() async {
    if (_isSubmitting) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Procesando solicitud...')));
      return;
    }

    // Solo guardar la información de SINPE y navegar
    setState(() {
      _isSubmitting = true;
      _sinpePhone = _sinpePhoneController.text;
      _sinpeName = _sinpeNameController.text;
    });

    // Navegar a la pantalla de comprobante
    _pageController.animateToPage(
      7, // Índice de Slide5b
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    setState(() => _isSubmitting = false);
  }

  // Nuevo método para procesar la creación de la sala
  Future<void> _processRoomCreation(File comprobanteFile) async {
    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'Usuario no autenticado';
      }

      // Obtener datos del usuario
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) {
        throw 'Perfil de usuario no encontrado';
      }

      // Subir imagen de portada si es necesario
      if (_portadaImageFile != null) {
        _portadaImageUrl = await uploadImageToFirebase(_portadaImageFile!);
      }

      // Procesar elementos multimedia
      List<Map<String, dynamic>> processedMediaItems = [];
      for (var item in _mediaItems) {
        if (item['type'] == 'image' && item['isLocal'] == true) {
          String? imageUrl = await uploadImageToFirebase(item['file']);
          if (imageUrl != null) {
            processedMediaItems.add({'type': 'image', 'url': imageUrl});
          }
        } else {
          processedMediaItems.add(item);
        }
      }

      // Obtener fecha actual y calcular fechas del ciclo de vida de la sala
      final now = DateTime.now();
      final timestamp = Timestamp.now();

      // La expiración ocurre al final del mes actual
      final expirationDate = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(days: 1));

      // El período de gracia comienza inmediatamente después de la expiración
      final gracePeriodStart = expirationDate.add(const Duration(days: 1));

      // La eliminación ocurre 15 días después del inicio del período de gracia
      final deletionDate = gracePeriodStart.add(const Duration(days: 15));

      // Obtener mes y año para filtrado de registros financieros
      final month = now.month;
      final year = now.year;

      // Comprimir el comprobante
      final compressedComprobante = await compressImage(comprobanteFile);
      final fileToUpload = compressedComprobante ?? comprobanteFile;

      // Subir comprobante a Firebase Storage
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
      final storageRef = FirebaseStorage.instance.ref().child(
        'comprobantes/$fileName',
      );

      final bytes = await fileToUpload.readAsBytes();
      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/webp'),
      );

      final comprobanteUrl = await uploadTask.ref.getDownloadURL();

      final userData = userDoc.data()!;
      final roomData = {
        'name': _nombreController.text,
        'shortDescription': _descripcionCortaController.text,
        'longDescription': _descripcionController.text,
        'price': double.parse(_precioController.text),
        'discount': 0,
        'category': _selectedCategory,
        'creatorUid': currentUser.uid,
        'creatorName': userData['name'] ?? 'Usuario',
        'creatorPhoto': userData['photoURL'] ?? '',
        'socialMedia': {
          'instagram': _instagramController.text,
          'facebook': _facebookController.text,
          'youtube': _youtubeController.text,
          'x': _xController.text,
          'whatsapp': _whatsappController.text,
        },
        'coverImage': _portadaImageUrl,
        'imagePosition': _imageVerticalPosition,
        'mediaItems': processedMediaItems,
        'approvalStatus': 'Pending',
        'paymentStatus': 'Revisar',
        'memberCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastPaidAt': Timestamp.fromDate(now),
        'expirationDate': Timestamp.fromDate(expirationDate),
        'gracePeriodStart': Timestamp.fromDate(gracePeriodStart),
        'deletionDate': Timestamp.fromDate(deletionDate),
        'status': 'Revisar', // Comienza en estado de revisión
        'sinpeInfo': {'phone': _sinpePhone, 'name': _sinpeName},
        'comprobanteUrl': comprobanteUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'admins': [
          {
            'id': currentUser.uid,
            'name': userData['name'] ?? 'Usuario',
            'email': userData['email'] ?? '',
            'photoUrl': userData['photoURL'] ?? '',
            'isCreator': true,
            'isAdmin': true,
            'addedAt': FieldValue.serverTimestamp(),
          }
        ],
      };

      // Crear la sala pendiente
      final roomRef = await FirebaseFirestore.instance
          .collection('pendingRooms')
          .add(roomData);

      // Resto del código para registros financieros...
      const paymentAmount = 10000.0; // Monto fijo para creación de salas

      // 1. Registrar el comprobante
      await FirebaseFirestore.instance.collection('comprobantes').add({
        'roomId': roomRef.id,
        'userId': currentUser.uid,
        'comprobanteUrl': comprobanteUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'roomName': roomData['name'] ?? 'Sin título',
        'category': roomData['category'] ?? 'Sin categoría',
      });

      // 2. Enviar notificación
      await _sendNotification(
        title: 'Solicitud en proceso',
        body:
            'Tu sala "${_nombreController.text}" está en proceso de aprobación.',
        userId: currentUser.uid,
      );

      setState(() {
        _isRequestSent = true;
      });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nombreController.dispose();
    _descripcionCortaController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    _xController.dispose();
    _whatsappController.dispose();
    _sinpePhoneController.dispose();
    _sinpeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detectar si el teclado está visible para optimizar renderizado
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return WillPopScope(
      onWillPop: () async {
        // No mostrar diálogo en primera slide
        if (_currentPage == 0) return true;

        // Mostrar diálogo de confirmación
        bool shouldExit =
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('¿Salir sin guardar?'),
                    content: const Text('Perderás los cambios no guardados.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                          // Navigate to home_hub when user confirms exit
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/home_hub');
                        },
                        child: const Text('Salir'),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (shouldExit) {
          // Navegar de vuelta al hub
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeHubPage()),
          );
          return false; // Prevenir comportamiento predeterminado del botón atrás
        }
        return false; // Permanecer en la página actual
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar:
            _currentPage > 0
                ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      // Show confirmation dialog
                      bool shouldExit =
                          await showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('¿Salir sin guardar?'),
                                  content: const Text(
                                    'Perderás los cambios no guardados.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () =>
                                              Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                        // Navigate to home_hub when user confirms exit
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/home_hub');
                                      },
                                      child: const Text('Salir'),
                                    ),
                                  ],
                                ),
                          ) ??
                          false;
                    },
                  ),
                  title: const Text('Crear Sala'),
                )
                : null,
        body: Focus(
          // Wrapper para mejor gestión de foco
          onFocusChange: (hasFocus) {
            if (!hasFocus && isKeyboardVisible) {
              // Si pierde el foco mientras el teclado está visible, esperar
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted) FocusScope.of(context).requestFocus();
              });
            }
          },
          child: RepaintBoundary(
            // Evita reconstrucciones innecesarias
            child: PageView.builder(
              key: _pageViewKey,
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9, // Número total de páginas
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                // Solo construir la página actual para mejorar rendimiento
                if (index != _currentPage) {
                  return Container(); // Devolver contenedor vacío para páginas no visibles
                }

                // Simplificar UI cuando el teclado está visible para reducir carga
                if (isKeyboardVisible) {
                  // Reducir complejidad visual durante entrada de teclado
                  switch (index) {
                    case 0:
                      return Slide1(
                        key: ValueKey('slide1-$index'),
                        onNext: () => _nextPage(0),
                      );
                    case 1:
                      return Slide2(
                        key: ValueKey('slide2-$index'),
                        nombreController: _nombreController,
                        descripcionCortaController: _descripcionCortaController,
                        descripcionController: _descripcionController,
                        precioController: _precioController,
                        selectedCategory: _selectedCategory,
                        onCategoryChanged:
                            (value) =>
                                setState(() => _selectedCategory = value),
                        mediaItems: _mediaItems,
                        onMediaItemsChanged:
                            (items) => setState(() => _mediaItems = items),
                        onNext: () => _nextPage(1),
                      );
                    case 2:
                      return Slide3(
                        key: ValueKey('slide3-$index'),
                        instagramController: _instagramController,
                        facebookController: _facebookController,
                        youtubeController: _youtubeController,
                        xController: _xController,
                        whatsappController: _whatsappController,
                        onNext: () => _nextPage(2),
                      );
                    // Resto de casos similares
                    default:
                      return Container();
                  }
                }

                // UI completa para cuando el teclado no está visible
                switch (index) {
                  case 0:
                    return Slide1(
                      key: ValueKey('slide1-$index'),
                      onNext: () => _nextPage(0),
                    );
                  case 1:
                    return Slide2(
                      key: ValueKey('slide2-$index'),
                      nombreController: _nombreController,
                      descripcionCortaController: _descripcionCortaController,
                      descripcionController: _descripcionController,
                      precioController: _precioController,
                      selectedCategory: _selectedCategory,
                      onCategoryChanged:
                          (value) => setState(() => _selectedCategory = value),
                      mediaItems: _mediaItems,
                      onMediaItemsChanged:
                          (items) => setState(() => _mediaItems = items),
                      onNext: () => _nextPage(1),
                    );
                  case 2:
                    return Slide3(
                      key: ValueKey('slide3-$index'),
                      instagramController: _instagramController,
                      facebookController: _facebookController,
                      youtubeController: _youtubeController,
                      xController: _xController,
                      whatsappController: _whatsappController,
                      onNext: () => _nextPage(2),
                    );
                  case 3:
                    return Slide4(
                      key: ValueKey('slide4-$index'),
                      portadaImageFile: _portadaImageFile,
                      portadaImageUrl: _portadaImageUrl,
                      onSelectImage: _handleImageSelection,
                      onPositionChanged:
                          (position) =>
                              setState(() => _imageVerticalPosition = position),
                      onNext: () => _nextPage(3),
                      verticalPosition: _imageVerticalPosition,
                    );
                  case 4:
                    return Slide4B(
                      key: ValueKey('slide4b-$index'),
                      sinpePhoneController: _sinpePhoneController,
                      sinpeNameController: _sinpeNameController,
                      onNext: () => _nextPage(4),
                    );
                  case 5:
                    return Slide4C(
                      key: ValueKey('slide4c-$index'),
                      sinpePhone: _sinpePhone,
                      sinpeName: _sinpeName,
                      onNext: () => _nextPage(5),
                    );
                  case 6:
                    return Slide5(
                      key: ValueKey('slide5-$index'),
                      nombreController: _nombreController,
                      descripcionCortaController: _descripcionCortaController,
                      descripcionController: _descripcionController,
                      precioController: _precioController,
                      instagramController: _instagramController,
                      facebookController: _facebookController,
                      youtubeController: _youtubeController,
                      xController: _xController,
                      whatsappController: _whatsappController,
                      selectedCategory: _selectedCategory,
                      portadaImageFile: _portadaImageFile,
                      portadaImageUrl: _portadaImageUrl,
                      imageVerticalPosition: _imageVerticalPosition,
                      isSubmitting: _isSubmitting,
                      mediaItems: _mediaItems,
                      sinpePhone: _sinpePhoneController.text,
                      sinpeName: _sinpeNameController.text,
                      onCreate: _onCreateRoomApproval,
                    );
                  case 7:
                    return Slide5b(
                      key: ValueKey('slide5b-$index'),
                      onContinue: () => _nextPage(7),
                      onProcessRoom: (comprobanteFile) {
                        _processRoomCreation(comprobanteFile);
                      },
                    );
                  case 8:
                    return Slide6(
                      key: ValueKey('slide6-$index'),
                      onFinish: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomeHubPage(),
                          ),
                        );
                      },
                    );
                  default:
                    return Container();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
