import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:grow/screens/room_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../rooms/fitness/room_fitness_home_page.dart';
import '../widgets/drawer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  bool isLoading = false;
  Map<String, dynamic>? userData;
  File? _newProfileImage;
  File? _newCoverImage;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController instagramController = TextEditingController();
  final TextEditingController twitterController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        setState(() {
          userData = doc.data();
          nameController.text = userData?['name'] ?? '';
          descriptionController.text = userData?['description'] ?? '';
          facebookController.text = userData?['socials']?['facebook'] ?? '';
          instagramController.text = userData?['socials']?['instagram'] ?? '';
          twitterController.text = userData?['socials']?['twitter'] ?? '';
          whatsappController.text = userData?['socials']?['whatsapp'] ?? '';

          // Cargar offsets guardados
          if (userData?['coverOffset'] != null) {
            _coverImageOffset = Offset(
              userData!['coverOffset']['dx'] ?? 0.0,
              userData!['coverOffset']['dy'] ?? 0.0,
            );
          }

          if (userData?['profileOffset'] != null) {
            _profileImageOffset = Offset(
              userData!['profileOffset']['dx'] ?? 0.0,
              userData!['profileOffset']['dy'] ?? 0.0,
            );
          }

          isLoading = false;
        });
      }
    }
  }

  double _profileImageScale = 1.0;
  double _coverImageScale = 1.0;
  Offset _coverImageOffset = Offset.zero;
  Offset _profileImageOffset = Offset.zero;

  // Show dialog for profile image options
  void _showProfileImageOptions() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Seleccionar nueva foto',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickProfileImage();
                    },
                  ),
                  if (_newProfileImage != null || userData?['photo'] != null)
                    ListTile(
                      leading: const Icon(Icons.crop, color: Colors.white),
                      title: const Text(
                        'Ajustar foto actual',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showProfileAdjustmentDialog();
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  void _showProfileAdjustmentDialog() {
    // Variable local para el offset
    Offset localOffset = _profileImageOffset;
    final containerSize = 240.0;

    // Crear un GlobalKey para medir las dimensiones de la imagen
    final GlobalKey imageKey = GlobalKey(debugLabel: 'profileImageKey');

    showDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Función para obtener las dimensiones reales de la imagen después de que se renderice
              void getImageDimensions() {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (imageKey.currentContext != null) {
                    final RenderBox renderBox =
                        imageKey.currentContext!.findRenderObject()
                            as RenderBox;
                    final imageSize = renderBox.size;
                    final imageHeight = imageSize.height;

                    // Calcular límites de desplazamiento solo si la imagen es más alta que el contenedor
                    if (imageHeight > containerSize) {
                      final maxOffset = (imageHeight - containerSize) / 2;
                      // Asegurar que el offset actual esté dentro de los límites
                      if (localOffset.dy < -maxOffset ||
                          localOffset.dy > maxOffset) {
                        setDialogState(() {
                          localOffset = Offset(
                            0,
                            localOffset.dy.clamp(-maxOffset, maxOffset),
                          );
                        });
                      }
                    }
                  }
                });
              }

              // Llamar a la función para obtener dimensiones
              getImageDimensions();

              return Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      backgroundColor: Colors.black,
                      title: const Text(
                        'Ajustar foto de perfil',
                        style: TextStyle(color: Colors.white),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _profileImageOffset = localOffset;
                            });
                            Navigator.pop(dialogContext);
                          },
                          child: const Text(
                            'GUARDAR',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Marco circular - referencia visual
                              Container(
                                width: containerSize,
                                height: containerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white60,
                                    width: 2,
                                  ),
                                ),
                              ),

                              // Contenedor recortado con la imagen
                              ClipOval(
                                child: SizedBox(
                                  width: containerSize,
                                  height: containerSize,
                                  child: GestureDetector(
                                    onVerticalDragUpdate: (details) {
                                      if (imageKey.currentContext != null) {
                                        final RenderBox renderBox =
                                            imageKey.currentContext!
                                                    .findRenderObject()
                                                as RenderBox;
                                        final imageSize = renderBox.size;
                                        final imageHeight = imageSize.height;

                                        // Solo permitir deslizamiento si la imagen es más alta que el contenedor
                                        if (imageHeight > containerSize) {
                                          final maxOffset =
                                              (imageHeight - containerSize) / 2;

                                          setDialogState(() {
                                            localOffset = Offset(
                                              0,
                                              (localOffset.dy +
                                                      details.delta.dy)
                                                  .clamp(-maxOffset, maxOffset),
                                            );
                                          });
                                        }
                                      }
                                    },
                                    child: OverflowBox(
                                      maxHeight: double.infinity,
                                      alignment: Alignment.center,
                                      child: Transform.translate(
                                        offset: localOffset,
                                        child:
                                            _newProfileImage != null
                                                ? Image.file(
                                                  _newProfileImage!,
                                                  key: imageKey,
                                                  fit: BoxFit.cover,
                                                  width: containerSize,
                                                )
                                                : userData?['photo'] != null
                                                ? Image.network(
                                                  userData!['photo'],
                                                  key: imageKey,
                                                  fit: BoxFit.cover,
                                                  width: containerSize,
                                                )
                                                : Container(
                                                  color: Colors.grey[800],
                                                ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Indicador visual
                              Positioned(
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Desliza para ajustar la posición',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showCoverAdjustmentDialog() {
    // Variable local para el offset
    Offset localOffset = _coverImageOffset;
    final containerHeight = 180.0;

    // GlobalKey para medir las dimensiones de la imagen
    final GlobalKey imageKey = GlobalKey(debugLabel: 'coverImageKey');

    showDialog(
      context: context,
      builder:
          (BuildContext dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Función para obtener dimensiones de la imagen
              void getImageDimensions() {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (imageKey.currentContext != null) {
                    final RenderBox renderBox =
                        imageKey.currentContext!.findRenderObject()
                            as RenderBox;
                    final imageSize = renderBox.size;
                    final imageHeight = imageSize.height;

                    // Calcular límites solo si la imagen es más alta que el contenedor
                    if (imageHeight > containerHeight) {
                      final maxOffset = (imageHeight - containerHeight) / 2;
                      if (localOffset.dy < -maxOffset ||
                          localOffset.dy > maxOffset) {
                        setDialogState(() {
                          localOffset = Offset(
                            0,
                            localOffset.dy.clamp(-maxOffset, maxOffset),
                          );
                        });
                      }
                    }
                  }
                });
              }

              // Llamar a la función
              getImageDimensions();

              return Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      backgroundColor: Colors.black,
                      title: const Text(
                        'Ajustar portada',
                        style: TextStyle(color: Colors.white),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // También necesitamos almacenar el offset en Firebase
                            setState(() {
                              _coverImageOffset = localOffset;

                              // Opcionalmente guardar esto en el userData local
                              if (userData != null) {
                                userData!['coverOffset'] = {
                                  'dx': localOffset.dx,
                                  'dy': localOffset.dy,
                                };
                              }
                            });
                            Navigator.pop(dialogContext);
                          },
                          child: const Text(
                            'GUARDAR',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Marco de referencia - área visible
                            Container(
                              height: containerHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white60,
                                  width: 2,
                                ),
                              ),
                            ),

                            // Contenedor con imagen
                            SizedBox(
                              height: containerHeight,
                              width: double.infinity,
                              child: GestureDetector(
                                onVerticalDragUpdate: (details) {
                                  if (imageKey.currentContext != null) {
                                    final RenderBox renderBox =
                                        imageKey.currentContext!
                                                .findRenderObject()
                                            as RenderBox;
                                    final imageSize = renderBox.size;
                                    final imageHeight = imageSize.height;

                                    // Solo permitir deslizamiento si la imagen es más alta que el contenedor
                                    if (imageHeight > containerHeight) {
                                      final maxOffset =
                                          (imageHeight - containerHeight) / 2;

                                      setDialogState(() {
                                        localOffset = Offset(
                                          0,
                                          (localOffset.dy + details.delta.dy)
                                              .clamp(-maxOffset, maxOffset),
                                        );
                                      });
                                    }
                                  }
                                },
                                child: ClipRect(
                                  child: OverflowBox(
                                    maxHeight: double.infinity,
                                    alignment: Alignment.center,
                                    child: Transform.translate(
                                      offset: localOffset,
                                      child:
                                          _newCoverImage != null
                                              ? Image.file(
                                                _newCoverImage!,
                                                key: imageKey,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                              : userData?['coverPhoto'] != null
                                              ? Image.network(
                                                userData!['coverPhoto'],
                                                key: imageKey,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                              : Container(
                                                color: Colors.grey[800],
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Indicador visual
                            Positioned(
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Desliza para ajustar la posición',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      // Verificar permisos según la versión de Android
      if (Platform.isAndroid) {
        if (await Permission.photos.isDenied ||
            await Permission.photos.isPermanentlyDenied) {
          final status = await Permission.photos.request();
          if (status.isDenied || status.isPermanentlyDenied) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se requiere permiso para acceder a las fotos'),
              ),
            );
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (image != null && mounted) {
        setState(() {
          _newProfileImage = File(image.path);
          // Reset offset para la nueva imagen
          _profileImageOffset = Offset.zero;
        });

        // Muestra un SnackBar para confirmar la acción
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto seleccionada. Guarda los cambios para aplicarlos.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar la imagen: $e')),
      );
    }
  }

  Future<void> _deleteOldProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || userData == null || userData!['photo'] == null) return;

    try {
      final String oldPhotoUrl = userData!['photo'];

      if (oldPhotoUrl.contains('firebase') && oldPhotoUrl.contains('storage')) {
        final ref = FirebaseStorage.instance.refFromURL(oldPhotoUrl);

        // Eliminar la imagen
        await ref.delete();
        print('Imagen de perfil anterior eliminada: $oldPhotoUrl');
      }
    } catch (e) {
      print('Error al eliminar la imagen de perfil anterior: $e');
    }
  }

  // Method to pick cover image with compression
  Future<void> _pickCoverImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65, // Slightly more compression for cover images
      maxWidth: 1200, // Cover images can be wider
      maxHeight: 800, // But limit height
    );

    if (image != null) {
      setState(() {
        _newCoverImage = File(image.path);
      });
    }
  }

  // Updated upload method with additional compression as needed
  Future<String?> _uploadImage(String uid, File imageFile, String type) async {
    try {
      final fileName = path.basename(imageFile.path);
      final destination = '${type}_images/$uid/$fileName';

      // Create storage reference
      final storageRef = FirebaseStorage.instance.ref().child(destination);

      // Set compression options for Firebase Storage
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'compressed': 'true'},
      );

      // Upload the file with metadata
      final uploadTask = storageRef.putFile(imageFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading $type image: $e');
      return null;
    }
  }

  Future<void> _saveUserData() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Upload new profile image if selected
      String? newPhotoUrl;
      if (_newProfileImage != null) {
        await _deleteOldProfileImage();
        newPhotoUrl = await _uploadImage(user.uid, _newProfileImage!, 'profile');
      }

      // Upload new cover image if selected
      String? newCoverUrl;
      if (_newCoverImage != null) {
        await _deleteOldCoverImage();
        newCoverUrl = await _uploadImage(user.uid, _newCoverImage!, 'cover');
      }

      // Create update data map
      final updateData = {
        'name': nameController.text,
        'description': descriptionController.text,
        'socials': {
          'facebook': facebookController.text,
          'instagram': instagramController.text,
          'twitter': twitterController.text,
          'whatsapp': whatsappController.text,
        },
        'showJoinedRooms': userData?['showJoinedRooms'] ?? true,
        'coverOffset': {'dx': _coverImageOffset.dx, 'dy': _coverImageOffset.dy},
        'profileOffset': {
          'dx': _profileImageOffset.dx,
          'dy': _profileImageOffset.dy,
        },
      };

      // Add photo URL if a new image was uploaded
      if (newPhotoUrl != null) {
        updateData['photo'] = newPhotoUrl;
      }

      // Add cover URL if a new cover was uploaded
      if (newCoverUrl != null) {
        updateData['coverPhoto'] = newCoverUrl;
      }

      // Update Firestore for user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Update rooms created by this user if name or photo changed
      if (nameController.text != userData?['name'] || newPhotoUrl != null) {
        final roomsQuery = await FirebaseFirestore.instance
            .collection('rooms')
            .where('creatorUid', isEqualTo: user.uid)
            .get();

        for (var roomDoc in roomsQuery.docs) {
          final roomUpdateData = <String, dynamic>{};

          if (nameController.text != userData?['name']) {
            roomUpdateData['creatorName'] = nameController.text;
          }

          if (newPhotoUrl != null) {
            roomUpdateData['creatorPhoto'] = newPhotoUrl;
          }

          if (roomUpdateData.isNotEmpty) {
            await roomDoc.reference.update(roomUpdateData);
          }
        }
      }

      setState(() {
        isEditing = false;
        _newProfileImage = null;
        _newCoverImage = null;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );

      _fetchUserData(); // Refresh data
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return 'Se unió el ${DateFormat('d \'de\' MMMM \'de\' y', 'es').format(date)}';
  }

  // Método para crear secciones de formulario
  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de sección
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 20),
          height: 1,
          color: Colors.grey[800],
        ),
        ...children,
      ],
    );
  }

  // Método para crear campos de formulario estándar
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          floatingLabelStyle: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // Método para crear campos de redes sociales
  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(icon, color: color, size: 20),
          ),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          floatingLabelStyle: TextStyle(color: color),
        ),
      ),
    );
  }

  void _openUrl(String url) async {
    // Add a basic check for URL scheme, defaulting to https if missing
    String formattedUrl =
        url.startsWith('http://') || url.startsWith('https://')
            ? url
            : 'https://$url';

    if (await canLaunchUrl(Uri.parse(formattedUrl))) {
      await launchUrl(
        Uri.parse(formattedUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $formattedUrl')),
      );
    }
  }

  Future<void> _deleteOldCoverImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || userData == null || userData!['coverPhoto'] == null)
      return;

    try {
      final String oldCoverUrl = userData!['coverPhoto'];

      if (oldCoverUrl.contains('firebase') && oldCoverUrl.contains('storage')) {
        final ref = FirebaseStorage.instance.refFromURL(oldCoverUrl);

        // Delete the image
        await ref.delete();
        print('Previous cover image deleted: $oldCoverUrl');
      }
    } catch (e) {
      print('Error deleting previous cover image: $e');
    }
  }

  void _showEditModeSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'MODO EDICIÓN DE PERFIL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEditProfile() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Cover Image with proper offset applied
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Cover image with adjustment applied
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ClipRect(
                    child: OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: _coverImageOffset,
                        child:
                            _newCoverImage != null
                                ? Image.file(
                                  _newCoverImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                                : userData?['coverPhoto'] != null
                                ? Image.network(
                                  userData!['coverPhoto'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                                : Container(color: Colors.grey[800]),
                      ),
                    ),
                  ),
                ),

                // Cover image edit button
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.grey[900],
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder:
                            (context) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.photo_library,
                                      color: Colors.white,
                                    ),
                                    title: const Text(
                                      'Seleccionar nueva portada',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickCoverImage();
                                    },
                                  ),
                                  if (_newCoverImage != null ||
                                      userData?['coverPhoto'] != null)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.crop,
                                        color: Colors.white,
                                      ),
                                      title: const Text(
                                        'Ajustar portada actual',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showCoverAdjustmentDialog();
                                      },
                                    ),
                                ],
                              ),
                            ),
                      );
                    },
                  ),
                ),

                // Profile image
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            userData?['photo'] != null
                                ? NetworkImage(userData!['photo'])
                                : null,
                        child:
                            userData?['photo'] == null
                                ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                )
                                : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 35), // Space for profile image

            Container(
              margin: const EdgeInsets.only(top: 20, bottom: 10),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Usar una verificación de contexto montado antes de mostrar el modal
                    if (mounted) {
                      _showProfileImageOptions();
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Cambiar foto de perfil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10), // Space for profile image

            Text(
              userData?['email'] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),

            // Formulario principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección de información personal
                  _buildFormSection(
                    title: "INFORMACIÓN PERSONAL",
                    icon: Icons.person_outline,
                    children: [
                      // Campo de nombre
                      _buildFormField(
                        controller: nameController,
                        label: 'Nombre completo',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 20),

                      // Campo de biografía
                      _buildFormField(
                        controller: descriptionController,
                        label: 'Acerca de mí',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Sección de redes sociales
                  _buildFormSection(
                    title: "REDES SOCIALES",
                    icon: Icons.link,
                    children: [
                      // Facebook
                      _buildSocialField(
                        controller: facebookController,
                        label: 'Facebook',
                        icon: FontAwesomeIcons.facebook,
                        color: const Color(0xFF1877F2),
                      ),
                      const SizedBox(height: 16),

                      // Instagram
                      _buildSocialField(
                        controller: instagramController,
                        label: 'Instagram',
                        icon: FontAwesomeIcons.instagram,
                        color: const Color(0xFFE1306C),
                      ),
                      const SizedBox(height: 16),

                      // Twitter
                      _buildSocialField(
                        controller: twitterController,
                        label: 'Twitter',
                        icon: FontAwesomeIcons.twitter,
                        color: const Color(0xFF1DA1F2),
                      ),
                      const SizedBox(height: 16),

                      // WhatsApp
                      _buildSocialField(
                        controller: whatsappController,
                        label: 'WhatsApp',
                        icon: FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SwitchListTile(
                    title: const Text(
                      'Mostrar salas unidas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Permitir que otros usuarios vean a qué salas te has unido',
                      style: TextStyle(color: Colors.grey),
                    ),
                    value: userData?['showJoinedRooms'] ?? true,
                    onChanged: (bool value) {
                      setState(() {
                        // Actualizar el valor en userData para que se guarde cuando se llame a _saveUserData()
                        if (userData != null) {
                          userData!['showJoinedRooms'] = value;
                        }
                      });
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green,
                  ),

                  const SizedBox(height: 40),

                  // Botones de acción
                  Row(
                    children: [
                      // Botón cancelar
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              isEditing = false;
                              _newProfileImage = null;
                              _newCoverImage = null;
                              _fetchUserData();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.grey[900],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "CANCELAR",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Botón guardar
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              isLoading
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_outlined),
                                      SizedBox(width: 8),
                                      Text(
                                        "GUARDAR",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
    );
  }

  Widget _buildCreatedRoomsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('rooms')
              .where('creatorUid', isEqualTo: user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_business_outlined,
                    size: 42,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No has creado ninguna sala todavía',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final rooms = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index].data() as Map<String, dynamic>;
            final roomId = rooms[index].id;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Room image with admin badge
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(room['coverImage'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Administrador',
                                  style: TextStyle(
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

                    // Room info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  room['name'] ?? 'Sala sin nombre',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 14,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      room['memberCount']?.toString() ?? '?',
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            room['shortDescription'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),

                          // Delete button for admin actions
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _showDeleteRoomDialog(
                                    context,
                                    roomId,
                                    room['name'] ?? 'esta sala',
                                  ),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Eliminar sala',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteRoomDialog(
    BuildContext context,
    String roomId,
    String roomName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar sala'),
            content: Text(
              'Al eliminar "$roomName", se enviará una notificación a todos los miembros informando que la sala ha sido eliminada y se procesará un reembolso para los usuarios dentro de 3 a 5 días hábiles. ¿Estás seguro?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (result == true) {
      setState(() => isLoading = true);

      try {
        // 1. Obtener los miembros de la sala para notificarlos
        final roomSnapshot =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();

        final Map<String, dynamic> roomData = roomSnapshot.data() ?? {};
        final List<dynamic> members = roomData['members'] ?? [];

        // 2. Marcar pagos para reembolso
        await FirebaseFirestore.instance
            .collection('payments')
            .where('roomId', isEqualTo: roomId)
            .where('status', isEqualTo: 'completed')
            .get()
            .then((snapshot) {
              for (final doc in snapshot.docs) {
                doc.reference.update({
                  'status': 'pending_refund',
                  'refundRequestedAt': FieldValue.serverTimestamp(),
                });
              }
            });

        // 3. Crear notificaciones para todos los miembros
        for (final memberId in members) {
          if (memberId != FirebaseAuth.instance.currentUser?.uid) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': memberId,
              'title': 'Sala eliminada por el administrador',
              'body':
                  'La sala "$roomName" ha sido eliminada por el administrador. ' +
                  'Si realizaste un pago, el dinero será devuelto en un plazo de 3 a 5 días hábiles.',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'type': 'room_deleted',
              'roomId': roomId,
            });
          }

          // 4. Eliminar la sala de la colección "salasUnidas" de cada miembro
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(memberId)
              .collection('salasUnidas')
              .doc(roomId)
              .delete()
              .catchError((error) {
                print('Error al eliminar sala de usuario $memberId: $error');
              });
        }

        // 5. Eliminar la sala principal
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sala eliminada correctamente. Se procesarán los reembolsos.',
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la sala: $e')),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null || isLoading) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/grow_baja_calidad_blanco.png', height: 60),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      );
    }

    final textColor = isEditing ? Colors.white : Colors.black;
    final backgroundColor = isEditing ? Colors.black : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (isEditing) {
          setState(() => isEditing = false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          title: Image.asset(
            isEditing
                ? 'assets/grow_baja_calidad_blanco.png'
                : 'assets/grow_baja_calidad_negro.png',
            height: 110,
          ),
          centerTitle: true,
          backgroundColor: backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              icon: Icon(
                isEditing ? Icons.close : Icons.edit_outlined,
                color: textColor,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  isEditing = !isEditing;
                });
                if (isEditing) {
                  _showEditModeSnackbar();
                }
              },
            ),
          ],
        ),
        body:
            isEditing
                ? _buildEditProfile()
                : CustomScrollView(
                  slivers: [
                    // Cover image and profile picture section
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Cover image with blur effect
                          // Cover image with applied offset
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.grey[100]),
                            child: Stack(
                              children: [
                                // Cover image with offset
                                if (userData?['coverPhoto'] != null)
                                  ClipRect(
                                    child: OverflowBox(
                                      maxHeight: double.infinity,
                                      alignment: Alignment.center,
                                      child: Transform.translate(
                                        offset: _coverImageOffset,
                                        child: Image.network(
                                          userData!['coverPhoto'],
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  // Fallback to placeholder image
                                  Image(
                                    image: AssetImage(
                                      'assets/grow_baja_calidad_negro.png',
                                    ),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    color: Colors.grey.withOpacity(0.7),
                                    colorBlendMode: BlendMode.saturation,
                                    opacity: const AlwaysStoppedAnimation(0.1),
                                  ),

                                // Gradient overlay remains the same
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                        Colors.black.withOpacity(0.2),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom profile container
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(32),
                                ),
                              ),
                            ),
                          ),

                          // Profile image
                          Positioned(
                            bottom: -50,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      userData?['photo'] != null
                                          ? NetworkImage(userData!['photo'])
                                          : null,
                                  child:
                                      userData?['photo'] == null
                                          ? const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey,
                                          )
                                          : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // User information
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60, bottom: 20),
                        child: Column(
                          children: [
                            // User name
                            Text(
                              userData?['name'] ?? 'Usuario',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            // Join date
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Text(
                                _formatDate(userData?['createdAt']),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            // Email
                            Text(
                              userData?['email'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Social media buttons
                    SliverToBoxAdapter(child: _buildSocialButtonsEnhanced()),

                    // Divider
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Container(height: 1, color: Colors.grey[200]),
                      ),
                    ),

                    // Description section if available
                    if (userData?['description'] != null &&
                        userData!['description'].isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: _buildInfoSectionEnhanced(
                            title: 'ACERCA DE MÍ',
                            icon: Icons.person_outline,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                userData!['description'],
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Rooms section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        child: _buildInfoSectionEnhanced(
                          title: 'MIS SALAS',
                          icon: Icons.meeting_room_outlined,
                          child: _buildRoomsListProfessional(),
                        ),
                      ),
                    ),

                    // Created Rooms section (new)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        child: _buildInfoSectionEnhanced(
                          title: 'SALAS QUE ADMINISTRO',
                          icon: Icons.admin_panel_settings_outlined,
                          child: _buildCreatedRoomsList(),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildInfoSectionEnhanced({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildSocialButtonsEnhanced() {
    bool hasSocials =
        facebookController.text.isNotEmpty ||
        instagramController.text.isNotEmpty ||
        twitterController.text.isNotEmpty ||
        whatsappController.text.isNotEmpty;

    if (!hasSocials) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (facebookController.text.isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.facebook,
              color: const Color(0xFF1877F2),
              onTap: () => _openUrl(facebookController.text),
            ),
          if (instagramController.text.isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.instagram,
              color: const Color(0xFFE1306C),
              onTap: () => _openUrl(instagramController.text),
            ),
          if (twitterController.text.isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.twitter,
              color: const Color(0xFF1DA1F2),
              onTap: () => _openUrl(twitterController.text),
            ),
          if (whatsappController.text.isNotEmpty)
            _buildSocialButtonProfessional(
              icon: FontAwesomeIcons.whatsapp,
              color: const Color(0xFF25D366),
              onTap: () => _openUrl(whatsappController.text),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButtonProfessional({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.9), color],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FaIcon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildRoomsListProfessional() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // For profile_page.dart use current user ID
    // For user_profile_page.dart use widget.userId
    final String userId = user.uid; // Adjust based on which file

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSalasUnidas(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.black),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.meeting_room_outlined,
                    size: 42,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No hay salas disponibles',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final rooms = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final sala = rooms[index];
            final String roomId = sala['id'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Si la categoría es Fitness, dirigir a room_fitness_homepage
                      if (sala['categoria']?.toLowerCase() == 'fitness') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RoomFitnessHomePage(
                                  roomId: roomId,
                                  userId: userId,
                                ),
                          ),
                        );
                      } else {
                        // Para otras categorías, usar la página general de detalle de sala
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RoomDetailsPage(
                                  roomId: roomId,
                                  roomData: sala,
                                ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        // Room image
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(sala['logo'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Room info
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sala['nombre'] ?? 'Sala sin nombre',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sala['descripcion'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
  }

  // Add this method to both files to match the drawer functionality
  Future<List<Map<String, dynamic>>> _getSalasUnidas(String userId) async {
    if (userId.isEmpty) return [];

    final snapshot =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .collection('salasUnidas')
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': doc.id};
    }).toList();
  }
}
