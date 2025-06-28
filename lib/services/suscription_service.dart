import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SubscriptionStatus {
  active,
  expired,
  gracePeriod,
  gracePeriodExpired,
  notMember,
}

class SubscriptionInfo {
  final SubscriptionStatus status;
  final DateTime? expiresAt;
  final DateTime? gracePeriodEndsAt;
  final int? daysUntilExpiration;
  final int? gracePeriodDaysLeft;

  SubscriptionInfo({
    required this.status,
    this.expiresAt,
    this.gracePeriodEndsAt,
    this.daysUntilExpiration,
    this.gracePeriodDaysLeft,
  });
}

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<SubscriptionInfo> checkSubscriptionStatus(String roomId) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('DEBUG: Usuario no autenticado');
      return SubscriptionInfo(status: SubscriptionStatus.notMember);
    }

    try {
      print('DEBUG: Verificando membresía para sala $roomId, usuario $userId');

      // Buscar en la colección members principal
      final memberQuery = await _firestore
          .collection('members')
          .where('userId', isEqualTo: userId)
          .where('roomId', isEqualTo: roomId)
          .get();

      if (memberQuery.docs.isEmpty) {
        print('DEBUG: El usuario no es miembro de la sala');
        return SubscriptionInfo(status: SubscriptionStatus.notMember);
      }

      final memberDoc = memberQuery.docs.first;
      final data = memberDoc.data();
      print('DEBUG: Datos de membresía encontrados: $data');

      // Usar la fecha y hora actual
      final DateTime now = DateTime.now();
      print('DEBUG: Fecha y hora actual: $now');

      // Obtener fechas
      DateTime? expiresAt;
      DateTime? gracePeriodEndsAt;

      if (data['expiresAt'] != null) {
        expiresAt = (data['expiresAt'] as Timestamp).toDate();
        print('DEBUG: Fecha de expiración: $expiresAt');
        print('DEBUG: ¿Está expirada? ${expiresAt.isBefore(now)}');
      } else {
        print('DEBUG: No hay fecha de expiración definida');
      }

      if (data['gracePeriodEndsAt'] != null) {
        gracePeriodEndsAt = (data['gracePeriodEndsAt'] as Timestamp).toDate();
        print('DEBUG: Período de gracia termina: $gracePeriodEndsAt');
      }

      // Si no hay fecha de expiración, asumimos que está activa
      if (expiresAt == null) {
        return SubscriptionInfo(status: SubscriptionStatus.active);
      }

      // Calcular días hasta expiración (solo fechas, sin horas)
      final DateTime expiresAtDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
      final DateTime todayDate = DateTime(now.year, now.month, now.day);
      int daysUntilExpiration = expiresAtDate.difference(todayDate).inDays;

      print('DEBUG: Días hasta expiración: $daysUntilExpiration');

      // Verificar si la suscripción está activa
      if (expiresAt.isAfter(now)) {
        return SubscriptionInfo(
          status: SubscriptionStatus.active,
          expiresAt: expiresAt,
          gracePeriodEndsAt: gracePeriodEndsAt,
          daysUntilExpiration: daysUntilExpiration,
        );
      }

      // La suscripción ha expirado
      // Actualizar el status en Firestore si es necesario
      if (data['status'] == 'active' || data['status'] == true) {
        await memberDoc.reference.update({'status': false});
      }

      // Verificar período de gracia existente
      if (gracePeriodEndsAt != null) {
        if (gracePeriodEndsAt.isAfter(now)) {
          // En período de gracia
          final DateTime gracePeriodDate = DateTime(
              gracePeriodEndsAt.year,
              gracePeriodEndsAt.month,
              gracePeriodEndsAt.day
          );
          int gracePeriodDaysLeft = gracePeriodDate.difference(todayDate).inDays;

          return SubscriptionInfo(
            status: SubscriptionStatus.gracePeriod,
            expiresAt: expiresAt,
            gracePeriodEndsAt: gracePeriodEndsAt,
            gracePeriodDaysLeft: gracePeriodDaysLeft + 1, // +1 para incluir hoy
          );
        } else {
          // Período de gracia expirado
          return SubscriptionInfo(
            status: SubscriptionStatus.gracePeriodExpired,
            expiresAt: expiresAt,
            gracePeriodEndsAt: gracePeriodEndsAt,
          );
        }
      }

      // No hay período de gracia definido, crear uno de 3 días
      final DateTime autoGracePeriodEnd = expiresAt.add(const Duration(days: 3));

      if (autoGracePeriodEnd.isAfter(now)) {
        // Actualizar Firestore con el período de gracia automático
        await memberDoc.reference.update({
          'gracePeriodEndsAt': Timestamp.fromDate(autoGracePeriodEnd),
          'status': false,
        });

        final DateTime gracePeriodDate = DateTime(
            autoGracePeriodEnd.year,
            autoGracePeriodEnd.month,
            autoGracePeriodEnd.day
        );
        int gracePeriodDaysLeft = gracePeriodDate.difference(todayDate).inDays;

        return SubscriptionInfo(
          status: SubscriptionStatus.gracePeriod,
          expiresAt: expiresAt,
          gracePeriodEndsAt: autoGracePeriodEnd,
          gracePeriodDaysLeft: gracePeriodDaysLeft + 1,
        );
      }

      // Período de gracia automático también expirado
      return SubscriptionInfo(
        status: SubscriptionStatus.gracePeriodExpired,
        expiresAt: expiresAt,
        gracePeriodEndsAt: autoGracePeriodEnd,
      );

    } catch (e) {
      print('ERROR: Error checking subscription status: $e');
      return SubscriptionInfo(status: SubscriptionStatus.notMember);
    }
  }

  // Actualizar el mensaje para el período de gracia
  static String getStatusMessage(SubscriptionInfo info) {
    switch (info.status) {
      case SubscriptionStatus.active:
        if (info.daysUntilExpiration != null &&
            info.daysUntilExpiration! <= 7) {
          if (info.daysUntilExpiration == 0) {
            return 'Tu suscripción expira hoy. Renuévala para mantener el acceso.';
          } else if (info.daysUntilExpiration == 1) {
            return 'Tu suscripción expira mañana. Renuévala pronto.';
          } else {
            return 'Tu suscripción expira en ${info.daysUntilExpiration} días';
          }
        }
        return 'Suscripción activa';
      case SubscriptionStatus.expired:
        return 'Tu suscripción ha expirado';
      case SubscriptionStatus.gracePeriod:
        if (info.gracePeriodDaysLeft == 1) {
          return 'Tu membresía expiró el ${info.expiresAt?.day}/${info.expiresAt?.month}/${info.expiresAt?.year}. El período de gracia termina mañana';
        } else {
          return 'Tu membresía expiró el ${info.expiresAt?.day}/${info.expiresAt?.month}/${info.expiresAt?.year}. Tienes ${info.gracePeriodDaysLeft} días de período de gracia';
        }
      case SubscriptionStatus.gracePeriodExpired:
        return 'Tu período de gracia ha terminado. Renueva tu suscripción para continuar';
      case SubscriptionStatus.notMember:
        return 'No eres miembro de esta sala';
    }
  }
}
