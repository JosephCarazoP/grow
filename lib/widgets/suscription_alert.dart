// lib/widgets/subscription_alert.dart
import 'package:flutter/material.dart';
import '../services/suscription_service.dart';

class SubscriptionAlert extends StatelessWidget {
  final SubscriptionInfo subscriptionInfo;
  final VoidCallback? onRenewPressed;

  const SubscriptionAlert({
    Key? key,
    required this.subscriptionInfo,
    this.onRenewPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (subscriptionInfo.status == SubscriptionStatus.active) {
      // Solo mostrar si está próximo a expirar (7 días o menos)
      if (subscriptionInfo.daysUntilExpiration != null &&
          subscriptionInfo.daysUntilExpiration! <= 7) {
        return _buildWarningAlert(context);
      }
      return const SizedBox.shrink();
    }

    if (subscriptionInfo.status == SubscriptionStatus.gracePeriod) {
      return _buildGracePeriodAlert(context);
    }

    if (subscriptionInfo.status == SubscriptionStatus.gracePeriodExpired) {
      return _buildExpiredAlert(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildWarningAlert(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suscripción próxima a expirar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu suscripción expira en ${subscriptionInfo.daysUntilExpiration} días',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRenewPressed, child: const Text('Renovar')),
        ],
      ),
    );
  }

  Widget _buildGracePeriodAlert(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suscripción expirada - Período de gracia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu período de gracia termina en ${subscriptionInfo.gracePeriodDaysLeft} días',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRenewPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Renovar suscripción'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredAlert(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.block, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Acceso restringido',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu período de gracia ha terminado. Renueva tu suscripción para continuar accediendo a esta sala.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRenewPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Renovar suscripción',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
