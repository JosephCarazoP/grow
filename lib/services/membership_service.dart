import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MembershipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verificar membresías vencidas (ejecutar periódicamente)
  Future<void> checkExpiredMemberships() async {
    final now = DateTime.now();

    // 1. Obtener membresías activas que han expirado
    final expiredMemberships = await _firestore
        .collection('members')
        .where('status', isEqualTo: 'active')
        .where('expiresAt', isLessThan: Timestamp.fromDate(now))
        .get();

    // 2. Cambiar estado a "grace_period" para membresías expiradas
    final batch = _firestore.batch();

    for (final doc in expiredMemberships.docs) {
      batch.update(doc.reference, {
        'status': 'grace_period',
      });

      // Notificar al usuario
      batch.set(_firestore.collection('notifications').doc(), {
        'userId': doc.data()['userId'],
        'title': 'Tu membresía ha expirado',
        'body': 'Tu membresía para ${doc.data()['roomName']} ha expirado. Tienes 3 días para renovarla.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    // 3. Verificar membresías en período de gracia que han vencido
    final expiredGrace = await _firestore
        .collection('members')
        .where('status', isEqualTo: 'grace_period')
        .where('gracePeriodEndsAt', isLessThan: Timestamp.fromDate(now))
        .get();

    // 4. Cancela membresías con período de gracia vencido
    for (final doc in expiredGrace.docs) {
      final data = doc.data();
      final userId = data['userId'];
      final roomId = data['roomId'];

      // Actualizar estado de membresía
      batch.update(doc.reference, {
        'status': 'cancelled',
      });

      // Decrementar contador de miembros
      batch.update(_firestore.collection('rooms').doc(roomId), {
        'memberCount': FieldValue.increment(-1),
      });

      // Eliminar de salasUnidas
      batch.delete(
          _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('salasUnidas')
              .doc(roomId)
      );

      // Notificar al usuario
      batch.set(_firestore.collection('notifications').doc(), {
        'userId': userId,
        'title': 'Membresía cancelada',
        'body': 'Tu membresía para ${data['roomName']} ha sido cancelada por falta de renovación.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    if (expiredMemberships.docs.isNotEmpty || expiredGrace.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Renovar membresía (cuando el usuario paga nuevamente)
  Future<void> renewMembership(String memberId) async {
    final now = DateTime.now();
    final expirationDate = now.add(const Duration(days: 30));

    await _firestore.collection('members').doc(memberId).update({
      'status': 'active',
      'renewedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expirationDate),
      'gracePeriodEndsAt': Timestamp.fromDate(
          expirationDate.add(const Duration(days: 3))
      ),
    });
  }

  // Verificar si el usuario tiene acceso a una sala específica
  Future<bool> hasAccessToRoom(String userId, String roomId) async {
    final now = DateTime.now();

    final querySnapshot = await _firestore
        .collection('members')
        .where('userId', isEqualTo: userId)
        .where('roomId', isEqualTo: roomId)
        .where('status', whereIn: ['active', 'grace_period'])
        .where('gracePeriodEndsAt', isGreaterThan: Timestamp.fromDate(now))
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }
}