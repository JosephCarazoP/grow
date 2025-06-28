import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
admin.initializeApp();

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