// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener el plan actual del usuario
  Future<Map<String, dynamic>> getCurrentPlan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'error': 'No hay usuario autenticado'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists || userDoc.data() == null || !userDoc.data()!.containsKey('plan')) {
        return {
          'name': 'free',
          'status': 'active',
          'features': [],
        };
      }

      final planData = userDoc.data()!['plan'] as Map<String, dynamic>;

      // Verificar si la prueba gratuita ha expirado
      if (planData['status'] == 'trial') {
        final trialEndDate = planData['trialEndDate'] as Timestamp;
        if (trialEndDate.toDate().isBefore(DateTime.now())) {
          // La prueba ha expirado, actualizar el estado
          await _firestore.collection('users').doc(user.uid).update({
            'plan.status': 'expired',
          });

          planData['status'] = 'expired';
        }
      }

      return planData;
    } catch (e) {
      print('Error al obtener el plan: $e');
      return {'error': e.toString()};
    }
  }

  // Verificar si el usuario tiene acceso a una característica específica
  Future<bool> hasAccess(String feature) async {
    final planData = await getCurrentPlan();

    if (planData.containsKey('error')) {
      return false;
    }

    // Si está en prueba gratuita activa o tiene plan premium activo
    if (planData['status'] == 'trial' ||
        (planData['status'] == 'active' && planData['name'] == 'Discipline+')) {
      return true;
    }

    // Lógica específica según el plan y la característica
    switch (feature) {
      case 'chat_coach':
      case 'personalized_routines':
      case 'verified_rooms':
        return planData['name'] == 'Discipline+' && planData['status'] == 'active';

      case 'community_posts':
        return planData['name'] == 'Discipline' ||
            planData['name'] == 'Elite' ||
            planData['name'] == 'Discipline+';

      default:
        return false;
    }
  }

  // Actualizar a un plan de pago
  Future<bool> upgradePlan(String planName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Aquí iría la lógica para procesar el pago con una pasarela de pagos

      // Actualizar el plan en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'plan': {
          'name': planName,
          'status': 'active',
          'subscriptionId': 'subscription_${DateTime.now().millisecondsSinceEpoch}',
          'lastPaymentDate': FieldValue.serverTimestamp(),
          'nextPaymentDate': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 30))
          ),
        }
      });

      return true;
    } catch (e) {
      print('Error al actualizar el plan: $e');
      return false;
    }
  }

  // Cancelar suscripción
  Future<bool> cancelSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Aquí iría la lógica para cancelar la suscripción con la pasarela de pagos

      // Actualizar el estado en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'plan.status': 'cancelled',
      });

      return true;
    } catch (e) {
      print('Error al cancelar la suscripción: $e');
      return false;
    }
  }
}