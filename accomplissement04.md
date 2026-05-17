# Accomplissements 04 — Session débogage & optimisation

**Date :** 24–25 avril 2026
**App :** nomade_client (Flutter / Firebase / Riverpod)

---

## Résumé général

Cette session a porté sur l'analyse de trois logs de débogage successifs, la correction de 5 bugs
(dont un crash null, une régression de performance, un bug Cloud Function critique, et une double
notification), ainsi que la mise en place complète d'App Check.

---

## 1. Crash — `SmallDot` null check operator

### Symptôme (log 2)
```
The following _TypeError was thrown building SmallDot(dirty):
Null check operator used on a null value
SmallDot:featured_item_card.dart:79:28
```
Cascade de 99939px d'overflow sur toutes les `FeaturedItemCard`.

### Cause
`small_dot.dart:14` utilisait `bodyLarge!.color!.withValues(...)`. Le champ `color` est `null`
dans le thème configuré → crash garanti à chaque affichage de carte menu.

### Fix
**Fichier :** `lib/components/small_dot.dart`
```dart
// Avant
color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.4),

// Après
color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black54).withValues(alpha: 0.4),
```

---

## 2. Régression performance — 241 frames skippés au lieu de 137

### Symptôme (log 2)
```
Skipped 43 frames   ← nouveau spike App Check
Skipped 133 frames  ← spike FCM (existant)
Skipped 65 frames   ← retry App Check "Too many attempts"
Total : 241 frames
```

### Cause
`await FirebaseAppCheck.instance.activate()` bloquait en série dans `main()`.
Le token de debug n'étant pas encore enregistré dans la Firebase Console,
App Check déclenchait une boucle de retry agressive (403 + "Too many attempts")
qui générait de la pression GC pendant le rendu des premiers frames.

### Fix
**Fichier :** `lib/main.dart`
```dart
// Avant
await FirebaseAppCheck.instance.activate(...);

// Après
unawaited(FirebaseAppCheck.instance.activate(...));
```
App Check s'initialise maintenant en parallèle de `Future.wait([Hive, LocalCache, Translations])`
au lieu de les précéder en série.

**Résultat après enregistrement du token debug + fix :** 44 + 108 = **152 frames**
(retour au niveau initial ~137 frames, le spike FCM restant étant structurel et inévitable).

---

## 3. App Check — token debug à enregistrer (action manuelle)

**Token :** `667ad01a-1990-4cb0-aa29-a583737809c4`

Le token s'affiche dans les logs Android :
```
D/DebugAppCheckProvider: Enter this debug secret into the allow list...
```

**Action :** Firebase Console → App Check → Applications → app Android → Gérer les tokens de débogage → ajouter le token.

Sans cela : erreurs `403 App attestation failed` sur tous les appels Firestore/Functions.

---

## 4. Bug Cloud Function — `sendRestaurantNotification` retournait `internal/Requested entity was not found`

### Symptôme (logs 2 et 3)
```
⚠️ [FoodNotification] CF non disponible: [firebase_functions/internal] Requested entity was not found.
```

### Analyse
La fonction était bien déployée (`firebase functions:list` confirmé), région `us-central1` correcte
des deux côtés, App Check non enforced sur Functions.

**Cause réelle :** le FCM token du restaurant (Pizzaolo Snack) était expiré.
`getMessaging().send()` lançait "Requested entity was not found" depuis l'API FCM.
Le `catch (err)` global capturait cette erreur et la rethrowait en `HttpsError("internal", err.message)`,
ce qui remontait à Flutter comme une erreur bloquante.

### Fix
**Fichier :** `functions/index.js` — `sendRestaurantNotification`

Séparation du try-catch en deux blocs distincts :
- Erreurs Firestore (lecture doc restaurant) → `throw HttpsError("internal")` conservé
- Restaurant non trouvé → retourne `{ success: false }` sans throw
- Erreurs FCM → retourne `{ success: false }`, nettoie automatiquement le token stale dans Firestore

```js
// Nettoyage automatique si token invalide
const isStaleToken = fcmErr.code === "messaging/registration-token-not-registered" ||
                     (fcmErr.message && fcmErr.message.includes("Requested entity was not found"));
if (isStaleToken) {
  await getFirestore().collection("restaurants").doc(restaurantId).update({ fcmToken: null });
}
return { success: false, message: fcmErr.message };
```

---

## 5. Fix Flutter — région explicite pour Cloud Functions

**Fichier :** `lib/services/food_notification_service.dart`

```dart
// Avant
final FirebaseFunctions _functions = FirebaseFunctions.instance;

// Après
final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
```

Force le SDK Flutter à utiliser l'URL correcte pour les callables v2.

---

## 6. Bug — Double notification restaurant à chaque commande

### Symptôme (log 4)
```
I/flutter (20826): 📲 [Background] Notification: 🔔 Nouvelle commande !
I/flutter (20826): 📲 [Background] Notification: 🔔 Nouvelle commande !  ← doublon
```

### Cause
Deux chemins envoyaient la même notification FCM en parallèle :
1. `sendRestaurantNotification` (callable) appelée explicitement depuis Flutter
2. `onOrderCreated` (Firestore trigger) se déclenchant automatiquement à la création de l'order

### Fix
**Fichier :** `functions/index.js` — `onOrderCreated`

Suppression de l'envoi FCM dans le trigger. La notification est entièrement gérée
par le callable `sendRestaurantNotification`.

```js
// onOrderCreated ne fait plus que logger — pas de FCM
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
  console.log("📦 Nouvelle commande créée:", orderId, "restaurant:", order.restaurantId);
});
```

---

## Déploiements effectués

| Commande | Fonctions déployées |
|---|---|
| `firebase deploy --only functions:sendRestaurantNotification` | Fix try-catch FCM + nettoyage token stale |
| `firebase deploy --only functions:onOrderCreated,functions:sendRestaurantNotification` | Suppression double notification |

---

## Tests de validation (log 4)

- [x] Commande créée → `✅ [OrderService] Commande créée: 4F9BgNLKMBvsgM8BlJAR` ✅
- [x] attachOrder instantané (chemin `initialOrder`) ✅
- [x] Navigation vers `OrderTrackingScreen` ✅
- [x] Stream Firestore actif → statut `pending` reçu ✅
- [x] Cloud Function notification restaurant → `✅ Notification envoyée via Cloud Function` ✅
- [x] `messageId: projects/nomade253-478a9/messages/...` ✅
- [x] Plus de crash `SmallDot` ✅
- [x] Performance stable : 44 + 108 = 152 frames ✅

---

## Bilan des fichiers modifiés

| Fichier | Modification |
|---|---|
| `lib/components/small_dot.dart` | `bodyLarge!.color!` → `?.color ?? Colors.black54` |
| `lib/main.dart` | `await AppCheck.activate` → `unawaited(AppCheck.activate)` |
| `lib/services/food_notification_service.dart` | `FirebaseFunctions.instance` → `instanceFor(region: 'us-central1')` |
| `functions/index.js` — `sendRestaurantNotification` | Séparation try-catch, nettoyage token FCM stale |
| `functions/index.js` — `onOrderCreated` | Suppression envoi FCM (double notification) |
