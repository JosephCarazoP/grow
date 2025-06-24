import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grow/screens/user_profile_page.dart';
import 'package:intl/intl.dart';

class PendingRoomsPageDetails extends StatelessWidget {
  final Map<String, dynamic> roomData;

  const PendingRoomsPageDetails({
    required this.roomData,
    super.key,
  });

  void _navigateToUserProfile(BuildContext context, String creatorUid) {
    if (creatorUid.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(userId: creatorUid),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo encontrar el perfil del usuario.')),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final dateCreated = (roomData['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/grow_baja_calidad_negro.png', height: 100),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portada
              if (roomData['coverImage'] != null &&
                  roomData['coverImage'].toString().isNotEmpty &&
                  roomData['coverImage'].toString().startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    roomData['coverImage'],
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 250,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Center(child: Text('No hay imagen de portada')),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Nombre de la sala y creador
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      roomData['name'] ?? 'Sin título',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToUserProfile(context, roomData['creatorUid']),
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(roomData['creatorUid'])
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              );
                            }

                            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                              final userData = snapshot.data!.data() as Map<String, dynamic>?;
                              final photoUrl = userData?['photo'] as String?;

                              return CircleAvatar(
                                radius: 20,
                                backgroundImage: photoUrl != null &&
                                    photoUrl.isNotEmpty &&
                                    photoUrl.startsWith('http')
                                    ? NetworkImage(photoUrl)
                                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                              );
                            }

                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: const AssetImage('assets/default_avatar.png'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _navigateToUserProfile(context, roomData['creatorUid']),
                        child: Text(
                          roomData['creatorName'] ?? 'Desconocido',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descripción corta y categoría
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Descripción corta: ${roomData['shortDescription'] ?? 'Sin descripción'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Categoría: ${roomData['category'] ?? 'Sin categoría'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Media Gallery section - Add this after the payment information section
              if (roomData['mediaItems'] != null &&
                  (roomData['mediaItems'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                // StatefulBuilder to track current page index
                StatefulBuilder(
                  builder: (context, setState) {
                    final int itemCount = (roomData['mediaItems'] as List).length;
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
                              final item = (roomData['mediaItems'] as List)[index];

                              if (item['type'] == 'video' && item['youtubeId'] != null) {
                                // YouTube video thumbnail with play button
                                final String youtubeId = item['youtubeId'];
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        "https://img.youtube.com/vi/$youtubeId/0.jpg",
                                        height: 250,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 250,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.video_library, size: 50, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                                    ),
                                  ],
                                );
                              } else if (item['type'] == 'image' && item['url'] != null) {
                                // Image display
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    item['url'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 250,
                                    alignment: Alignment(
                                      0,
                                      (item['verticalPosition'] ?? 0.0).toDouble(),
                                    ),
                                    errorBuilder: (context, url, error) => Container(
                                      height: 250,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
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

                        // Page indicator dots
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
                                color: currentPage == index
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
              ],

              // Descripción larga
              const Text(
                'Descripción:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roomData['longDescription'] ?? 'Sin descripción',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // Precio y Fecha de creación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Precio:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₡${roomData['price']?.toString() ?? "0"}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (dateCreated != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Fecha de creación:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateCreated.toString().substring(0, 16),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Información de pago
              Center(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple, Colors.blue],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'INFORMACIÓN DE PAGO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentInfo('Estado de pago', roomData['paymentStatus'] ?? 'No especificado'),
                        const SizedBox(height: 16),
                        const Text(
                          'Comprobante:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: FutureBuilder<String?>(
                            future: _fetchComprobante(roomData['id']),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }

                              if (snapshot.data != null && snapshot.data!.isNotEmpty && snapshot.data!.startsWith('http')) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                    const Text('Error al cargar el comprobante.', style: TextStyle(color: Colors.white)),
                                  ),
                                );
                              }

                              return const Text(
                                'No se encontró comprobante de pago.',
                                style: TextStyle(color: Colors.white),
                              );
                            },
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
      ),
      bottomNavigationBar: Container(
        color: Colors.black, // Fondo negro para todo el contenedor
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _rejectRoom(context, roomData['id']),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Row(
                    children: const [
                      Icon(Icons.close, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Rechazar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _approveRoom(context, roomData['id']),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Row(
                    children: const [
                      Icon(Icons.check, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Aprobar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
  }

  Future<void> _approveRoom(BuildContext context, String roomId) async {
    // Store a reference to ScaffoldMessenger at the beginning
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Mover la sala a la colección de salas aprobadas
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        ...roomData,
        'status': 'active',
      });

      // Eliminar de las salas pendientes
      await FirebaseFirestore.instance.collection('pendingRooms').doc(roomId).delete();

      // Crear notificación para el creador de la sala
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': roomData['creatorUid'],
        'title': '¡Tu sala ha sido aprobada! 🎉',
        'body': 'Tu sala "${roomData['name']}" ha sido aprobada y ya está disponible para todos los usuarios.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'room_approval',
        'roomId': roomId
      });

      // Use the stored reference to show SnackBar
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Sala aprobada exitosamente.')),
      );

      // Navigate after a short delay
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al aprobar la sala: $e')),
      );
    }
  }

  Future<void> _rejectRoom(BuildContext context, String roomId) async {
    // Mostrar diálogo de confirmación primero
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar sala'),
        content: const Text(
            'Al rechazar esta sala, el dinero será devuelto al usuario en un plazo de 3 a 5 días hábiles. ¿Estás seguro de rechazar esta sala?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar sala'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Obtener el monto a devolver
      final amount = 10000; // Monto fijo para creación de salas
      final currentUser = FirebaseAuth.instance.currentUser;

      // MODIFICADO: Cambiado a pending_refund para que aparezca en la pestaña "Por Devolver"
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('roomId', isEqualTo: roomId)
          .where('paymentType', isEqualTo: 'room_creation')
          .limit(1)
          .get();

      if (paymentsQuery.docs.isNotEmpty) {
        final paymentDoc = paymentsQuery.docs.first;
        await paymentDoc.reference.update({
          'status': 'pending_refund',
          'updatedAt': FieldValue.serverTimestamp(),
          'refundRequestedAt': FieldValue.serverTimestamp(),
          'notes': 'Pago pendiente de devolución por rechazo de sala el ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
          'month': DateTime.now().month,  // Añadir mes para filtros
          'year': DateTime.now().year,    // Añadir año para filtros
        });
      }

      // Actualizar registros financieros
      final financesRef = FirebaseFirestore.instance.collection('finances').doc('summary');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final financeSnapshot = await transaction.get(financesRef);

        if (financeSnapshot.exists) {
          final financeData = financeSnapshot.data() as Map<String, dynamic>;

          // Obtener valores actuales
          double ganancias = (financeData['ganancias'] as num?)?.toDouble() ?? 0;
          double porDevolver = (financeData['porDevolver'] as num?)?.toDouble() ?? 0;

          // Actualizar valores
          transaction.update(financesRef, {
            'ganancias': ganancias - amount,
            'porDevolver': porDevolver + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Actualizar el registro de earnings_history para que tenga los campos month y year
      await FirebaseFirestore.instance.collection('earnings_history').add({
        'amount': -amount,
        'description': 'Devolución por sala rechazada: ${roomData['name']}',
        'userId': roomData['creatorUid'],
        'userName': roomData['creatorName'] ?? 'Usuario',
        'userPhoto': roomData['creatorPhoto'] ?? '',
        'roomId': roomId,
        'roomName': roomData['name'],
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'refund',
        'label': 'Sala rechazada',
        'month': DateTime.now().month,
        'year': DateTime.now().year,
      });

      // NUEVO: Crear registro en historial de devoluciones
      await FirebaseFirestore.instance.collection('refunds').add({
        'amount': amount,
        'reason': 'Sala rechazada',
        'userId': roomData['creatorUid'],
        'userName': roomData['creatorName'] ?? 'Usuario',
        'userPhoto': roomData['creatorPhoto'] ?? '',
        'roomId': roomId,
        'roomName': roomData['name'],
        'refundDate': FieldValue.serverTimestamp(),
        'status': 'processed',
      });

      // NUEVO: Crear notificación para la sección de finanzas
      await FirebaseFirestore.instance.collection('finance_notifications').add({
        'title': 'Devolución realizada',
        'body': 'Se ha devuelto ₡10,000 por el rechazo de la sala "${roomData['name']}"',
        'userId': roomData['creatorUid'],
        'userName': roomData['creatorName'] ?? 'Usuario',
        'userPhoto': roomData['creatorPhoto'] ?? '',
        'amount': amount,
        'roomId': roomId,
        'roomName': roomData['name'],
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'refund_processed',
      });

      // Eliminar la sala pendiente
      await FirebaseFirestore.instance.collection('pendingRooms').doc(roomId).delete();

      // Crear notificación para el creador de la sala
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': roomData['creatorUid'],
        'title': 'Tu sala no ha sido aprobada ❌',
        'body': 'Lamentablemente, tu sala "${roomData['name']}" no ha sido aprobada. ' +
            'El dinero pagado será devuelto en un plazo de 3 a 5 días hábiles. ' +
            'Si tienes preguntas, contacta al equipo de soporte.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'room_rejection',
        'roomId': roomId
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sala rechazada. El reembolso está en proceso.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar la sala: $e')),
      );
    }
  }

  Widget _buildPaymentInfo(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }

  Future<String?> _fetchComprobante(String? roomId) async {
    if (roomId == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('comprobantes')
        .where('roomId', isEqualTo: roomId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['comprobanteUrl'] as String?;
    }
    return null;
  }
}

// Create a reusable expandable text widget
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final String label;

  const ExpandableText({
    required this.text,
    required this.style,
    this.label = 'Descripción corta',
    Key? key,
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${widget.label}: ${widget.text}",
          style: widget.style,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _expanded ? 'Ver menos' : 'Ver más',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: widget.style.fontSize! - 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}