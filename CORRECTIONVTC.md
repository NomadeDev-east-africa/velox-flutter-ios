# CORRECTIONS VTC TAXI — Nomade 253
Date : 14 mai 2026

---

## PROBLÈME DE DÉPART

Le client créait une course VTC avec succès (statut `requested` dans Firestore),
mais le chauffeur ne recevait jamais de notification. La course restait bloquée
indéfiniment en statut `requested`.

---

## DIAGNOSTIC (via MCP Firebase + lecture du code)

### Cause racine #1 — Index Firestore manquants (CRITIQUE)

La Cloud Function `onTaxiRideCreated` exécute cette query :
```js
.where("isOnline",      "==", true)
.where("isAvailable",   "==", true)
.where("lastHeartbeat", ">=", heartbeatLimit)
```
Firestore exige un index composite pour combiner deux égalités + une inégalité
sur un champ différent. Sans cet index → exception Firestore silencieuse →
la fonction crashe dans le `catch` → aucun chauffeur trouvé → aucune notification.

Même problème sur `cleanupDeadDrivers` :
```js
.where("isOnline",      "==", true)
.where("lastHeartbeat", "<",  heartbeatLimit)
```
→ Le chauffeur zombie restait `isOnline: true` indéfiniment.

### Cause racine #2 — Heartbeat chauffeur expiré (51 jours)

Le seul chauffeur en base (`ZXa4bYGyhMhhpDiTbNqtnQhkDzu2`) avait :
- `isOnline: true` ✅
- `lastHeartbeat: 2026-03-24` (51 jours sans ouvrir l'app) ❌

Même avec les index corrigés, il sera filtré jusqu'à réouverture de l'app.

### Cause racine #3 — `firestore.indexes.json` inexistant

Aucun fichier d'index n'existait dans le projet → aucun index composite déployé.

---

## INCOHÉRENCES ENTRE CLIENT ET APP CHAUFFEUR (Velox_driver)

### 1. Type FCM incompatible (CRITIQUE)
| Côté | Valeur |
|------|--------|
| CF `sendRideOfferToDriver` envoyait | `"new_ride_request"` |
| Driver app `VeloxMessagingService` attendait | `"newRide"` |

→ Notification reçue mais routée dans le mauvais canal Android.

### 2. Channel ID Android inexistant (CRITIQUE)
| Côté | Valeur |
|------|--------|
| CF envoyait | `channelId: "rides"` |
| Driver app déclarait | `"ride_requests"`, `"ride_status"`, `"location_service"` |

→ Sur Android 8+ en arrière-plan : notification muette ou ignorée.

### 3. Acceptation bypass la Cloud Function (CRITIQUE)
Le driver app fait une transaction Firestore directe (`RideRepository.acceptRide`)
au lieu d'appeler la CF `acceptRideTx`.
- `onRideUpdated` se déclenche sur `requested → accepted` mais n'avait pas
  de cas `accepted` → **le client ne recevait jamais la notification "chauffeur accepté"**.
- `driverPhotoUrl` non écrit dans Firestore.
- `offerExpiresAt` non remis à `null`.

### 4. Statut `noDriverAvailable` vs `no_driver_available`
| CF écrivait | Driver app enum |
|-------------|----------------|
| `"no_driver_available"` | `NO_DRIVER("noDriverAvailable")` |

### 5. Index manquant pour la query du chauffeur
`observeAvailableRides` dans le driver app :
```kotlin
.whereEqualTo("targetedDriverId", driverId)
.whereEqualTo("status", "requested")
.whereEqualTo("driverId", null)
.whereGreaterThan("requestedAt", cutoff)
```
→ Requiert un index composite `(targetedDriverId, status, driverId, requestedAt)`.

### 6. Crash recovery VTC manquant côté client
`_listenForActiveRide()` n'existait pas dans `main.dart`.
Au redémarrage après crash, le client n'était pas redirigé vers `TrackingScreen`
malgré le `rideId` sauvegardé dans Hive.
Les types FCM VTC dans `_consumePendingNotification()` étaient obsolètes
(`ride_accepted`, `ride_update` au lieu des vrais types de la CF).

---

## CORRECTIONS APPLIQUÉES

### `firestore.indexes.json` (créé)
- Index `(isOnline, isAvailable, lastHeartbeat)` sur `drivers` → corrige `onTaxiRideCreated`
- Index `(isOnline, lastHeartbeat)` sur `drivers` → corrige `cleanupDeadDrivers`
- Index `(targetedDriverId, status, driverId, requestedAt)` sur `taxiRides` → corrige query driver app
- Index `(driverId, status, completedAt)` sur `taxiRides` → corrige revenus du jour
- Tous les index existants du projet intégrés (orders, menu_items, livreurNotifications, etc.)
  pour éviter la question de suppression aux futurs déploiements

### `firebase.json` (modifié)
- Ajout de la section `"firestore": { "indexes": "firestore.indexes.json" }`

### `functions/index.js` (3 corrections)
1. `type: "new_ride_request"` → `"newRide"` dans `sendRideOfferToDriver()`
2. `channelId: "rides"` → `"ride_requests"` dans `sendRideOfferToDriver()`
3. Ajout du cas `accepted` dans `onRideUpdated` :
   quand le driver accepte directement via Firestore, le client reçoit
   maintenant la notification "chauffeur accepté" via le trigger.

### `Velox_driver` — `RideRepository.kt` (modifié)
- Ajout du paramètre `driverPhotoUrl` dans `acceptRide()`
- Écriture de `driverPhotoUrl`, `offerExpiresAt: null`, `updatedAt` dans la transaction

### `Velox_driver` — `HomeViewModel.kt` (modifié)
- Passage de `driver.photoUrl` au nouvel appel `acceptRide()`

### `Velox_driver` — `Ride.kt` (modifié)
- `NO_DRIVER("noDriverAvailable")` → `NO_DRIVER("no_driver_available")`

### `lib/main.dart` (modifié)
- Ajout de `_listenForActiveRide()` : surveille `activeRideProvider` au démarrage
  et navigue automatiquement vers `TrackingScreen` si course active en Hive
- Ajout de `_navigateToActiveRide()` avec flag `_activeRideNavigated`
- `_listenForActiveRide()` appelé dans `initState` → `addPostFrameCallback`
- `_activeRideSub` fermé dans `dispose()`
- `_consumePendingNotification()` mis à jour avec tous les types VTC réels :
  `driver_accepted`, `driver_arriving`, `driver_arrived`, `ride_started`,
  `ride_completed`, `ride_cancelled`, `no_driver_available`

### `lib/services/notification_service.dart` (modifié)
- `_handleMessageClick()` mis à jour avec les mêmes types FCM VTC

---

## DÉPLOIEMENT EFFECTUÉ

```bash
firebase deploy --only firestore:indexes   # ✅ Deploy complete!
```

---

## ACTIONS RESTANTES

```bash
# 1. Déployer la Cloud Function (corrections type FCM + handler accepted)
firebase deploy --only functions

# 2. Rebuilder et déployer l'app chauffeur Velox_driver
./gradlew assembleRelease

# 3. Le chauffeur doit ouvrir l'app Velox_driver
#    → heartbeat mis à jour → visible dans la query onTaxiRideCreated
```

---

## FLUX COMPLET APRÈS CORRECTIONS

```
Client sélectionne destination
        ↓
Course créée dans taxiRides (status: requested)
        ↓
CF onTaxiRideCreated déclenché
        ↓
Query drivers : isOnline + isAvailable + lastHeartbeat récent  ← INDEX OK
        ↓
FCM envoyé au chauffeur : type="newRide", channelId="ride_requests"  ← CORRIGÉ
        ↓
Driver app reçoit la notification dans le bon canal
        ↓
Chauffeur accepte → RideRepository.acceptRide() (Firestore direct)
        ↓
CF onRideUpdated déclenché : requested → accepted  ← HANDLER AJOUTÉ
        ↓
FCM envoyé au client : type="driver_accepted"
        ↓
Client reçoit la notification + TrackingScreen mis à jour en temps réel
```

---

## CRASH RECOVERY CLIENT (après corrections)

```
App crash / kill OS
        ↓
Client relance l'app
        ↓
HiveService.getRideId() → rideId trouvé
        ↓
ActiveRideNotifier._init() : Hive → Firestore → stream
        ↓
_listenForActiveRide() détecte hasActiveRide == true  ← AJOUTÉ
        ↓
Navigation automatique vers TrackingScreen
        ↓
Client reprend la course là où il en était
```
