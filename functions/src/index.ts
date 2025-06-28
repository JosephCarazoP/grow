import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
admin.initializeApp();

// Función para enviar notificación cuando se aprueba una membresía
export const sendMembershipApprovedNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    // Obtener el token FCM del usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(notification.userId)
      .get();

    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: notification.type || 'general',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high' as const,
          notification: {
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
      };

      try {
        await admin.messaging().send(message);
        console.log('Notificación enviada exitosamente');
      } catch (error) {
        console.error('Error enviando notificación:', error);
      }
    }
  });

// Función helper para enviar notificaciones
export const sendNotificationToUser = async (
  userId: string,
  title: string,
  body: string,
  data?: any
) => {
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId)
    .get();

  const fcmToken = userDoc.data()?.fcmToken;

  if (fcmToken) {
    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        priority: 'high' as const,
      },
    };

    return admin.messaging().send(message);
  }
};

// Función programada para actualizar membresías expiradas
export const updateExpiredMemberships = functions.pubsub
  .schedule("every 24 hours")
  .timeZone("America/Costa_Rica")
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    try {
      // Buscar todas las membresías
      const membersSnapshot = await db.collection("members").get();

      const batch = db.batch();
      let expiredCount = 0;

      for (const doc of membersSnapshot.docs) {
        const memberData = doc.data();

        // Solo procesar membresías activas
        if (memberData.status === "active" && memberData.expiresAt) {
          const expiresAt = memberData.expiresAt;

          // Si ya expiró
          if (expiresAt.toMillis() < now.toMillis()) {
            batch.update(doc.ref, {
              status: "inactive",
              lastUpdated: now,
            });
            expiredCount++;
          }
        }
      }

      // Ejecutar batch si hay actualizaciones
      if (expiredCount > 0) {
        await batch.commit();
        console.log(`Actualizadas ${expiredCount} membresías a inactive`);
      }

      return null;
    } catch (error) {
      console.error("Error actualizando membresías:", error);
      return null;
    }
  });