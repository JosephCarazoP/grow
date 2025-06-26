import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grow/screens/pending_rooms_page_details.dart';
import 'package:grow/screens/room_detail_page.dart';
import 'package:grow/screens/user_profile_page.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _currentIndex = 1; // Mantener notificaciones como tab por defecto
  String role = 'usuario';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      setState(() {
        role = userDoc.data()?['role'] ?? 'usuario';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (role != 'owner') {
      return Scaffold(
        appBar: AppBar(
          title: Image.asset('assets/grow_baja_calidad_negro.png', height: 100),
          centerTitle: true,
        ),
        body: const NotificationsTab(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/grow_baja_calidad_negro.png', height: 100),
        centerTitle: true,
      ),
      body:
          _currentIndex == 0
              ? const ApprovalsSection()
              : _currentIndex == 1
              ? const NotificationsTab()
              : const FinancialsSection(),
      bottomNavigationBar: StreamBuilder<List<int>>(
        stream: Rx.combineLatest2<int, int, List<int>>(
          _getTotalApprovalsCount(),
          _getUnreadNotificationsCount(),
          (a, b) => [a, b],
        ),
        builder: (context, snapshot) {
          final approvalsCount = snapshot.data?[0] ?? 0;
          final notificationsCount = snapshot.data?[1] ?? 0;
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: SizedBox(
                  width: 40,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.check_circle_outline),
                      if (approvalsCount > 0)
                        Positioned(
                          right: -8,
                          top: -2,
                          child: _buildBadge(approvalsCount),
                        ),
                    ],
                  ),
                ),
                label: 'Aprobaciones',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(
                  width: 40,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications),
                      if (notificationsCount > 0)
                        Positioned(
                          right: -8,
                          top: -2,
                          child: _buildBadge(notificationsCount),
                        ),
                    ],
                  ),
                ),
                label: 'Notificaciones',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.attach_money),
                label: 'Finanzas',
              ),
            ],
          );
        },
      ),
    );
  }

  // Badge widget
  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Stream<int> _getTotalApprovalsCount() {
    final pendingRooms =
        FirebaseFirestore.instance.collection('pendingRooms').snapshots();
    final pendingMembers =
        FirebaseFirestore.instance.collection('pendingMembers').snapshots();
    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, int>(
      pendingRooms,
      pendingMembers,
      (a, b) => a.size + b.size,
    );
  }

  // Stream para notificaciones no leídas
  Stream<int> _getUnreadNotificationsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }
}

class FinancialsSection extends StatefulWidget {
  const FinancialsSection({super.key});

  @override
  State<FinancialsSection> createState() => _FinancialsSectionState();
}

class _FinancialsSectionState extends State<FinancialsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Pagos Recibidos'),
            Tab(text: 'Por Devolver'),
            Tab(text: 'Ganancias'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ReceivedPaymentsTab(),
              RefundsTab(),
              MonthlyEarningsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceivedPaymentsTab extends StatelessWidget {
  const ReceivedPaymentsTab({super.key});

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('payments')
              .where('status', whereIn: ['received', 'refunded'])
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay pagos registrados',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final payment = snapshot.data!.docs[index];
            final data = payment.data() as Map<String, dynamic>;
            final isRefunded = data['status'] == 'refunded';
            final amount = data['amount'] ?? 0;
            final timestamp = data['timestamp'] as Timestamp?;
            final roomName = data['roomName'] ?? 'Sala sin nombre';
            final roomId = data['roomId'] ?? '';
            final userId = data['userId'] ?? '';
            final userName = data['userName'] ?? 'Usuario desconocido';
            final paymentType = data['paymentType'] ?? 'payment';
            final userPhoto = data['userPhoto'] ?? '';
            final receiptUrl = data['receiptUrl'] as String?;

            // Determinar etiqueta y color basado en tipo de pago
            String labelText = 'PAGO';
            Color labelColor = Colors.blue;

            if (paymentType == 'room_creation') {
              labelText = isRefunded ? 'DEVUELTO' : 'SALA';
              labelColor = isRefunded ? Colors.red : Colors.green;
            } else if (paymentType == 'subscription') {
              labelText = 'SUSCRIPCIÓN';
              labelColor = Colors.purple;
            } else if (paymentType == 'membership') {
              labelText = isRefunded ? 'DEVUELTO' : 'MEMBRESÍA';
              labelColor = isRefunded ? Colors.red : Colors.orange;
            } else {
              // Para cualquier otro tipo de pago, si está reembolsado, mostrar en rojo
              if (isRefunded) {
                labelText = 'DEVUELTO';
                labelColor = Colors.red;
              }
            }

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [labelColor, labelColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con monto y tipo de pago
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [labelColor, labelColor.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₡${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                labelText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Información del pago
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información del usuario que hizo el pago
                            Row(
                              children: [
                                FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(data['userId'])
                                          .get(),
                                  builder: (context, userSnapshot) {
                                    final userData =
                                        userSnapshot.data?.data()
                                            as Map<String, dynamic>?;
                                    final userPhoto = userData?['photo'] ?? '';

                                    return CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          userPhoto.isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                userPhoto,
                                              )
                                              : null,
                                      child:
                                          userPhoto.isEmpty
                                              ? const Icon(
                                                Icons.person,
                                                color: Colors.grey,
                                              )
                                              : null,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Usuario',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            // ID de usuario
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_pin,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'ID: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    userId,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Nombre de la sala
                            if (roomName.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.meeting_room,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Sala: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      roomName,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // ID de la sala
                            if (roomId.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.key,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Sala ID: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      roomId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Fecha del pago
                            if (timestamp != null) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Fecha: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(timestamp.toDate()),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Ver comprobante (si existe)
                            if (receiptUrl != null &&
                                receiptUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
                                                    AppBar(
                                                      title: const Text(
                                                        'Comprobante de pago',
                                                      ),
                                                      centerTitle: true,
                                                      backgroundColor:
                                                          labelColor,
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
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
                                                      minScale: 0.5,
                                                      maxScale: 4.0,
                                                      child: CachedNetworkImage(
                                                        imageUrl: receiptUrl,
                                                        placeholder:
                                                            (
                                                              context,
                                                              url,
                                                            ) => const SizedBox(
                                                              height: 300,
                                                              child: Center(
                                                                child:
                                                                    CircularProgressIndicator(),
                                                              ),
                                                            ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) => const SizedBox(
                                                              height: 300,
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons.error,
                                                                ),
                                                              ),
                                                            ),
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: Colors.black87,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Ver comprobante',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Botones de acción
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: Row(
                          children: [
                            if (roomId.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // First fetch the complete room data
                                    final roomDoc =
                                        await FirebaseFirestore.instance
                                            .collection('rooms')
                                            .doc(roomId)
                                            .get();

                                    if (roomDoc.exists) {
                                      final roomData = {
                                        ...roomDoc.data()!,
                                        'id': roomDoc.id,
                                      };

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => RoomDetailsPage(
                                                roomId: roomId,
                                                roomData: roomData,
                                              ),
                                        ),
                                      );
                                    } else {
                                      // Try to find in pendingRooms if not found in rooms
                                      final pendingDoc =
                                          await FirebaseFirestore.instance
                                              .collection('pendingRooms')
                                              .doc(roomId)
                                              .get();

                                      if (pendingDoc.exists) {
                                        final roomData = {
                                          ...pendingDoc.data()!,
                                          'id': pendingDoc.id,
                                        };

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    PendingRoomsPageDetails(
                                                      roomData: roomData,
                                                    ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No se encontró información de la sala',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Ver Sala'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: labelColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            if (userId.isNotEmpty && roomId.isNotEmpty)
                              const SizedBox(width: 8),
                            if (userId.isNotEmpty)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                UserProfilePage(userId: userId),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person),
                                  label: const Text('Ver Usuario'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
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
            );
          },
        );
      },
    );
  }
}

// Tab de Pagos por Devolver
class RefundsTab extends StatelessWidget {
  const RefundsTab({super.key});

  Future<void> _markAsRefunded(String paymentId) async {
    try {
      // Obtener los datos del pago primero
      final paymentDoc =
          await FirebaseFirestore.instance
              .collection('payments')
              .doc(paymentId)
              .get();

      if (!paymentDoc.exists) return;

      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final amount = paymentData['amount'] ?? 0;
      final paymentType = paymentData['paymentType'] ?? 'payment';

      // Actualizar el estado del pago
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
            'status': 'refunded',
            'refundedAt': FieldValue.serverTimestamp(),
            'paymentType': paymentType,
          });

      // Actualizar los datos financieros
      final financesRef = FirebaseFirestore.instance
          .collection('finances')
          .doc('summary');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final financeSnapshot = await transaction.get(financesRef);

        if (financeSnapshot.exists) {
          final financeData = financeSnapshot.data() as Map<String, dynamic>;
          double porDevolver =
              (financeData['porDevolver'] as num?)?.toDouble() ?? 0;

          // Reducir el monto en porDevolver
          transaction.update(financesRef, {
            'porDevolver': porDevolver - amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Crear notificación para confirmar devolución
      await FirebaseFirestore.instance.collection('finance_notifications').add({
        'title': 'Devolución completada',
        'body': 'Se ha marcado como completada la devolución de ₡$amount.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'refund_completed',
      });
    } catch (e) {
      print('Error al marcar como devuelto: $e');
    }
  }

  int _calculateDaysSinceRefundRequested(Timestamp requestedAt) {
    final now = DateTime.now();
    final requestDate = requestedAt.toDate();
    return now.difference(requestDate).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('payments')
              .where('status', isEqualTo: 'pending_refund')
              .orderBy('refundRequestedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay pagos pendientes de devolución',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final payment = snapshot.data!.docs[index];
            final data = payment.data() as Map<String, dynamic>;
            final amount = data['amount'] ?? 0;
            final refundRequestedAt = data['refundRequestedAt'] as Timestamp?;
            final roomName = data['roomName'] ?? 'Sala sin nombre';
            final userName = data['userName'] ?? 'Usuario desconocido';

            // Calcular días desde la solicitud de reembolso
            int daysSinceRequest = 0;
            if (refundRequestedAt != null) {
              daysSinceRequest = _calculateDaysSinceRefundRequested(
                refundRequestedAt,
              );
            }

            // Determinar color basado en días pendientes
            Color statusColor =
                daysSinceRequest >= 4 ? Colors.red : Colors.orange;
            if (daysSinceRequest >= 5) {
              statusColor = Colors.red[700]!;
            }

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con status
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [statusColor, statusColor.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₡${amount.toString()} - Por devolver',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Día $daysSinceRequest/5',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sala: $roomName',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Usuario: $userName',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            if (refundRequestedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Solicitado: ${_formatDate(refundRequestedAt.toDate())}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Plazo máximo: 5 días',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    daysSinceRequest >= 4
                                        ? Colors.red
                                        : Colors.black54,
                                fontWeight:
                                    daysSinceRequest >= 4
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botón para marcar como devuelto
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _markAsRefunded(payment.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Marcar como Devuelto',
                              style: TextStyle(color: Colors.white),
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
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

// Tab de Ganancias Mensuales
class MonthlyEarningsTab extends StatefulWidget {
  const MonthlyEarningsTab({super.key});

  @override
  State<MonthlyEarningsTab> createState() => _MonthlyEarningsTabState();
}

class _MonthlyEarningsTabState extends State<MonthlyEarningsTab> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<Map<String, dynamic>> _months = [
    {'value': 1, 'label': 'Enero'},
    {'value': 2, 'label': 'Febrero'},
    {'value': 3, 'label': 'Marzo'},
    {'value': 4, 'label': 'Abril'},
    {'value': 5, 'label': 'Mayo'},
    {'value': 6, 'label': 'Junio'},
    {'value': 7, 'label': 'Julio'},
    {'value': 8, 'label': 'Agosto'},
    {'value': 9, 'label': 'Septiembre'},
    {'value': 10, 'label': 'Octubre'},
    {'value': 11, 'label': 'Noviembre'},
    {'value': 12, 'label': 'Diciembre'},
  ];

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Eliminar ingreso'),
                content: const Text(
                  '¿Estás seguro de eliminar este ingreso manual?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _deleteManualIncome(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('manual_earnings')
          .doc(id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingreso eliminado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar ingreso: $e')));
    }
  }

  List<int> get _years {
    final currentYear = DateTime.now().year;
    return List<int>.generate(currentYear - 2022, (i) => 2023 + i);
  }

  Future<void> _addManualIncome() async {
    if (_amountController.text.isEmpty ||
        double.tryParse(_amountController.text) == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingrese un monto válido')));
      return;
    }

    final amount = double.parse(_amountController.text);
    final description =
        _descriptionController.text.trim().isEmpty
            ? 'Ingreso manual'
            : _descriptionController.text;

    try {
      // Guardar con mes y año para que aparezca en los filtros
      await FirebaseFirestore.instance.collection('manual_earnings').add({
        'amount': amount,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'addedManually': true,
        'month': _selectedMonth, // Usar el mes seleccionado actualmente
        'year': _selectedYear, // Usar el año seleccionado actualmente
      });

      // Limpiar controladores
      _amountController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingreso agregado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al agregar ingreso: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Selector de mes y año mejorado
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por periodo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Dropdown de mes con estilo mejorado
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Mes',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                          ),
                          value: _selectedMonth,
                          items: _months.map((month) {
                            return DropdownMenuItem<int>(
                              value: month['value'],
                              child: Text(month['label']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value!;
                            });
                          },
                          icon: const Icon(Icons.calendar_month),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dropdown de año con estilo mejorado
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Año',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                          ),
                          value: _selectedYear,
                          items: _years.map((year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value!;
                            });
                          },
                          icon: const Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tarjeta de resumen mensual mejorada
          Card(
            elevation: 6,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ganancias Totales',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_months.firstWhere((m) => m['value'] == _selectedMonth)['label']} $_selectedYear',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bar_chart,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<double>(
                        stream: _calculateMonthlyEarnings(
                          _selectedMonth,
                          _selectedYear,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 48,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final earnings = snapshot.data ?? 0.0;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₡',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                earnings.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Formulario para añadir ingresos manuales mejorado
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              title: const Text(
                'Agregar Ingreso Manual',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.add_circle, color: Colors.green),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monto (₡)',
                        hintText: '50000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.confirmation_number),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Ingreso por servicio adicional',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.description),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _addManualIncome,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Agregar Ingreso',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Título de transacciones
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Transacciones de ${_months.firstWhere((m) => m['value'] == _selectedMonth)['label']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Lista de transacciones con altura fija
          SizedBox(
            height: 400, // Altura fija para la lista
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('status', isEqualTo: 'received')
                  .where('year', isEqualTo: _selectedYear)
                  .where('month', isEqualTo: _selectedMonth)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, paymentSnapshot) {
                if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('manual_earnings')
                      .where('year', isEqualTo: _selectedYear)
                      .where('month', isEqualTo: _selectedMonth)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, manualSnapshot) {
                    if (manualSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Combinar ambos tipos de ingresos
                    List<Map<String, dynamic>> allTransactions = [];

                    if (paymentSnapshot.hasData) {
                      for (var doc in paymentSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        allTransactions.add({
                          ...data,
                          'id': doc.id,
                          'type': 'payment',
                        });
                      }
                    }

                    if (manualSnapshot.hasData) {
                      for (var doc in manualSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        allTransactions.add({
                          ...data,
                          'id': doc.id,
                          'type': 'manual',
                        });
                      }
                    }

                    // Ordenar por fecha (más reciente primero)
                    allTransactions.sort((a, b) {
                      final aTime = a['timestamp'] as Timestamp?;
                      final bTime = b['timestamp'] as Timestamp?;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    if (allTransactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay transacciones en ${_months.firstWhere((m) => m['value'] == _selectedMonth)['label']} $_selectedYear',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Usar ListView dentro del SizedBox
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = allTransactions[index];
                        final isManual = transaction['type'] == 'manual';
                        final amount = transaction['amount'] ?? 0;
                        final timestamp = transaction['timestamp'] as Timestamp?;
                        final transactionId = transaction['id'] ?? '';

                        // Formato para fecha más legible
                        String dateFormatted = timestamp != null
                            ? _formatDate(timestamp.toDate())
                            : 'Fecha no disponible';

                        return Dismissible(
                          key: Key(transactionId),
                          direction: isManual
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: isManual
                              ? (direction) => _confirmDelete(context)
                              : null,
                          onDismissed: isManual
                              ? (direction) => _deleteManualIncome(transactionId)
                              : null,
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Icono con fondo circular
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isManual
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isManual
                                          ? Icons.front_hand_rounded
                                          : Icons.payment,
                                      color: isManual ? Colors.green : Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Información de la transacción
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isManual
                                              ? (transaction['description'] ?? 'Ingreso manual')
                                              : (transaction['roomName'] ?? 'Pago recibido'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dateFormatted,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Monto
                                  Text(
                                    '₡${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Colors.black,
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
                );
              },
            ),
          ),

          // Padding inferior para mejor visualización
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Stream<double> _calculateMonthlyEarnings(int month, int year) {
    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('status', isEqualTo: 'received')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            total += (data['amount'] ?? 0).toDouble();
          }
          return total;
        });

    final manualEarningsStream = FirebaseFirestore.instance
        .collection('manual_earnings')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            total += (data['amount'] ?? 0).toDouble();
          }
          return total;
        });

    return Rx.combineLatest2<double, double, double>(
      paymentsStream,
      manualEarningsStream,
      (paymentsTotal, manualTotal) => paymentsTotal + manualTotal,
    );
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy hh:mm a');
    return formatter.format(date.toLocal());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class ApprovalsSection extends StatefulWidget {
  const ApprovalsSection({super.key});

  @override
  State<ApprovalsSection> createState() => _ApprovalsSectionState();
}

Future<void> _approveRoom(
  BuildContext context,
  String roomId,
  Map<String, dynamic> roomData,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('approvedRooms')
        .doc(roomId)
        .set({...roomData, 'status': 'active'});
    await FirebaseFirestore.instance
        .collection('pendingRooms')
        .doc(roomId)
        .delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sala aprobada con éxito')));
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error al aprobar la sala: $e')));
  }
}

void _viewPaymentReceipt(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder:
        (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Cambio crucial aquí
              children: [
                // Header fijo
                Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Comprobante de Pago',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Contenido completamente scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          placeholder:
                              (context, url) => Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 8),
                                    Text('Error al cargar imagen'),
                                  ],
                                ),
                              ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

class _ApprovalsSectionState extends State<ApprovalsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _approveMembership(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Incrementar memberCount en la sala
      final roomRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(requestData['roomId']);

      // 2. Crear documento en collection members
      final memberRef = FirebaseFirestore.instance.collection('members').doc();
      final now = DateTime.now();
      final expirationDate = now.add(const Duration(days: 30));

      batch.set(memberRef, {
        'userId': requestData['userId'],
        'roomId': requestData['roomId'],
        'userName': requestData['userName'],
        'userPhoto': requestData['userPhoto'],
        'roomName': requestData['roomName'],
        'joinedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationDate),
        'gracePeriodEndsAt': Timestamp.fromDate(
          expirationDate.add(const Duration(days: 3)),
        ),
        'status': 'active',
      });

      // 3. Crear en salasUnidas para el drawer
      final userSalasRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(requestData['userId'])
          .collection('salasUnidas')
          .doc(requestData['roomId']);

      // Obtener datos de la sala para guardar en salasUnidas
      final roomDoc = await roomRef.get();
      final roomData = roomDoc.data() ?? {};

      batch.set(userSalasRef, {
        'id': requestData['roomId'],
        'nombre': requestData['roomName'],
        'logo': roomData['coverImage'] ?? '',
        'categoria': roomData['category'] ?? '',
        'unidoEn': FieldValue.serverTimestamp(),
      });

      // 4. Incrementar memberCount
      batch.update(roomRef, {'memberCount': FieldValue.increment(1)});

      // 5. Eliminar solicitud pendiente
      batch.delete(
        FirebaseFirestore.instance.collection('pendingMembers').doc(requestId),
      );

      // 6. Registrar pago como recibido
      batch.set(FirebaseFirestore.instance.collection('payments').doc(), {
        'userId': requestData['userId'],
        'userName': requestData['userName'],
        'roomId': requestData['roomId'],
        'roomName': requestData['roomName'],
        'amount': requestData['paymentAmount'],
        'receiptUrl': requestData['paymentReceiptUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'month': DateTime.now().month,
        'year': DateTime.now().year,
        'status': 'received',
        'type': 'membership',
      });

      // 7. Notificar al usuario
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'userId': requestData['userId'],
        'title': '¡Membresía aprobada!',
        'body':
            'Tu solicitud para unirte a ${requestData['roomName']} ha sido aprobada.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membresía aprobada con éxito')),
      );
    } catch (e) {
      print('Error al aprobar membresía: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectMembership(
    BuildContext context,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Crear registro para devolución
      batch.set(FirebaseFirestore.instance.collection('payments').doc(), {
        'userId': requestData['userId'],
        'userName': requestData['userName'],
        'roomId': requestData['roomId'],
        'roomName': requestData['roomName'],
        'amount': requestData['paymentAmount'],
        'receiptUrl': requestData['paymentReceiptUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'month': DateTime.now().month,
        'year': DateTime.now().year,
        'status': 'pending_refund',
        'refundRequestedAt': FieldValue.serverTimestamp(),
        'type': 'refund',
        'paymentType': 'membership',
      });

      // 2. Eliminar solicitud pendiente
      batch.delete(
        FirebaseFirestore.instance.collection('pendingMembers').doc(requestId),
      );

      // 3. Notificar al usuario
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'userId': requestData['userId'],
        'title': 'Solicitud rechazada',
        'body':
            'Tu solicitud para unirte a ${requestData['roomName']} ha sido rechazada. El monto será reembolsado.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 4. Notificar a finanzas sobre la devolución pendiente
      batch.set(
        FirebaseFirestore.instance.collection('finance_notifications').doc(),
        {
          'title': 'Devolución pendiente',
          'body':
              'Se ha solicitado la devolución de ₡${requestData['paymentAmount']} a ${requestData['userName']}',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'refund_requested',
        },
      );

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud rechazada. Se ha generado una solicitud de devolución',
          ),
        ),
      );
    } catch (e) {
      print('Error al rechazar solicitud: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildTabWithBadge(String label, Stream<int> countStream) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 6), // Space between label and badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            _buildTabWithBadge(
              'Salas',
              FirebaseFirestore.instance
                  .collection('pendingRooms')
                  .snapshots()
                  .map((s) => s.size),
            ),
            _buildTabWithBadge(
              'Miembros',
              FirebaseFirestore.instance
                  .collection('pendingMembers')
                  .snapshots()
                  .map((s) => s.size),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildApprovalList(
                FirebaseFirestore.instance
                    .collection('pendingRooms')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                'Sala',
                'Categoría',
              ),
              _buildApprovalList(
                FirebaseFirestore.instance
                    .collection('pendingMembers')
                    .orderBy('requestedAt', descending: true)
                    .snapshots(),
                'Usuario',
                'Sala',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalList(
    Stream<QuerySnapshot> stream,
    String mainLabel,
    String secondaryLabel,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No hay solicitudes pendientes de aprobación.'),
          );
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final data = items[index].data() as Map<String, dynamic>;
            final title = data['name'] ?? data['userName'] ?? 'Sin título';
            final subtitle =
                data['category'] ?? data['roomName'] ?? 'Sin categoría';
            final createdAt =
                data['createdAt'] as Timestamp? ??
                data['requestedAt'] as Timestamp?;
            final paymentStatus = data['paymentStatus'] ?? 'No especificado';
            final docId = items[index].id;
            final bool isMembershipRequest = data.containsKey(
              'paymentReceiptUrl',
            );

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PendingRoomsPageDetails(
                          roomData: {...data, 'id': docId},
                        ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: Colors.black.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con gradiente a todo lo ancho
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nombre de sala: $subtitle',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Estado de pago: $paymentStatus',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Creado el: ${_formatDate(createdAt.toDate())}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Botones de acción para solicitudes de membresía
                        if (isMembershipRequest)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                // Botón Aprobar
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => _approveMembership(
                                          context,
                                          docId,
                                          data,
                                        ),
                                    icon: const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                    ),
                                    label: const Text('Aprobar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(
                                        color: Colors.green,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Botón Rechazar
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => _rejectMembership(
                                          context,
                                          docId,
                                          data,
                                        ),
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: const Text('Rechazar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Botón para ver comprobante (solo en solicitudes de membresía)
                        if (isMembershipRequest &&
                            data['paymentReceiptUrl'] != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _viewPaymentReceipt(
                                    context,
                                    data['paymentReceiptUrl'],
                                  );
                                },
                                icon: const Icon(
                                  Icons.receipt_long,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Ver Comprobante',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
          },
        );
      },
    );
  }

  // Función auxiliar para formatear fechas
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('No has iniciado sesión'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No tienes notificaciones por el momento.\n😁',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final notification = snapshot.data!.docs[index];
            final data = notification.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final isRead = data['read'] == true;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isRead ? Colors.grey[100] : Colors.blue[50],
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey[300] : Colors.blue[100],
                  child: Icon(
                    isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: isRead ? Colors.grey : Colors.blue,
                    size: 24,
                  ),
                ),
                title: Text(
                  data['title'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      data['body'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timestamp != null
                          ? timestamp.toDate().toString().substring(0, 16)
                          : '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await notification.reference.delete();
                  },
                  tooltip: 'Eliminar notificación',
                ),
                onTap: () {
                  if (!isRead) {
                    notification.reference.update({'read': true});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
