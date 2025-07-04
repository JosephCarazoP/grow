import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:grow/screens/user_profile_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../rooms/fitness/room_fitness_home_page.dart';
import '../services/suscription_service.dart';
import '../widgets/animated_gradiente_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/drawer.dart';

class RoomDetailsPage extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> roomData;

  const RoomDetailsPage({
    required this.roomId,
    required this.roomData,
    super.key,
  });

  @override
  _RoomDetailsPageState createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends State<RoomDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _checkInitialSubscriptionStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Recargar datos de la sala
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (roomDoc.exists && mounted) {
        setState(() {
          widget.roomData.clear();
          widget.roomData.addAll(roomDoc.data() as Map<String, dynamic>);
        });
      }

      // Verificar estado de suscripción nuevamente
      await _checkInitialSubscriptionStatus();
    } catch (e) {
      print('Error refreshing room data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Nuevo método para verificar al cargar la página
  Future<void> _checkInitialSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Solo verificar si es miembro (no creador)
    if (widget.roomData['creatorUid'] != user.uid) {
      final isMember = await _isUserMember();
      if (isMember) {
        final subscriptionInfo =
        await SubscriptionService.checkSubscriptionStatus(widget.roomId);

        // Si el status es inactive o período de gracia expirado, bloquear inmediatamente
        if (subscriptionInfo.status == SubscriptionStatus.gracePeriodExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSubscriptionExpiredDialog();
          });
        } else if (subscriptionInfo.status == SubscriptionStatus.gracePeriod) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGracePeriodAlert(subscriptionInfo);
          });
        } else if (subscriptionInfo.status == SubscriptionStatus.active &&
            subscriptionInfo.daysUntilExpiration != null &&
            subscriptionInfo.daysUntilExpiration! <= 7) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showExpirationWarningAlert(subscriptionInfo);
          });
        }
      }
    }
  }
  // Agregar estos métodos a RoomDetailsPage

  void _showGracePeriodAlert(SubscriptionInfo subscriptionInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Obtener dimensiones de la pantalla
        final size = MediaQuery.of(context).size;
        final isSmallDevice = size.width < 360;
        final isMediumDevice = size.width >= 360 && size.width < 400;
        final isLargeDevice = size.width >= 400;

        // Ajustar tamaños según el dispositivo
        final double titleFontSize = isSmallDevice ? 16 : (isMediumDevice ? 17 : 18);
        final double contentFontSize = isSmallDevice ? 14 : (isMediumDevice ? 15 : 16);
        final double smallTextSize = isSmallDevice ? 12 : (isMediumDevice ? 13 : 14);
        final double iconSize = isSmallDevice ? 20 : (isMediumDevice ? 22 : 24);
        final double buttonPaddingHorizontal = isSmallDevice ? 16 : 20;
        final double buttonPaddingVertical = isSmallDevice ? 8 : 10;

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 20 : 24,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 16 : 20,
            vertical: isSmallDevice ? 16 : 20,
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: iconSize),
              SizedBox(width: isSmallDevice ? 6 : 8),
              Flexible(
                child: Text(
                  '¡Membresía Expirada!',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu membresía expiró el ${subscriptionInfo.expiresAt?.day}/${subscriptionInfo.expiresAt?.month}/${subscriptionInfo.expiresAt?.year}.',
                  style: TextStyle(
                    fontSize: contentFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isSmallDevice ? 10 : 12),
                Text(
                  'Tienes un periodo de gracia de 3 días el cual finalizará el día ${subscriptionInfo.gracePeriodEndsAt?.day}/${subscriptionInfo.gracePeriodEndsAt?.month}/${subscriptionInfo.gracePeriodEndsAt?.year}.',
                  style: TextStyle(fontSize: contentFontSize - 1),
                ),
                SizedBox(height: isSmallDevice ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isSmallDevice ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.orange,
                        size: iconSize - 4,
                      ),
                      SizedBox(width: isSmallDevice ? 6 : 8),
                      Expanded(
                        child: Text(
                          subscriptionInfo.gracePeriodDaysLeft == 1
                              ? 'Te queda 1 día de periodo de gracia'
                              : 'Te quedan ${subscriptionInfo.gracePeriodDaysLeft} días de periodo de gracia',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: smallTextSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallDevice ? 16 : 20),
                Center(
                  child: Text(
                    '¿Deseas renovar tu membresía ahora?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: contentFontSize - 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: EdgeInsets.only(
            left: isSmallDevice ? 8 : 12,
            right: isSmallDevice ? 8 : 12,
            bottom: isSmallDevice ? 12 : 16,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: buttonPaddingHorizontal,
                  vertical: buttonPaddingVertical,
                ),
              ),
              child: Text(
                'Más tarde',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: smallTextSize,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showRenewalPaymentModal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: buttonPaddingHorizontal,
                  vertical: buttonPaddingVertical,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallDevice ? 6 : 8),
                ),
              ),
              child: Text(
                'Renovar Ahora',
                style: TextStyle(fontSize: smallTextSize),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showExpirationWarningAlert(SubscriptionInfo subscriptionInfo) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text(
                  'Suscripción por Expirar',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu suscripción expira en ${subscriptionInfo.daysUntilExpiration} días.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Renueva antes del ${subscriptionInfo.expiresAt?.day}/${subscriptionInfo.expiresAt?.month} para evitar interrupciones.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '¿Deseas renovar tu suscripción ahora?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Más tarde'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRenewalPaymentModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text('Renovar Ahora'),
              ),
            ],
          ),
    );
  }

  void _checkSubscriptionAndNavigate() async {
    final subscriptionInfo = await SubscriptionService.checkSubscriptionStatus(
      widget.roomId,
    );

    // Si el status es inactive o período de gracia expirado, bloquear acceso
    if (subscriptionInfo.status == SubscriptionStatus.gracePeriodExpired) {
      _showSubscriptionExpiredDialog();
      return;
    }

    if (subscriptionInfo.status == SubscriptionStatus.gracePeriod ||
        (subscriptionInfo.status == SubscriptionStatus.active &&
            subscriptionInfo.daysUntilExpiration != null &&
            subscriptionInfo.daysUntilExpiration! <= 7)) {
      // Mostrar alerta pero permitir acceso
      _showSubscriptionWarningAndNavigate(subscriptionInfo);
      return;
    }

    // Si la suscripción está activa, navegar normalmente
    _navigateToRoomContent();
  }

  void _showSubscriptionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Acceso Restringido', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu suscripción y período de gracia han expirado. Necesitas renovar tu suscripción para continuar accediendo a esta sala.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  '¿Deseas renovar tu suscripción ahora?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRenewalPaymentModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Renovar'),
              ),
            ],
          ),
    );
  }

  void _showSubscriptionWarningAndNavigate(SubscriptionInfo subscriptionInfo) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  subscriptionInfo.status == SubscriptionStatus.gracePeriod
                      ? Icons.warning
                      : Icons.info_outline,
                  color:
                      subscriptionInfo.status == SubscriptionStatus.gracePeriod
                          ? Colors.red
                          : Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  subscriptionInfo.status == SubscriptionStatus.gracePeriod
                      ? 'Período de Gracia'
                      : 'Suscripción por Expirar',
                  style: TextStyle(
                    color:
                        subscriptionInfo.status ==
                                SubscriptionStatus.gracePeriod
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
              ],
            ),
            content: Text(
              SubscriptionService.getStatusMessage(subscriptionInfo),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToRoomContent();
                },
                child: Text('Continuar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRenewalPaymentModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      subscriptionInfo.status == SubscriptionStatus.gracePeriod
                          ? Colors.red
                          : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text('Renovar'),
              ),
            ],
          ),
    );
  }

  void _showRenewalPaymentModal() {
    final double renewalPrice = (widget.roomData['price'] ?? 0).toDouble();
    final double discount = (widget.roomData['discount'] ?? 0).toDouble();
    final double discountedPrice = renewalPrice * (1 - (discount / 100));

    _displayPaymentModal(context, discountedPrice);
  }

  Future<void> _playWithSystemPlayer(
    BuildContext context,
    String youtubeId,
  ) async {
    try {
      // Método 1: Intent explícito para reproducir video (Android)
      if (Platform.isAndroid) {
        // Primero intentamos con un intent de VIDEO directo
        final Uri videoUri = Uri.parse(
          "https://www.youtube.com/watch?v=$youtubeId",
        );
        if (await canLaunchUrl(videoUri)) {
          final bool launched = await launchUrl(
            videoUri,
            mode: LaunchMode.externalApplication,
          );

          if (launched) return;
        }
      }

      // Método 2: Usar el esquema de youtube:// (funciona en iOS y algunos Android)
      final Uri youtubeUri = Uri.parse("youtube://watch?v=$youtubeId");
      if (await canLaunchUrl(youtubeUri)) {
        final bool launched = await launchUrl(youtubeUri);
        if (launched) return;
      }

      // Método 3: Usar un intent VIEW con tipo de contenido (para Android)
      if (Platform.isAndroid) {
        final Uri uri = Uri.parse("https://www.youtube.com/watch?v=$youtubeId");
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        final Map<String, String> params = <String, String>{
          'android.intent.action.VIEW': '',
          'android.intent.category.BROWSABLE': '',
          'android.intent.extra.REFERRER': 'android-app://$packageName',
        };

        final uriLaunch = Uri.https('www.youtube.com', '/watch', {
          'v': youtubeId,
        });
        await launchUrl(
          uriLaunch,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        return;
      }

      // Método 4: Fallback a navegador/webview como último recurso
      final Uri webUri = Uri.parse(
        "https://www.youtube.com/watch?v=$youtubeId",
      );
      await launchUrl(webUri, mode: LaunchMode.inAppWebView);
    } catch (e) {
      print('Error al reproducir video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir el video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _displayPaymentModal(BuildContext context, double price) {
    final user = FirebaseAuth.instance.currentUser;
    XFile? selectedImage;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Evitar cerrar el modal durante la carga
      isDismissible: !isUploading,
      enableDrag: !isUploading,
      builder: (context) {
        return WillPopScope(
          // Prevenir cierre durante la carga
          onWillPop: () async {
            return !isUploading;
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Cabecera con indicador de arrastre
                      Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Título con fondo de gradiente
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.purple],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Unirse a la Sala',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card con instrucciones de pago
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Encabezado de la tarjeta
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Instrucciones de Pago',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Contenido de la tarjeta
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Realiza el pago mediante SINPE al siguiente número:',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Número SINPE
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.grey[200]!,
                                                  Colors.grey[100]!,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 5,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  '86622488',
                                                  style: TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.5,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[900],
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.copy,
                                                      color: Colors.white,
                                                    ),
                                                    onPressed: () {
                                                      Clipboard.setData(
                                                        const ClipboardData(
                                                          text: '86622488',
                                                        ),
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Número copiado al portapapeles',
                                                          ),
                                                          backgroundColor:
                                                              Colors.black87,
                                                          duration: Duration(
                                                            seconds: 1,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // Nombre del beneficiario
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: const Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Beneficiario:',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Joseph Eduardo Carazo Peña',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 20),

                                          // Monto a pagar
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Colors.blue,
                                                  Colors.purple,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.payments_outlined,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Monto a transferir:',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '₡${price.toInt()}',
                                                      style: const TextStyle(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
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
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

                              // Sección para subir comprobante
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.grey[50]!],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          color: Colors.black87,
                                          size: 22,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Comprobante de Pago',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    const Text(
                                      'Adjunta una captura del comprobante de pago',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Selector de imagen
                                    GestureDetector(
                                      onTap:
                                          isUploading
                                              ? null
                                              : () async {
                                                final ImagePicker picker =
                                                    ImagePicker();
                                                final XFile?
                                                image = await picker.pickImage(
                                                  source: ImageSource.gallery,
                                                  maxWidth:
                                                      1800, // Mayor resolución
                                                  imageQuality:
                                                      90, // Mayor calidad
                                                );

                                                if (image != null) {
                                                  setState(() {
                                                    selectedImage = image;
                                                  });
                                                }
                                              },
                                      child: Container(
                                        height:
                                            300, // Aumentado para mejor visualización
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                selectedImage == null
                                                    ? Colors.grey[300]!
                                                    : Colors.transparent,
                                            width: 1,
                                          ),
                                          boxShadow:
                                              selectedImage != null
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
                                                  : null,
                                        ),
                                        child:
                                            selectedImage == null
                                                ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .add_photo_alternate,
                                                        size: 40,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Pulsa para seleccionar imagen',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Formatos admitidos: JPG, PNG',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                : Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    // Imagen con ajuste para mantener relación de aspecto
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Image.file(
                                                        File(
                                                          selectedImage!.path,
                                                        ),
                                                        fit:
                                                            BoxFit
                                                                .contain, // Cambiado a contain para mostrar completa
                                                      ),
                                                    ),

                                                    // Botones de acción
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Row(
                                                        children: [
                                                          // Botón ampliar imagen
                                                          Container(
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  right: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              gradient: const LinearGradient(
                                                                colors: [
                                                                  Colors.blue,
                                                                  Colors.purple,
                                                                ],
                                                                begin:
                                                                    Alignment
                                                                        .topLeft,
                                                                end:
                                                                    Alignment
                                                                        .bottomRight,
                                                              ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                                  blurRadius: 4,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        2,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: IconButton(
                                                              icon: const Icon(
                                                                Icons.zoom_in,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 20,
                                                              ),
                                                              onPressed: () {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (
                                                                        context,
                                                                      ) => Dialog(
                                                                        backgroundColor:
                                                                            Colors.transparent,
                                                                        insetPadding:
                                                                            const EdgeInsets.all(
                                                                              20,
                                                                            ),
                                                                        child: Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Container(
                                                                              decoration: BoxDecoration(
                                                                                gradient: const LinearGradient(
                                                                                  colors: [
                                                                                    Colors.blue,
                                                                                    Colors.purple,
                                                                                  ],
                                                                                  begin:
                                                                                      Alignment.topLeft,
                                                                                  end:
                                                                                      Alignment.bottomRight,
                                                                                ),
                                                                                borderRadius: BorderRadius.circular(
                                                                                  12,
                                                                                ),
                                                                              ),
                                                                              child: Container(
                                                                                margin: const EdgeInsets.all(
                                                                                  2,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  color:
                                                                                      Colors.white,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    10,
                                                                                  ),
                                                                                ),
                                                                                child: Column(
                                                                                  children: [
                                                                                    AppBar(
                                                                                      title: const Text(
                                                                                        'Vista previa del comprobante',
                                                                                      ),
                                                                                      centerTitle:
                                                                                          true,
                                                                                      backgroundColor:
                                                                                          Colors.transparent,
                                                                                      foregroundColor:
                                                                                          Colors.black87,
                                                                                      elevation:
                                                                                          0,
                                                                                      leading: IconButton(
                                                                                        icon: const Icon(
                                                                                          Icons.close,
                                                                                        ),
                                                                                        onPressed:
                                                                                            () => Navigator.pop(
                                                                                              context,
                                                                                            ),
                                                                                      ),
                                                                                    ),
                                                                                    InteractiveViewer(
                                                                                      minScale:
                                                                                          0.5,
                                                                                      maxScale:
                                                                                          4.0,
                                                                                      boundaryMargin: const EdgeInsets.all(
                                                                                        20,
                                                                                      ),
                                                                                      child: Image.file(
                                                                                        File(
                                                                                          selectedImage!.path,
                                                                                        ),
                                                                                        fit:
                                                                                            BoxFit.contain,
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height:
                                                                                          16,
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
                                                            ),
                                                          ),

                                                          // Botón eliminar
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              gradient: const LinearGradient(
                                                                colors: [
                                                                  Colors
                                                                      .black87,
                                                                  Colors
                                                                      .black54,
                                                                ],
                                                                begin:
                                                                    Alignment
                                                                        .topLeft,
                                                                end:
                                                                    Alignment
                                                                        .bottomRight,
                                                              ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                                  blurRadius: 4,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        2,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: IconButton(
                                                              icon: const Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 20,
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  selectedImage =
                                                                      null;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Indicador de toque
                                                    if (selectedImage != null)
                                                      Positioned(
                                                        bottom: 10,
                                                        left: 0,
                                                        right: 0,
                                                        child: Center(
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                    0.6,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'Toca para ampliar imagen',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                      ),
                                    ),

                                    if (selectedImage != null) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Comprobante adjuntado correctamente. Utiliza el botón de ampliar para verificar que la imagen sea clara y completa.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Botón de envío
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient:
                                isUploading || selectedImage == null
                                    ? LinearGradient(
                                      colors: [
                                        Colors.grey[400]!,
                                        Colors.grey[500]!,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                    : const LinearGradient(
                                      colors: [Colors.blue, Colors.purple],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                isUploading || selectedImage == null
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                          ),
                          child: ElevatedButton(
                            onPressed:
                                isUploading || selectedImage == null
                                    ? null
                                    : () async {
                                      setState(() {
                                        isUploading = true;
                                      });

                                      await _submitJoinRequest(
                                        context,
                                        selectedImage!,
                                        price,
                                      );
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              disabledForegroundColor: Colors.white.withOpacity(
                                0.8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child:
                                isUploading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send, size: 18),
                                        SizedBox(width: 10),
                                        Text(
                                          'Enviar Solicitud',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submitJoinRequest(
    BuildContext context,
    XFile imageFile,
    double price,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Verificar si es una renovación
      final isMember = await _isUserMember();
      final requestType = isMember ? 'renewal' : 'new_membership';

      // 1. Subir la imagen a Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment_receipts')
          .child('${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg');

      final uploadTask = storageRef.putFile(File(imageFile.path));
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // 2. Obtener información del usuario
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'Usuario';
      final userPhoto = userData['photo'] ?? '';

      // 3. Crear registro en pendingMembers
      await FirebaseFirestore.instance.collection('pendingMembers').add({
        'userId': user.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'roomId': widget.roomId,
        'roomName': widget.roomData['name'],
        'paymentAmount': price,
        'paymentReceiptUrl': downloadUrl,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': requestType, // Nuevo campo para distinguir renovaciones
      });

      // 4. Registrar notificación para el admin
      await FirebaseFirestore.instance.collection('finance_notifications').add({
        'title':
            requestType == 'renewal'
                ? 'Solicitud de renovación'
                : 'Nueva solicitud de membresía',
        'body':
            requestType == 'renewal'
                ? '$userName quiere renovar su suscripción en ${widget.roomData['name']}'
                : '$userName quiere unirse a ${widget.roomData['name']}',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'membership_request',
      });

      // 5. Notificar al usuario
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'title':
            requestType == 'renewal'
                ? 'Solicitud de renovación enviada'
                : 'Solicitud enviada',
        'body':
            requestType == 'renewal'
                ? 'Tu solicitud de renovación para ${widget.roomData['name']} ha sido enviada.'
                : 'Tu solicitud para unirte a ${widget.roomData['name']} ha sido enviada. Te notificaremos cuando sea revisada.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Cerrar modal y mostrar mensaje de éxito
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestType == 'renewal'
                ? 'Solicitud de renovación enviada correctamente'
                : 'Solicitud enviada correctamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al enviar solicitud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showJoinRoomDialog(BuildContext context, double price) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para unirte a una sala'),
        ),
      );
      return;
    }

    // Verificar si ya existe una solicitud pendiente para esta sala
    FirebaseFirestore.instance
        .collection('pendingMembers')
        .where('userId', isEqualTo: user.uid)
        .where('roomId', isEqualTo: widget.roomId)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ya tienes una solicitud pendiente para esta sala',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Si no hay solicitud pendiente, mostrar modal
          _displayPaymentModal(context, price);
        });
  }

  Future<void> _launchYoutubeVideo(
    BuildContext context,
    String youtubeId,
  ) async {
    await _playWithSystemPlayer(context, youtubeId);
  }

  Future<bool> _isUserMember() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    print('DEBUG: Verificando membresía para sala ${widget.roomId}, usuario $userId');

    // Verificar si es el creador
    if (widget.roomData['creatorUid'] == userId) {
      print('DEBUG: El usuario es el creador de la sala');
      return true;
    }

    try {
      // Verificar en la colección members principal
      final membersQuery = await FirebaseFirestore.instance
          .collection('members')
          .where('userId', isEqualTo: userId)
          .where('roomId', isEqualTo: widget.roomId)
          .limit(1)
          .get();

      if (membersQuery.docs.isEmpty) {
        print('DEBUG: No se encontró registro de membresía');
        // Limpiar cualquier referencia obsoleta en salasUnidas
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .collection('salasUnidas')
            .doc(widget.roomId)
            .delete()
            .catchError((error) => print('Error limpiando salasUnidas: $error'));
        return false;
      }

      // Verificar el status de la membresía
      final memberData = membersQuery.docs.first.data();
      final status = memberData['status'] as String?;

      print('DEBUG: Status de membresía: $status');

      // Solo considerar como miembro si el status es "active"
      final isActiveMember = status == 'active';

      if (!isActiveMember) {
        print('DEBUG: Membresía inactiva, limpiando salasUnidas');
        // Si la membresía no está activa, limpiar salasUnidas
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .collection('salasUnidas')
            .doc(widget.roomId)
            .delete()
            .catchError((error) => print('Error limpiando salasUnidas: $error'));
      }

      return isActiveMember;
    } catch (e) {
      print('ERROR: Error checking membership: $e');
      return false;
    }
  }

  void _navigateToRoomContent() {
    // Determinar a qué pantalla navegar según la categoría
    if (widget.roomData['category']?.toLowerCase() == 'fitness') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => RoomFitnessHomePage(
                roomId: widget.roomId,
                userId: FirebaseAuth.instance.currentUser!.uid,
              ),
        ),
      );
    } else {
      // Para otras categorías, usar la página general
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => RoomDetailsPage(
                roomId: widget.roomId,
                roomData: widget.roomData,
              ),
        ),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Hero(
                    tag: 'media_$imageUrl',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) => const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 50,
                          ),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double price = (widget.roomData['price'] ?? 0).toDouble();
    final double discount = (widget.roomData['discount'] ?? 0).toDouble();
    final double discountedPrice = price * (1 - (discount / 100));
    final bool isOfficial = widget.roomData['oficial'] ?? false;

    return Scaffold(
        key: _scaffoldKey,
        drawer: const CustomDrawer(),
    appBar: AppBar(
    leading: IconButton(
    icon: const Icon(Icons.menu),
    onPressed: () {
    _scaffoldKey.currentState?.openDrawer();
    },
    ),
    title: Row(
    children: [
    Expanded(
    child: Text(
    widget.roomData['name'] ?? 'Detalles de la Sala',
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Colors.black,
    ),
    overflow: TextOverflow.ellipsis,
    ),
    ),
    if (isOfficial)
    GestureDetector(
    onTap: () {
    showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
    return Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
    constraints: const BoxConstraints(maxWidth: 340),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 32,
    offset: const Offset(0, 16),
    spreadRadius: 0,
    ),
    ],
    ),
    child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
    color: const Color(0xFF0F172A),
    borderRadius: BorderRadius.circular(32),
    ),
    child: const Icon(
    Icons.verified,
    color: Colors.white,
    size: 32,
    ),
    ),
    const SizedBox(height: 24),
    const Text(
    'Sala Oficial',
    style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Color(0xFF0F172A),
    letterSpacing: -0.5,
    ),
    ),
    const SizedBox(height: 12),
    Text(
    'Esta sala es oficial y está potenciada por la app. Es confiable y cumple con los estándares de calidad.',
    textAlign: TextAlign.center,
    style: TextStyle(
    fontSize: 16,
    color: Colors.grey[600],
    height: 1.5,
    letterSpacing: 0.2,
    ),
    ),
    const SizedBox(height: 32),
    SizedBox(
    width: double.infinity,
    child: ElevatedButton(
    onPressed: () => Navigator.of(context).pop(),
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF0F172A),
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(
    vertical: 16,
    ),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    ),
    child: const Text(
    'Entendido',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    ),
    ),
    ),
    ),
    ],
    ),
    ),
    ),
    );
    },
    );
    },
    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 2,
    ),
    decoration: BoxDecoration(
    color: Colors.blue.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
    children: const [
    Icon(Icons.verified, color: Colors.blue, size: 18),
    SizedBox(width: 4),
    Text(
    'Oficial',
    style: TextStyle(
    color: Colors.blue,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    ),
    ),
    ],
    ),
    ),
    ),
    ],
    ),
    centerTitle: true,
    backgroundColor: Colors.white,
    elevation: 4,
    shadowColor: Colors.grey.withOpacity(0.3),
    iconTheme: const IconThemeData(color: Colors.black),
    actions: [
    if (_isRefreshing)
    const Center(
    child: Padding(
    padding: EdgeInsets.only(right: 16.0),
    child: SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(
    strokeWidth: 2,
    ),
    ),
    ),
    ),
    ],
    ),
    body: RefreshIndicator(
    onRefresh: _refreshPage,
    color: Colors.blue,
    backgroundColor: Colors.white,
    child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Imagen de portada
    if (widget.roomData['coverImage'] != null &&
    widget.roomData['coverImage'].toString().isNotEmpty)
    ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: CachedNetworkImage(
    imageUrl: widget.roomData['coverImage'],
    height: 250,
    width: double.infinity,
    fit: BoxFit.cover,
    alignment: Alignment(
    0,
    (widget.roomData['imagePosition'] ?? 0.0).toDouble(),
    ),
    memCacheHeight: 500,
    fadeInDuration: const Duration(milliseconds: 300),
    placeholder: (context, url) => Container(
    height: 250,
    color: Colors.grey[200],
    child: const Center(
    child: CircularProgressIndicator(),
    ),
    ),
    errorWidget: (context, url, error) => Container(
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
    const SizedBox(height: 16),

    // Animated Join Button
    FutureBuilder<bool>(
    future: _isUserMember(),
    builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
    return Container(
    height: 56,
    decoration: BoxDecoration(
    color: Colors.grey[300],
    borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
    child: CircularProgressIndicator(
    color: Colors.grey[600],
    ),
    ),
    );
    }

    final bool isMember = snapshot.data ?? false;

    return FutureBuilder<SubscriptionInfo>(
    future: isMember
    ? SubscriptionService.checkSubscriptionStatus(
    widget.roomId,
    )
        : null,
    builder: (context, subscriptionSnapshot) {
    if (isMember &&
    subscriptionSnapshot.hasData &&
    subscriptionSnapshot.data!.status ==
    SubscriptionStatus.gracePeriodExpired) {
    return AnimatedGradientButton(
    text: 'Renovar Suscripción',
    onPressed: () => _showRenewalPaymentModal(),
    );
    }

    return AnimatedGradientButton(
    text: isMember ? 'Entrar a la Sala' : 'Unirme a la Sala',
    onPressed: () {
    if (isMember) {
    _checkSubscriptionAndNavigate();
    } else {
    final double price = (widget.roomData['price'] ?? 0).toDouble();
    final double discount = (widget.roomData['discount'] ?? 0).toDouble();
    final double discountedPrice = price * (1 - (discount / 100));
    _showJoinRoomDialog(context, discountedPrice);
    }
    },
    );
    },
    );
    },
    ),
    const SizedBox(height: 16),

              // Prices Section
              Center(
                child:
                    discount > 0
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Antes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₡${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.black38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ahora',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    return Text(
                                      '₡${discountedPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        foreground:
                                            Paint()
                                              ..shader = LinearGradient(
                                                colors: const [
                                                  Colors.blue,
                                                  Colors.purple,
                                                  Colors.blue,
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                                begin: Alignment(
                                                  -1.0 + _controller.value * 2,
                                                  0.0,
                                                ),
                                                end: Alignment(
                                                  1.0 + _controller.value * 2,
                                                  0.0,
                                                ),
                                              ).createShader(
                                                const Rect.fromLTWH(
                                                  0.0,
                                                  0.0,
                                                  200.0,
                                                  70.0,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                        : AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: [
                                    Colors.blue,
                                    Colors.purple,
                                    Colors.blue,
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                  begin: Alignment(
                                    -1.0 + _controller.value * 2,
                                    0.0,
                                  ),
                                  end: Alignment(
                                    1.0 + _controller.value * 2,
                                    0.0,
                                  ),
                                ).createShader(bounds);
                              },
                              child: Text(
                                '₡${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Colors
                                          .white, // Acts as a mask for the gradient
                                ),
                              ),
                            );
                          },
                        ),
              ),
              const SizedBox(height: 24),

              // Title and Creator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.roomData['name'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.roomData['creatorUid'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UserProfilePage(
                                      userId: widget.roomData['creatorUid'],
                                    ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Información del creador no disponible',
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            FutureBuilder<DocumentSnapshot>(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.roomData['creatorUid'])
                                      .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[200],
                                  );
                                }

                                if (snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.exists) {
                                  final userData =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                  // Comprobar ambos campos posibles para la foto
                                  final photoUrl =
                                      userData?['photo'] as String? ??
                                      userData?['photoURL'] as String?;

                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage:
                                        photoUrl != null &&
                                                photoUrl.isNotEmpty &&
                                                photoUrl.startsWith('http')
                                            ? CachedNetworkImageProvider(
                                              photoUrl,
                                            )
                                            : const AssetImage(
                                                  'assets/default_avatar.png',
                                                )
                                                as ImageProvider,
                                  );
                                }

                                return CircleAvatar(
                                  radius: 16,
                                  backgroundImage: const AssetImage(
                                    'assets/default_avatar.png',
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.roomData['creatorName'] ?? 'Desconocido',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.blue,
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
              const SizedBox(height: 20),

              if (widget.roomData['mediaItems'] != null &&
                  (widget.roomData['mediaItems'] as List).isNotEmpty) ...[
                // StatefulBuilder to track current page index within this widget section
                StatefulBuilder(
                  builder: (context, setState) {
                    final int itemCount =
                        (widget.roomData['mediaItems'] as List).length;
                    final PageController pageController = PageController();
                    int currentPage = 0;

                    return Column(
                      children: [
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: PageView.builder(
                            controller: pageController,
                            itemCount: itemCount,
                            onPageChanged: (index) {
                              setState(() {
                                currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final item =
                                  (widget.roomData['mediaItems']
                                      as List)[index];

                              if (item['type'] == 'video' &&
                                  item['youtubeId'] != null) {
                                // Extract the YouTube ID
                                final String youtubeId = item['youtubeId'];

                                // For YouTube videos
                                return GestureDetector(
                                  onTap:
                                      () => _launchYoutubeVideo(
                                        context,
                                        youtubeId,
                                      ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // YouTube thumbnail
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              "https://img.youtube.com/vi/$youtubeId/0.jpg",
                                          height: 250,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (context, url) => Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Container(
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
                                      // Play button
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (item['type'] == 'image' &&
                                  item['url'] != null) {
                                // For images
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Hero(
                                    tag: 'media_${item['url']}',
                                    child: GestureDetector(
                                      onTap:
                                          () => _showFullScreenImage(
                                            context,
                                            item['url'],
                                          ),
                                      child: CachedNetworkImage(
                                        imageUrl: item['url'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 250,
                                        alignment: Alignment(
                                          0,
                                          (item['verticalPosition'] ?? 0.0)
                                              .toDouble(),
                                        ),
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.error),
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(); // Empty container for invalid items
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Interactive page indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            itemCount,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: currentPage == index ? 16 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    currentPage == index
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Description
              Text(
                widget.roomData['longDescription'] ?? 'Sin descripción',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categoría: ${widget.roomData['category'] ?? 'Sin categoría'}',
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.roomData['memberCount'] ?? 0} miembros',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
