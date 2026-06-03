// ============================================================
// FIREBASE CLOUD FUNCTIONS V2 - Nomade 253
// VERSION PRODUCTION — 27 Mars 2026
// ============================================================
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError}  = require("firebase-functions/v2/https");
const {onSchedule}          = require("firebase-functions/v2/scheduler");
const {initializeApp}       = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging}        = require("firebase-admin/messaging");

initializeApp();

// ─────────────────────────────────────────────────────────────
// CONSTANTES GLOBALES
// ─────────────────────────────────────────────────────────────
const OFFER_TIMEOUT_SECONDS     = 30;
const RIDE_MAX_AGE_MINUTES      = 30;
const HEARTBEAT_TIMEOUT_MINUTES = 2;   // Driver considéré mort après 2 min sans heartbeat
const STUCK_RIDE_TIMEOUTS = {
  accepted: 30,   // 30 min sans transition → annulé
  arriving: 20,   // 20 min en transit vers le client → annulé
  arrived:  15,   // 15 min sans démarrer → annulé
  started:  180,  // 3h de course → annulé
};

// Statuts valides pour une course en attente
// En production Nomade253, le client écrit toujours "requested"
// Les autres sont gardés pour compatibilité ascendante
const PENDING_STATUSES = ["requested", "pending", "waiting", "new", "created"];

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : distance Haversine (km)
// ─────────────────────────────────────────────────────────────
function haversineKm(lat1, lon1, lat2, lon2) {
  const R    = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Vérifier si un driver a une course active
// ─────────────────────────────────────────────────────────────
async function driverHasActiveRide(driverId) {
  const activeRide = await getFirestore()
    .collection("taxiRides")
    .where("driverId", "==", driverId)
    .where("status", "in", ["accepted", "arriving", "arrived", "started"])
    .limit(1)
    .get();
  return !activeRide.empty;
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Récupérer le FCM token client via user_id
// ✅ FIX : utilise user_id (doc direct) au lieu de query par phone
//          → 1 read garanti au lieu d'une requête multi-docs
// ─────────────────────────────────────────────────────────────
async function getClientFcmToken(ride) {
  try {
    // Priorité 1 : user_id — lookup direct O(1), fiable
    if (ride.userId) {
      const userDoc = await getFirestore().collection("users").doc(ride.userId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        return userDoc.data().fcmToken;
      }
    }
    // Priorité 2 : user_phone — fallback si user_id absent
    const phoneField = ride.userPhone || ride.clientPhone;
    if (phoneField) {
      const userQuery = await getFirestore()
        .collection("users")
        .where("phone", "==", phoneField)
        .limit(1)
        .get();
      if (!userQuery.empty && userQuery.docs[0].data().fcmToken) {
        return userQuery.docs[0].data().fcmToken;
      }
    }
    return null;
  } catch (err) {
    console.error("❌ getClientFcmToken:", err.message);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Envoyer une offre de course FCM à un driver
// ─────────────────────────────────────────────────────────────
async function sendRideOfferToDriver(driverToken, rideId, ride) {
  return getMessaging().send({
    token: driverToken,
    notification: {
      title: "🚕 Nouvelle course disponible !",
      body:  `${ride.pickup?.address || "Adresse"} → ${ride.destination?.address || "Destination"} — ${Math.round(ride.estimatedFare || 0)} FDJ`,
    },
    data: {
      type:               "newRide",
      rideId:             rideId,
      pickup:             JSON.stringify(ride.pickup      || {}),
      destination:        JSON.stringify(ride.destination || {}),
      estimatedFare:     String(ride.estimatedFare      || 0),
      estimatedDistance: String(ride.estimatedDistance  || 0),
      estimated_duration: String(ride.estimatedDuration  || 0),
    },
    android: {
      priority: "high",
      notification: { sound: "default", channelId: "ride_requests", priority: "high" },
    },
    apns: { payload: { aps: { sound: "default", contentAvailable: true } } },
  });
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Calculer offer_expires_at (now + 30s)
// ─────────────────────────────────────────────────────────────
function nextOfferExpiry() {
  return new Date(Date.now() + OFFER_TIMEOUT_SECONDS * 1000);
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Assigner un driver à une course
// Partagé par onTaxiRideCreated et cleanupExpiredOffers
// En cas d'erreur, met le statut à "no_driver_available"
// pour éviter les rides bloquées à "requested" indéfiniment.
// ─────────────────────────────────────────────────────────────
async function assignDriverToRide(db, rideRef, rideId, ride) {
  const pickupLat = ride.pickup?.latitude;
  const pickupLng = ride.pickup?.longitude;
  if (!pickupLat || !pickupLng) {
    console.error(`❌ [assignDriver] Coordonnées pickup manquantes: ${rideId}`);
    return;
  }

  try {
    const heartbeatLimit = new Date(Date.now() - HEARTBEAT_TIMEOUT_MINUTES * 60 * 1000);

    const driversSnap = await db
      .collection("drivers")
      .where("isOnline",      "==", true)
      .where("isAvailable",   "==", true)
      .where("lastHeartbeat", ">=", heartbeatLimit)
      .get();

    console.log(`  [assignDriver] ${rideId} — drivers vivants: ${driversSnap.size}`);

    if (driversSnap.empty) {
      console.warn(`⚠️ [assignDriver] ${rideId}: aucun driver vivant`);
      await rideRef.update({ status: "no_driver_available", updatedAt: FieldValue.serverTimestamp() });
      return;
    }

    const candidates = [];
    driversSnap.forEach((doc) => {
      const d   = doc.data();
      const loc = d.currentLocation;
      if (!loc?.latitude || !loc?.longitude) return;
      if (!d.fcmToken)       return;
      if (!isDriverAlive(d)) return;
      const dist = haversineKm(pickupLat, pickupLng, loc.latitude, loc.longitude);
      candidates.push({ id: doc.id, data: d, distance: dist });
    });

    const radiuses = [5, 10, 15, 30, 50];
    let nearby = [];
    for (const radius of radiuses) {
      const found = candidates
        .filter((d) => d.distance <= radius)
        .sort((a, b) => a.distance - b.distance);
      if (found.length >= 3) { nearby = found; console.log(`  ✅ Rayon ${radius}km — ${found.length} drivers`); break; }
      else if (found.length > 0) nearby = found;
    }

    if (nearby.length === 0) {
      console.warn(`⚠️ [assignDriver] ${rideId}: aucun driver dans un rayon de 50km`);
      await rideRef.update({ status: "no_driver_available", updatedAt: FieldValue.serverTimestamp() });
      return;
    }

    const hasActiveChecks = await Promise.all(nearby.map((d) => driverHasActiveRide(d.id)));
    const validDrivers    = nearby.filter((_, i) => !hasActiveChecks[i]);

    if (validDrivers.length === 0) {
      console.warn(`⚠️ [assignDriver] ${rideId}: tous les drivers ont une course active`);
      await rideRef.update({ status: "no_driver_available", updatedAt: FieldValue.serverTimestamp() });
      return;
    }

    console.log(`  ✅ [assignDriver] ${rideId} — ${validDrivers.length} drivers éligibles`);

    const driverQueue  = validDrivers.map((d) => d.id);
    const targetDriver = validDrivers[0];

    await rideRef.update({
      targetedDriverId:  targetDriver.id,
      driverQueue:       driverQueue,
      currentOfferIndex: 0,
      offerSentAt:       FieldValue.serverTimestamp(),
      offerExpiresAt:    nextOfferExpiry(),
      updatedAt:         FieldValue.serverTimestamp(),
    });

    await sendRideOfferToDriver(targetDriver.data.fcmToken, rideId, ride);
    console.log(`✅ [assignDriver] ${rideId} → ${targetDriver.id} (${targetDriver.distance.toFixed(1)} km)`);

  } catch (err) {
    console.error(`❌ [assignDriver] Erreur pour ${rideId}:`, err);
    // Marquer la course pour éviter qu'elle reste bloquée à "requested"
    await rideRef.update({
      status:    "no_driver_available",
      updatedAt: FieldValue.serverTimestamp(),
    }).catch(() => {});
  }
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRE : Vérifier si un driver est vivant (heartbeat récent)
// ─────────────────────────────────────────────────────────────
function isDriverAlive(driverData) {
  if (!driverData.lastHeartbeat) return false;
  const hb = driverData.lastHeartbeat.toDate
    ? driverData.lastHeartbeat.toDate()
    : new Date(driverData.lastHeartbeat);
  const ageMs = Date.now() - hb.getTime();
  return ageMs < HEARTBEAT_TIMEOUT_MINUTES * 60 * 1000;
}

// =============================================================
// FONCTION 1 : Trigger — nouvelle course taxi créée
// =============================================================
exports.onTaxiRideCreated = onDocumentCreated(
  "taxiRides/{rideId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const ride   = snap.data();
    const rideId = event.params.rideId;

    console.log("🚕 Nouvelle course créée:", rideId, "status:", ride.status);

    if (!PENDING_STATUSES.includes(ride.status)) {
      console.log("⏭️ Statut non éligible:", ride.status);
      return;
    }
    if (ride.driverId) {
      console.log("⏭️ Course déjà assignée");
      return;
    }

    const pickupLat = ride.pickup?.latitude;
    const pickupLng = ride.pickup?.longitude;
    if (!pickupLat || !pickupLng) {
      console.error("❌ Coordonnées pickup manquantes");
      return;
    }

    await assignDriverToRide(getFirestore(), snap.ref, rideId, ride);
  }
);

// =============================================================
// FONCTION 2 : Acceptation atomique d'une course
// =============================================================
exports.acceptRideTx = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Vous devez être connecté");

  const driverId = request.auth.uid;
  const { rideId, driverName, driverPhone, driverPhotoUrl, vehicleId } = request.data;
  if (!rideId) throw new HttpsError("invalid-argument", "rideId est requis");

  console.log(`🚕 acceptRideTx: driver=${driverId} ride=${rideId}`);

  const db      = getFirestore();
  const rideRef = db.collection("taxiRides").doc(rideId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const rideDoc = await tx.get(rideRef);
      if (!rideDoc.exists) throw new HttpsError("not-found", "Course introuvable");

      const ride = rideDoc.data();

      if (!PENDING_STATUSES.includes(ride.status)) {
        throw new HttpsError("failed-precondition", `Course non disponible (statut: ${ride.status})`);
      }
      if (ride.driverId) {
        throw new HttpsError("already-exists", "Course déjà assignée à un autre chauffeur");
      }
      if (ride.offerExpiresAt) {
        const expiresAt = ride.offerExpiresAt.toDate
          ? ride.offerExpiresAt.toDate()
          : new Date(ride.offerExpiresAt);
        if (new Date() > expiresAt) {
          throw new HttpsError("deadline-exceeded", "Offre expirée");
        }
      }
      if (ride.requestedAt) {
        const requestedMs = ride.requestedAt.toMillis
          ? ride.requestedAt.toMillis()
          : new Date(ride.requestedAt).getTime();
        const ageMs = Date.now() - requestedMs;
        if (ageMs > RIDE_MAX_AGE_MINUTES * 60 * 1000) {
          throw new HttpsError("deadline-exceeded", "Course expirée");
        }
      }

      tx.update(rideRef, {
        driverId:        driverId,
        driverName:      driverName     || "",
        driverPhone:     driverPhone    || "",
        driverPhotoUrl: driverPhotoUrl || null,
        vehicleId:       vehicleId      || "",
        status:           "accepted",
        acceptedAt:      FieldValue.serverTimestamp(),
        offerExpiresAt: null,
        updatedAt:        FieldValue.serverTimestamp(),
      });

      console.log(`✅ Course ${rideId} assignée atomiquement à ${driverId}`);
      return { success: true, rideId, driverId };
    });

    // ── Notification client : driver trouvé ─────────────────────
    // ✅ FIX : lecture du doc après transaction + getClientFcmToken
    try {
      const rideDoc = await rideRef.get();
      const ride    = rideDoc.data();
      const clientToken = await getClientFcmToken(ride);

      if (clientToken) {
        // ✅ FIX : estimated_duration est en MINUTES (pas secondes)
        const eta = ride.estimatedDuration || 5;
        await getMessaging().send({
          token: clientToken,
          notification: {
            title: "✅ Un chauffeur a accepté votre course",
            body:  `${driverName} arrive dans ${eta} min — ${driverPhone}`,
          },
          data: {
            type:        "driver_accepted",
            rideId:      rideId,
            driverName:  driverName  || "",
            driverPhone: driverPhone || "",
            eta:         String(eta),
          },
          android: { priority: "high", notification: { channelId: "rides" } },
        });
        console.log("✅ Notification 'driver accepté' envoyée au client");
      }
    } catch (notifErr) {
      console.error("❌ Erreur notification client (acceptation):", notifErr.message);
    }

    return result;

  } catch (err) {
    if (err instanceof HttpsError) throw err;
    console.error("❌ Erreur transaction acceptRideTx:", err);
    throw new HttpsError("internal", "Erreur lors de l'acceptation de la course");
  }
});

// =============================================================
// FONCTION 3 : Passer au driver suivant (refus / timeout manuel)
// ─── Utilise une boucle while — PAS de récursif ✅
// =============================================================
exports.sendNextDriverOffer = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");

  const { rideId } = request.data;
  if (!rideId) throw new HttpsError("invalid-argument", "rideId requis");

  console.log("⏭️ sendNextDriverOffer:", rideId);

  const db      = getFirestore();
  const rideRef = db.collection("taxiRides").doc(rideId);

  try {
    const rideDoc = await rideRef.get();
    if (!rideDoc.exists) throw new HttpsError("not-found", "Course introuvable");

    const ride = rideDoc.data();
    if (ride.driverId) return { success: false, message: "Course déjà acceptée" };

    const queue        = ride.driverQueue        || [];
    const currentIndex = ride.currentOfferIndex || 0;
    let   nextIndex    = currentIndex + 1;

    // ✅ Boucle while — pas d'appel récursif
    while (nextIndex < queue.length) {
      const candidateId = queue[nextIndex];

      const driverDoc  = await db.collection("drivers").doc(candidateId).get();
      if (!driverDoc.exists) { nextIndex++; continue; }

      const driverData = driverDoc.data();

      // Vérifier token + heartbeat + pas de course active
      if (!driverData.fcmToken) {
        console.log(`  ⏭️ ${candidateId}: pas de token FCM`);
        nextIndex++;
        continue;
      }
      if (!isDriverAlive(driverData)) {
        console.log(`  ⏭️ ${candidateId}: heartbeat expiré`);
        nextIndex++;
        continue;
      }
      if (!driverData.isAvailable || !driverData.isOnline) {
        console.log(`  ⏭️ ${candidateId}: hors ligne ou indisponible`);
        nextIndex++;
        continue;
      }
      const hasActive = await driverHasActiveRide(candidateId);
      if (hasActive) {
        console.log(`  ⏭️ ${candidateId}: course active en cours`);
        nextIndex++;
        continue;
      }

      // ✅ Driver valide trouvé
      await rideRef.update({
        targetedDriverId:  candidateId,
        currentOfferIndex: nextIndex,
        offerSentAt:       FieldValue.serverTimestamp(),
        offerExpiresAt:    nextOfferExpiry(),
        updatedAt:           FieldValue.serverTimestamp(),
      });

      await sendRideOfferToDriver(driverData.fcmToken, rideId, ride);
      console.log(`✅ Offre envoyée au driver suivant: ${candidateId} (index ${nextIndex})`);
      return { success: true, nextDriverId: candidateId, index: nextIndex };
    }

    // ── Plus aucun driver dans la queue ─────────────────────────
    console.warn("⚠️ Queue épuisée — aucun driver disponible:", rideId);
    await rideRef.update({
      status:          "no_driver_available",
      offerExpiresAt: null,
      updatedAt:       FieldValue.serverTimestamp(),
    });

    // Notifier le client que personne n'est disponible
    try {
      const rideData    = (await rideRef.get()).data();
      const clientToken = await getClientFcmToken(rideData);
      if (clientToken) {
        await getMessaging().send({
          token: clientToken,
          notification: {
            title: "⚠️ Aucun chauffeur disponible",
            body:  "Veuillez réessayer dans quelques minutes",
          },
          data: { type: "no_driver_available", rideId },
          android: { priority: "high", notification: { channelId: "rides" } },
        });
      }
    } catch (notifErr) {
      console.error("❌ Erreur notification no_driver:", notifErr.message);
    }

    return { success: false, message: "Aucun autre driver disponible" };

  } catch (err) {
    if (err instanceof HttpsError) throw err;
    console.error("❌ Erreur sendNextDriverOffer:", err);
    throw new HttpsError("internal", err.message);
  }
});

// =============================================================
// FONCTION 4 : Scheduler — nettoyage offres expirées (toutes les 1 min)
// =============================================================
exports.cleanupExpiredOffers = onSchedule(
  "every 1 minutes",
  async () => {
    console.log("🧹 Cleanup offres expirées...");

    const db  = getFirestore();
    const now = new Date();

    try {
      const expiredSnap = await db
        .collection("taxiRides")
        .where("status",          "in", PENDING_STATUSES)
        .where("offerExpiresAt", "<", now)
        .where("driverId",       "==", null)
        .get();

      console.log(`  ${expiredSnap.size} offres expirées`);

      const promises = expiredSnap.docs.map(async (doc) => {
        const ride         = doc.data();
        const queue        = ride.driverQueue        || [];
        const currentIndex = ride.currentOfferIndex || 0;
        let   nextIndex    = currentIndex + 1;

        while (nextIndex < queue.length) {
          const candidateId = queue[nextIndex];
          const driverDoc   = await db.collection("drivers").doc(candidateId).get();

          if (!driverDoc.exists) { nextIndex++; continue; }

          const driverData = driverDoc.data();

          if (!driverData.fcmToken || !isDriverAlive(driverData) ||
              !driverData.isAvailable || !driverData.isOnline) {
            nextIndex++;
            continue;
          }

          const hasActive = await driverHasActiveRide(candidateId);
          if (hasActive) { nextIndex++; continue; }

          await doc.ref.update({
            targetedDriverId:  candidateId,
            currentOfferIndex: nextIndex,
            offerSentAt:       FieldValue.serverTimestamp(),
            offerExpiresAt:    nextOfferExpiry(),
            updatedAt:           FieldValue.serverTimestamp(),
          });

          await sendRideOfferToDriver(driverData.fcmToken, doc.id, ride);
          console.log(`  ➡️ Course ${doc.id}: offre → ${candidateId}`);
          return;
        }

        // Queue épuisée
        await doc.ref.update({
          status:          "no_driver_available",
          offerExpiresAt: null,
          updatedAt:       FieldValue.serverTimestamp(),
        });
        console.log(`  ⛔ Course ${doc.id}: no_driver_available`);
      });

      await Promise.allSettled(promises);
      console.log("✅ Cleanup offres terminé");

    } catch (err) {
      console.error("❌ Erreur cleanupExpiredOffers:", err);
    }

    // ── Rides abandonnées : CF crashée lors de la création ──────
    // Courses "requested" depuis > 2 min sans driverQueue
    // (onTaxiRideCreated n'a jamais écrit targetedDriverId)
    try {
      const abandonedSnap = await db
        .collection("taxiRides")
        .where("status", "==", "requested")
        .get();

      const cutoff    = new Date(now.getTime() - 2 * 60 * 1000);
      const abandoned = abandonedSnap.docs.filter((doc) => {
        const d = doc.data();
        const requestedAt = d.requestedAt?.toDate?.();
        return !d.driverId
          && (!d.driverQueue || d.driverQueue.length === 0)
          && requestedAt instanceof Date
          && requestedAt < cutoff;
      });

      if (abandoned.length > 0) {
        console.log(`  🔄 ${abandoned.length} ride(s) abandonnée(s) → réassignation`);
        await Promise.allSettled(
          abandoned.map((doc) =>
            assignDriverToRide(db, doc.ref, doc.id, doc.data())
          )
        );
      }
    } catch (err) {
      console.error("❌ Erreur récupération rides abandonnées:", err);
    }
  }
);

// =============================================================
// FONCTION 5 : Scheduler — nettoyage courses bloquées (toutes les 5 min)
// =============================================================
exports.cleanupStuckRides = onSchedule(
  "every 5 minutes",
  async () => {
    console.log("🔧 Nettoyage courses bloquées...");

    const db  = getFirestore();
    const now = new Date();
    let   cleaned = 0;

    try {
      const [acceptedSnap, arrivingSnap, arrivedSnap, startedSnap] = await Promise.all([
        db.collection("taxiRides")
          .where("status", "==", "accepted")
          .where("acceptedAt", "<", new Date(now - STUCK_RIDE_TIMEOUTS.accepted * 60 * 1000))
          .get(),
        db.collection("taxiRides")
          .where("status", "==", "arriving")
          .where("arrivingAt", "<", new Date(now - STUCK_RIDE_TIMEOUTS.arriving * 60 * 1000))
          .get(),
        db.collection("taxiRides")
          .where("status", "==", "arrived")
          .where("arrivedAt", "<", new Date(now - STUCK_RIDE_TIMEOUTS.arrived * 60 * 1000))
          .get(),
        db.collection("taxiRides")
          .where("status", "==", "started")
          .where("startedAt", "<", new Date(now - STUCK_RIDE_TIMEOUTS.started * 60 * 1000))
          .get(),
      ]);

      const allStuck = [
        ...acceptedSnap.docs,
        ...arrivingSnap.docs,
        ...arrivedSnap.docs,
        ...startedSnap.docs,
      ];

      for (const doc of allStuck) {
        const ride = doc.data();
        console.log(`  ⚠️ Course bloquée: ${doc.id} (${ride.status})`);

        await doc.ref.update({
          status:              "cancelled",
          cancelledAt:        FieldValue.serverTimestamp(),
          cancellationReason: "timeout_system",
          cancelledBy:        "system",
          updatedAt:           FieldValue.serverTimestamp(),
        });

        if (ride.driverId) {
          await db.collection("drivers").doc(ride.driverId).update({
            isAvailable: true,
            updatedAt:    FieldValue.serverTimestamp(),
          });
          console.log(`  ✅ Driver ${ride.driverId} libéré`);
        }

        cleaned++;
      }

      console.log(`✅ ${cleaned} courses bloquées nettoyées`);

    } catch (err) {
      console.error("❌ Erreur cleanupStuckRides:", err);
    }
  }
);

// =============================================================
// FONCTION 6 : Heartbeat driver
// =============================================================
exports.driverHeartbeat = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");

  const driverId = request.auth.uid;
  const { latitude, longitude } = request.data;

  const db         = getFirestore();
  const driverRef  = db.collection("drivers").doc(driverId);

  try {
    const updateData = {
      lastHeartbeat: FieldValue.serverTimestamp(),
      updatedAt:      FieldValue.serverTimestamp(),
    };

    if (latitude && longitude) {
      updateData.currentLocation = {
        latitude,
        longitude,
        updatedAt: FieldValue.serverTimestamp(),
      };
    }

    await driverRef.update(updateData);
    return { success: true };

  } catch (err) {
    console.error("❌ Erreur driverHeartbeat:", err);
    throw new HttpsError("internal", err.message);
  }
});

// =============================================================
// FONCTION 7 : Scheduler — nettoyage drivers morts (toutes les 1 min)
// =============================================================
exports.cleanupDeadDrivers = onSchedule(
  "every 1 minutes",
  async () => {
    console.log("💀 Nettoyage drivers morts...");

    const db             = getFirestore();
    const heartbeatLimit = new Date(Date.now() - HEARTBEAT_TIMEOUT_MINUTES * 60 * 1000);

    try {
      const deadSnap = await db
        .collection("drivers")
        .where("isOnline",      "==", true)
        .where("lastHeartbeat", "<",  heartbeatLimit)
        .get();

      console.log(`  ${deadSnap.size} drivers morts potentiels`);
      let cleaned = 0;

      for (const doc of deadSnap.docs) {
        const hasActive = await driverHasActiveRide(doc.id);
        if (hasActive) {
          console.log(`  ⏭️ Driver ${doc.id} a une course active — préservé`);
          continue;
        }

        await doc.ref.update({
          isOnline:      false,
          isAvailable:   false,
          offlineReason: "heartbeat_timeout",
          updatedAt:      FieldValue.serverTimestamp(),
        });
        cleaned++;
      }

      console.log(`✅ ${cleaned} drivers nettoyés`);

    } catch (err) {
      console.error("❌ Erreur cleanupDeadDrivers:", err);
    }
  }
);

// =============================================================
// FONCTION 8 : Trigger — mise à jour statut de course
// ✅ FIX : utilise user_id + estimated_duration déjà en minutes
// =============================================================
exports.onRideUpdated = onDocumentUpdated(
  "taxiRides/{rideId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    const rideId = event.params.rideId;

    if (!before || !after)                    return;
    if (before.status === after.status)       return;

    console.log(`🔄 Course ${rideId}: ${before.status} → ${after.status}`);

    const db = getFirestore();

    try {
      // ✅ FIX : récupération token client via user_id (plus rapide)
      const clientToken = await getClientFcmToken(after);

      // Récupération token driver
      let driverToken = null;
      if (after.driverId) {
        const driverDoc = await db.collection("drivers").doc(after.driverId).get();
        if (driverDoc.exists) driverToken = driverDoc.data().fcmToken;
      }

      // ── Driver a accepté la course (via app chauffeur directement) ──
      if (after.status === "accepted" && before.status !== "accepted") {
        if (clientToken) {
          const eta = after.estimatedDuration || 5;
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "✅ Un chauffeur a accepté votre course",
              body:  `${after.driverName || "Votre chauffeur"} arrive dans ${eta} min — ${after.driverPhone || ""}`,
            },
            data: {
              type:        "driver_accepted",
              rideId:      rideId,
              driverName:  after.driverName  || "",
              driverPhone: after.driverPhone || "",
              eta:         String(eta),
            },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
          console.log("✅ Notif 'driver accepté' envoyée au client (via onRideUpdated)");
        }
      }

      // ── Driver en route vers le client ────────────────────────
      if (after.status === "arriving" && before.status !== "arriving") {
        if (before.status !== "accepted") {
          console.warn(`⚠️ Transition invalide ${before.status} → arriving (course ${rideId})`);
          return;
        }
        if (clientToken) {
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "🚕 Votre chauffeur arrive",
              body:  `${after.driverName} est en route vers vous`,
            },
            data: { type: "driver_arriving", rideId },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
          console.log("✅ Notif 'en route' envoyée au client");
        }
      }

      // ── Arrivée du driver ──────────────────────────────────────
      if (after.status === "arrived" && before.status !== "arrived") {
        if (before.status !== "accepted" && before.status !== "arriving") {
          console.warn(`⚠️ Transition invalide ${before.status} → arrived (course ${rideId})`);
          return;
        }
        if (clientToken) {
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "📍 Votre chauffeur est arrivé",
              body:  `${after.driverName} vous attend à ${after.pickup?.address || "votre adresse"}`,
            },
            data: { type: "driver_arrived", rideId },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
          console.log("✅ Notif 'arrivé' envoyée au client");
        }
      }

      // ── Course démarrée ────────────────────────────────────────
      if (after.status === "started" && before.status !== "started") {
        if (before.status !== "arrived") {
          console.warn(`⚠️ Transition invalide ${before.status} → started (course ${rideId})`);
          return;
        }
        if (clientToken) {
          const eta = after.estimatedDuration || 10;
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "🚗 Course commencée",
              body:  `Direction ${after.destination?.address || "destination"} — Arrivée dans ${eta} min`,
            },
            data: { type: "ride_started", rideId },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
          console.log("✅ Notif 'course démarrée' envoyée au client");
        }
      }

      // ── Course terminée ────────────────────────────────────────
      if (after.status === "completed" && before.status !== "completed") {
        if (before.status !== "started") {
          console.warn(`⚠️ Transition invalide ${before.status} → completed (course ${rideId})`);
          return;
        }
        if (clientToken) {
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "✅ Course terminée",
              body:  `Merci d'avoir voyagé avec Nomade 253 ! ${Math.round(after.finalFare || 0)} FDJ`,
            },
            data: {
              type:  "ride_completed",
              rideId,
              fare:  String(after.finalFare || 0),
            },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
          console.log("✅ Notif 'terminée' envoyée au client");
        }

        if (driverToken) {
          // Calcul revenus du jour
          const todayStart = new Date();
          todayStart.setHours(0, 0, 0, 0);

          const completedToday = await db
            .collection("taxiRides")
            .where("driverId",    "==", after.driverId)
            .where("status",       "==", "completed")
            .where("completedAt", ">=", todayStart)
            .get();

          const dailyTotal = completedToday.docs.reduce(
            (sum, d) => sum + (d.data().finalFare || 0), 0
          );

          await getMessaging().send({
            token: driverToken,
            notification: {
              title: "💰 Course terminée",
              body:  `+${Math.round(after.finalFare || 0)} FDJ — Total aujourd'hui: ${Math.round(dailyTotal)} FDJ`,
            },
            data: {
              type:  "earnings_updated",
              rideId,
              fare:  String(after.finalFare || 0),
            },
            android: { priority: "high", notification: { channelId: "earnings" } },
          });
          console.log("✅ Notif revenus envoyée au driver");
        }
      }

      // ── Course annulée ─────────────────────────────────────────
      if (after.status === "cancelled" && before.status !== "cancelled") {
        const cancelledBy = after.cancelledBy || "system";

        if (cancelledBy === "driver" && clientToken) {
          await getMessaging().send({
            token: clientToken,
            notification: {
              title: "❌ Course annulée par le chauffeur",
              body:  "Nous recherchons un autre chauffeur pour vous",
            },
            data: { type: "ride_cancelled", rideId, by: "driver" },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
        } else if (cancelledBy === "customer" && driverToken) {
          await getMessaging().send({
            token: driverToken,
            notification: {
              title: "❌ Course annulée par le client",
              body:  "Vous êtes disponible pour une nouvelle course",
            },
            data: { type: "ride_cancelled", rideId, by: "customer" },
            android: { priority: "high", notification: { channelId: "rides" } },
          });
        }
      }

    } catch (err) {
      console.error("❌ Erreur onRideUpdated:", err);
    }
  }
);

// =============================================================
// FONCTION 9 : Trigger — notation chauffeur taxi
// Déclenché quand le client soumet sa note depuis RideCompletedScreen.
// Recalcule la moyenne du chauffeur à partir de toutes ses courses notées.
// =============================================================
exports.onTaxiRideRated = onDocumentUpdated(
  "taxiRides/{rideId}",
  async (event) => {
    const before  = event.data?.before?.data();
    const after   = event.data?.after?.data();

    if (!before || !after) return;

    // Déclencher uniquement quand userRating vient d'être défini
    if (before.userRating === after.userRating) return;
    if (!after.driverId || !after.userRating)   return;
    if (after.userRating < 1 || after.userRating > 5) return;

    const db       = getFirestore();
    const driverId = after.driverId;

    console.log(`⭐ onTaxiRideRated: ride=${event.params.rideId} driver=${driverId} rating=${after.userRating}`);

    try {
      const driverRef = db.collection("drivers").doc(driverId);

      await db.runTransaction(async (tx) => {
        const driverDoc = await tx.get(driverRef);
        if (!driverDoc.exists) {
          console.warn(`⚠️ Driver ${driverId} introuvable`);
          return;
        }

        const data     = driverDoc.data();
        const oldSum   = data.ratingSum   || 0;
        const oldCount = data.ratingCount || 0;
        const newSum   = oldSum   + after.userRating;
        const newCount = oldCount + 1;
        const newAvg   = Math.round((newSum / newCount) * 10) / 10;

        tx.update(driverRef, {
          ratingSum:    newSum,
          ratingCount:  newCount,
          rating:       newAvg,
          totalRatings: newCount,
          updatedAt:    FieldValue.serverTimestamp(),
        });

        console.log(`✅ Driver ${driverId}: moyenne ${newAvg} (${newCount} notes)`);
      });
    } catch (err) {
      console.error("❌ Erreur onTaxiRideRated:", err);
    }
  }
);

// =============================================================
// FONCTIONS FOOD (inchangées — déjà en production)
// =============================================================
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const order   = snap.data();
  const orderId = event.params.orderId;
  console.log("📦 Nouvelle commande créée:", orderId, "restaurant:", order.restaurantId);

  // ── Validation des prix côté serveur ────────────────────────
  const db    = getFirestore();
  const items = order.items || [];
  if (items.length === 0) return;

  try {
    // Récupérer les vrais prix depuis menuItems en parallèle
    const menuDocs = await Promise.all(
      items.map((item) => db.collection("menuItems").doc(item.menuId).get())
    );

    let priceValid   = true;
    let realSubtotal = 0;

    for (let i = 0; i < items.length; i++) {
      const item    = items[i];
      const menuDoc = menuDocs[i];

      // Article introuvable → annulation immédiate
      if (!menuDoc.exists) {
        console.warn(`[validatePrices] Article ${item.menuId} introuvable → annulation`);
        await snap.ref.update({
          status:             "cancelled",
          cancellationReason: `Article introuvable: ${item.name || item.menuId}`,
          cancelledBy:        "system",
          cancelledAt:        FieldValue.serverTimestamp(),
          updatedAt:          FieldValue.serverTimestamp(),
        });
        return;
      }

      const realBasePrice = menuDoc.data().price ?? 0;
      const extrasTotal   = item.extrasTotal ?? 0;
      const saucesTotal   = item.saucesTotal ?? 0;
      const realUnitPrice = realBasePrice + extrasTotal + saucesTotal;
      realSubtotal       += realUnitPrice * (item.quantity ?? 1);

      if (realBasePrice !== item.basePrice) {
        console.warn(
          `[validatePrices] ${item.name}: client=${item.basePrice} réel=${realBasePrice}`
        );
        priceValid = false;
      }
    }

    const deliveryFee = order.deliveryFee ?? 500;
    const realTotal   = realSubtotal + deliveryFee;

    if (!priceValid || realTotal !== order.total) {
      console.warn(`[validatePrices] ${orderId} — correction: ${order.total} → ${realTotal} FDJ`);
      await snap.ref.update({
        subtotal:       realSubtotal,
        total:          realTotal,
        priceValidated: true,
        updatedAt:      FieldValue.serverTimestamp(),
      });
    } else {
      await snap.ref.update({
        priceValidated: true,
        updatedAt:      FieldValue.serverTimestamp(),
      });
      console.log(`✅ [validatePrices] ${orderId} — prix valides: ${realTotal} FDJ`);
    }
  } catch (err) {
    console.error(`❌ [validatePrices] ${orderId}:`, err);
  }

  // ── Notification restaurant ──────────────────────────────────
  // Envoi côté serveur (Admin SDK) — fiable même si le client est déjà parti
  if (!order.restaurantId) return;
  try {
    const restaurantDoc = await db.collection("restaurants").doc(order.restaurantId).get();
    if (!restaurantDoc.exists) {
      console.warn(`⚠️ [onOrderCreated] Restaurant introuvable: ${order.restaurantId}`);
      return;
    }
    const fcmToken = restaurantDoc.data().fcmToken;
    if (!fcmToken) {
      console.warn(`⚠️ [onOrderCreated] Pas de token FCM pour restaurant ${order.restaurantId}`);
      return;
    }
    const customerName = order.customerName || order.userName || "Client";
    const total        = order.total || 0;
    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "🔔 Nouvelle commande !",
        body:  `${customerName} a commandé pour ${total} FDJ`,
      },
      data: {
        type:         "new_order",
        orderId,
        restaurantId: order.restaurantId,
        customerName,
        total:        total.toString(),
      },
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "orders" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });
    console.log(`✅ [onOrderCreated] Notification restaurant envoyée: ${order.restaurantId}`);
  } catch (notifErr) {
    const stale = notifErr.code === "messaging/registration-token-not-registered" ||
                  (notifErr.message && notifErr.message.includes("Requested entity was not found"));
    if (stale) {
      console.log(`🗑️ Token FCM invalide pour restaurant ${order.restaurantId} — nettoyage`);
      await db.collection("restaurants").doc(order.restaurantId).update({ fcmToken: null });
    } else {
      console.error("❌ [onOrderCreated] Erreur notification restaurant:", notifErr.message);
    }
  }
});

exports.sendRestaurantNotification = onCall(async (request) => {
  const { restaurantId, orderId, customerName, total } = request.data;

  let doc;
  try {
    doc = await getFirestore().collection("restaurants").doc(restaurantId).get();
  } catch (err) {
    throw new HttpsError("internal", err.message);
  }

  if (!doc.exists) return { success: false, message: "Restaurant non trouvé" };
  const fcmToken = doc.data().fcmToken;
  if (!fcmToken) return { success: false, message: "Pas de token FCM" };

  try {
    const response = await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "🔔 Nouvelle commande !",
        body:  `${customerName} a commandé pour ${total} FDJ`,
      },
      data: { type: "new_order", orderId, restaurantId, customerName, total: total.toString() },
      android: { priority: "high", notification: { sound: "default", channelId: "orders" } },
      apns:    { payload: { aps: { sound: "default" } } },
    });
    return { success: true, messageId: response };
  } catch (fcmErr) {
    console.warn(`⚠️ FCM sendRestaurantNotification: ${fcmErr.message}`);
    const isStaleToken = fcmErr.code === "messaging/registration-token-not-registered" ||
                         (fcmErr.message && fcmErr.message.includes("Requested entity was not found"));
    if (isStaleToken) {
      console.log(`🗑️ Token FCM invalide pour restaurant ${restaurantId} — nettoyage`);
      await getFirestore().collection("restaurants").doc(restaurantId).update({ fcmToken: null });
    }
    return { success: false, message: fcmErr.message };
  }
});

exports.sendFCMNotification = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Vous devez être connecté");
  const { token, title, body, data } = request.data;
  if (!token) throw new HttpsError("invalid-argument", "token est requis");
  try {
    const response = await getMessaging().send({
      token, notification: { title, body }, data: data || {},
    });
    return { success: true, messageId: response };
  } catch (err) {
    throw new HttpsError("internal", err.message);
  }
});

exports.sendOrderReadyNotifications = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Vous devez être connecté");
  const { orderId } = request.data;
  if (!orderId) throw new HttpsError("invalid-argument", "orderId est requis");
  console.log("📦 sendOrderReadyNotifications:", orderId);
  try {
    const orderDoc = await getFirestore().collection("orders").doc(orderId).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Commande non trouvée");
    const order = orderDoc.data();

    await getFirestore().collection("orders").doc(orderId).update({
      status: "ready", readyAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });

    const livreurSnap = await getFirestore()
      .collection("livreurs")
      .where("isAvailable", "==", true)
      .where("isOnline",    "==", true)
      .get();

    if (livreurSnap.empty) {
      return { success: false, message: "Aucun livreur disponible", driversSent: 0, clientSent: false };
    }

    const promises = [];
    livreurSnap.forEach((livreurDoc) => {
      const livreur   = livreurDoc.data();
      const livreurId = livreurDoc.id;
      if (!livreur.fcmToken) return;

      const promise = (async () => {
        try {
          await getMessaging().send({
            token: livreur.fcmToken,
            notification: {
              title: "🛵 Nouvelle livraison !",
              body:  `Commande de ${order.userName || order.customerName || "Client"} — ${order.total} FDJ`,
            },
            data: {
              type: "order_ready_for_delivery", orderId,
              restaurantName: order.restaurantName || "", restaurantId: order.restaurantId || "",
              customerName:   order.userName       || order.customerName   || "",
              customerPhone:  order.userPhone      || order.customerPhone  || "",
              deliveryAddress: order.deliveryAddress || "", total: order.total.toString(),
            },
            android: { priority: "high", notification: { sound: "default", channelId: "orders", priority: "high" } },
            apns:    { payload: { aps: { sound: "default", contentAvailable: true } } },
          });
        } catch (e) { console.warn("⚠️ FCM livreur:", e.message); }

        try {
          const notifData = {
            userId: livreurId, type: "food_delivery", orderId,
            title:  "🍽️ Nouvelle livraison !",
            body:   `De ${order.restaurantName || "Restaurant"} vers ${order.deliveryAddress || "Adresse"}`,
            data: {
              order_type: "food",
              restaurant_name:  order.restaurantName    || "",
              pickup_address:   order.restaurantAddress || "",
              delivery_address: order.deliveryAddress   || "",
              customer_name:    order.userName          || order.customerName  || "",
              customer_phone:   order.userPhone         || order.customerPhone || "",
              total:            order.total             || 0,
              estimated_distance: 5,
              estimated_time:     15,
            },
            createdAt: FieldValue.serverTimestamp(),
            read:      false,
            accepted:  false,
            rejected:  false,
          };
          if (order.deliveryLocation) notifData.data.delivery_location = order.deliveryLocation;
          await getFirestore().collection("livreurNotifications").add(notifData);
        } catch (e) { console.error("❌ Erreur notif Firestore livreur:", e.message); }
      })();
      promises.push(promise);
    });

    await Promise.allSettled(promises);

    let clientSent = false;
    // Lookup direct par userId (O(1)) — cohérent avec getClientFcmToken
    const clientDoc = order.userId
      ? await getFirestore().collection("users").doc(order.userId).get()
      : null;

    if (clientDoc && clientDoc.exists) {
      const client = clientDoc.data();
      if (client.fcmToken) {
        try {
          await getMessaging().send({
            token: client.fcmToken,
            notification: {
              title: "✅ Votre commande est prête",
              body:  "Un livreur arrive sous peu pour récupérer votre commande",
            },
            data: { type: "order_ready_client", orderId },
            android: { priority: "high", notification: { sound: "default", channelId: "orders" } },
            apns:    { payload: { aps: { sound: "default" } } },
          });
          clientSent = true;
        } catch (e) { console.warn("⚠️ Erreur notif client food:", e.message); }
      }
    }

    // ── Incrément stats restaurant (server-side uniquement) ──────
    if (order.restaurantId) {
      try {
        await getFirestore().collection("restaurants").doc(order.restaurantId).update({
          totalOrders:  FieldValue.increment(1),
          totalRevenue: FieldValue.increment(order.total || 0),
          updatedAt:    FieldValue.serverTimestamp(),
        });
        console.log(`✅ Stats restaurant ${order.restaurantId} mises à jour`);
      } catch (statsErr) {
        console.error("❌ Erreur stats restaurant:", statsErr.message);
      }
    }

    return {
      success:    true,
      driversSent: promises.length,
      clientSent,
      message:    `${promises.length} livreur(s) notifié(s), client: ${clientSent ? "notifié" : "pas de token"}`,
    };

  } catch (err) {
    console.error("❌ Erreur sendOrderReadyNotifications:", err);
    throw new HttpsError("internal", err.message);
  }
});

// =============================================================
// FONCTION FOOD : Trigger — notation commande terminée
// Déclenché quand le client soumet ses notes depuis OrderCompletedScreen.
// Met à jour la moyenne du restaurant + la moyenne du livreur,
// et crée un document review dans restaurants/{id}/reviews.
// =============================================================
exports.onOrderRated = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before  = event.data?.before?.data();
    const after   = event.data?.after?.data();
    const orderId = event.params.orderId;

    if (!before || !after) return;

    // On ne déclenche que lorsque ratedAt vient d'être défini
    if (before.ratedAt || !after.ratedAt) return;

    const restaurantRating = after.restaurantRating;
    const driverRating     = after.driverRating;
    const restaurantId     = after.restaurantId;
    const driverId         = after.deliveryDriverId;
    const comment          = after.restaurantComment || "";
    const customerName     = after.customerName || "Client";

    console.log(`⭐ onOrderRated: order=${orderId} restaurantRating=${restaurantRating} driverRating=${driverRating}`);

    const db = getFirestore();

    // ── 1. Mettre à jour la moyenne du restaurant ────────────────
    if (restaurantId && restaurantRating >= 1 && restaurantRating <= 5) {
      try {
        const restaurantRef = db.collection("restaurants").doc(restaurantId);

        await db.runTransaction(async (tx) => {
          const restaurantDoc = await tx.get(restaurantRef);
          if (!restaurantDoc.exists) {
            console.warn(`⚠️ Restaurant ${restaurantId} introuvable`);
            return;
          }

          const data       = restaurantDoc.data();
          const oldSum     = data.ratingSum   || 0;
          const oldCount   = data.ratingCount || 0;
          const newSum     = oldSum   + restaurantRating;
          const newCount   = oldCount + 1;
          const newAverage = Math.round((newSum / newCount) * 10) / 10; // arrondi 1 décimale

          tx.update(restaurantRef, {
            ratingSum:   newSum,
            ratingCount: newCount,
            rating:      newAverage,
            updatedAt:   FieldValue.serverTimestamp(),
          });
        });

        // Ajouter l'avis dans la sous-collection reviews
        await db
          .collection("restaurants")
          .doc(restaurantId)
          .collection("reviews")
          .doc(orderId)
          .set({
            orderId,
            rating:      restaurantRating,
            comment:     comment,
            customerName,
            createdAt:   FieldValue.serverTimestamp(),
          });

        console.log(`✅ Restaurant ${restaurantId}: moyenne mise à jour + avis ajouté`);
      } catch (err) {
        console.error("❌ Erreur mise à jour rating restaurant:", err);
      }
    }

    // ── 2. Mettre à jour la moyenne du livreur ───────────────────
    if (driverId && driverRating >= 1 && driverRating <= 5) {
      try {
        const livreurRef = db.collection("livreurs").doc(driverId);

        await db.runTransaction(async (tx) => {
          const livreurDoc = await tx.get(livreurRef);
          if (!livreurDoc.exists) {
            console.warn(`⚠️ Livreur ${driverId} introuvable`);
            return;
          }

          const data       = livreurDoc.data();
          const oldSum     = data.ratingSum   || 0;
          const oldCount   = data.ratingCount || 0;
          const newSum     = oldSum   + driverRating;
          const newCount   = oldCount + 1;
          const newAverage = Math.round((newSum / newCount) * 10) / 10;

          tx.update(livreurRef, {
            ratingSum:   newSum,
            ratingCount: newCount,
            rating:      newAverage,
            updatedAt:   FieldValue.serverTimestamp(),
          });
        });

        console.log(`✅ Livreur ${driverId}: moyenne mise à jour`);
      } catch (err) {
        console.error("❌ Erreur mise à jour rating livreur:", err);
      }
    }
  }
);