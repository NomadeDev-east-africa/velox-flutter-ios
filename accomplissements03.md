# Accomplissements 03 — Session de débogage & optimisation

Date : 17 avril 2026  
App : nomade_client (Flutter / Firebase / Riverpod)

---

## Résumé général

Cette session a porté sur la correction de 3 bugs bloquants signalés après les sessions précédentes,
le renommage complet de la terminologie "driver" → "livreur", la mise en place du système
de notation post-livraison, l'affichage des avis clients dans la page restaurant,
et une optimisation de performance sur la navigation vers le suivi de commande.

---

## 1. Bug — Position du livreur toujours null (TrackDeliveryScreen)

### Symptôme
La page "Voir livreur" affichait systématiquement "Position du livreur non disponible"
alors que le livreur avait une position GPS active dans Firestore.

### Analyse (3 itérations)

**Itération 1** — Mauvaise collection Firestore  
Le code lisait la collection `drivers` (taxi) au lieu de `livreurs` (food delivery).  
Fix : suppression de `DriverService`, écoute directe de `livreurs/{livreurId}`.

**Itération 2** — asyncExpand + .take(1) cassait le stream  
L'utilisation de `.take(1)` sur le stream livreur faisait que seul le premier snapshot
était reçu. Chaque mise à jour du document `orders` relançait une nouvelle subscription
qui s'arrêtait immédiatement après 1 événement.  
Fix : simplification vers un stream direct sur `livreurs/{livreurId}`.

**Itération 3 (cause racine)** — GeoPoint vs Map  
La fonction `_extrairePositionDepuisMap()` retournait `null` pour tout champ non-Map.
Or, dans la collection `livreurs`, le champ `currentLocation` est un **GeoPoint direct**
(pas un Map `{latitude, longitude}`), comme confirmé par la structure Firestore :
```
currentLocation: [11.5754218° N, 43.1330302° E] (geopoint)
```
Fix dans `track_delivery_screen.dart` :
```dart
if (raw is GeoPoint) {
  final ts = data['updatedAt'];
  return LivreurLocation(
    latitude:  raw.latitude,
    longitude: raw.longitude,
    miseAJour: ts is Timestamp ? ts.toDate() : DateTime.now(),
  );
}
// fallback Map {latitude, longitude} conservé
return _extrairePositionDepuisMap(raw);
```

### Fichier modifié
`lib/screens/food/food_tracking/track_delivery_screen.dart`

---

## 2. Bug — Livreur app n'écrivait jamais currentLocation dans Firestore

### Symptôme
Même avec le fix GeoPoint côté client, `currentLocation` n'était jamais mis à jour
dans Firestore car l'app livreur ne l'écrivait pas.

### Cause racine (identifiée côté livreur app)
Dans `livreur_notifier.dart`, `updateLocation()` avait ce guard :
```dart
final livreur = state.valueOrNull;
if (livreur == null) return; // ← GPS jamais écrit si LivreurNotifier en timeout
```
Quand le `LivreurNotifier` était en timeout (state = null), toutes les mises à jour
GPS étaient silencieusement ignorées.

### Corrections appliquées côté livreur app
| Fichier | Correction |
|---|---|
| `livreur_notifier.dart` | `updateLocation` utilise `FirebaseAuth.instance.currentUser?.uid` directement — GPS écrit même si LivreurNotifier est en timeout |
| `location_service.dart` | `update()` → `set(merge:true)` — crée le doc livreur s'il n'existe pas |
| `notification_notifier.dart` | `markNotificationAsRead` auto quand `acceptOrder` échoue |

---

## 3. Bug — "Confirmer livraison" disparaissait avant que l'utilisateur puisse appuyer

### Symptôme
Après que le livreur marquait la commande comme livrée, le statut passait à `completed`,
`activeOrderProvider` nettoyait automatiquement l'état après 4 secondes, et le bouton
"Confirmer livraison" disparaissait — l'utilisateur était renvoyé à l'accueil sans passer
par `OrderCompletedScreen`.

### Cause
`_buildBody()` dans `OrderTrackingScreen` dépendait directement de `orderState.order`
pour afficher le bouton. Quand `activeOrderProvider` effaçait l'order (auto-clear 4s),
le bouton disparaissait avec lui.

### Fix — Cache local `_completedOrder`
Ajout d'un champ `Order? _completedOrder` dans le state du widget.
Avant chaque build, si le statut est `completed`, l'order est sauvegardé localement.
Même après que `activeOrderProvider` efface l'order, le bouton reste visible grâce au cache local.

```dart
// Dans _buildBody() :
if (orderState.order != null &&
    orderState.order!.status == Order.statusCompleted) {
  _completedOrder = orderState.order;
}

// Quand activeOrderProvider efface → on utilise _completedOrder
if (orderState.order == null && _completedOrder != null) {
  // → afficher le bouton "Confirmer livraison" avec _completedOrder
}
```

### Fichier modifié
`lib/screens/food/food_tracking/order_tracking_screen.dart`

---

## 4. Bug — Notations post-livraison n'apparaissaient pas dans Firebase

### Symptôme
L'utilisateur soumettait ses notes sur `OrderCompletedScreen` mais rien n'apparaissait
dans Firebase — ni dans `orders`, ni dans `restaurants/{id}/avis`.

### Cause
`_submitRatings()` n'écrivait qu'un seul champ dans `orders/{id}` et ne créait
aucun document dans la sous-collection `restaurants/{id}/avis`.

### Fix — 4 écritures Firestore dans `_submitRatings()`
```dart
// 1. Mettre à jour la commande
await db.collection('orders').doc(widget.order.id).update({
  'restaurantRating': _restaurantRating,
  'livreurRating':    _driverRating,
  if (comment.isNotEmpty) 'restaurantComment': comment,
  'ratedAt': now,
});

// 2. Créer l'avis dans la sous-collection du restaurant
await db.collection('restaurants')
    .doc(widget.order.restaurantId)
    .collection('avis')
    .add({
  'orderId':     widget.order.id,
  'userId':      widget.order.userId,
  'clientNom':   widget.order.customerName,
  'note':        _restaurantRating,
  'commentaire': comment,
  'createdAt':   now,
});

// 3. Mettre à jour l'agrégat de note du restaurant
await db.collection('restaurants').doc(widget.order.restaurantId).update({
  'ratingSum':   FieldValue.increment(_restaurantRating),
  'ratingCount': FieldValue.increment(1),
  'updatedAt':   now,
});

// 4. Mettre à jour l'agrégat de note du livreur
if (widget.order.deliveryDriverId != null) {
  await db.collection('livreurs').doc(widget.order.deliveryDriverId).update({
    'ratingSum':   FieldValue.increment(_driverRating),
    'ratingCount': FieldValue.increment(1),
    'updatedAt':   now,
  });
}
```

### Fichier modifié
`lib/screens/food/food_tracking/order_completed_screen.dart`

---

## 5. Avis clients non affichés dans la page restaurant

### Symptôme
La page détail restaurant (`DetailsScreen`) n'affichait aucun avis client,
même après soumission de notations.

### Cause
`RestaurantInfo` affichait uniquement la note statique `widget.restaurant.rating`.
Aucune section d'avis n'existait dans `DetailsScreen`.

### Fix — Nouveau widget `_AvisSection`
Ajout d'un `StreamBuilder` qui écoute `restaurants/{id}/avis` en temps réel.
Affiche uniquement les avis avec un commentaire non vide.
Chaque carte avis contient : étoiles, commentaire, nom du client, date.

```dart
class _AvisSection extends StatelessWidget {
  // StreamBuilder → restaurants/{id}/avis (orderBy createdAt desc, limit 20)
  // Filtre : commentaire non vide
  // Affichage : étoiles + commentaire + clientNom + date
}
```

Intégré dans `DetailsScreen` après la section `Items` :
```dart
_AvisSection(restaurantId: restaurant.id),
```

### Fichier modifié
`lib/screens/food/details/details_screen.dart`

---

## 6. Stream timeout trop agressif (faux déconnexions)

### Symptôme
Les logs montraient des `TimeoutException` fréquentes sur `activeOrderProvider`,
causant des reconnexions inutiles et des logs d'erreur trompeurs.

### Cause
Le timeout du stream Firestore était réglé à 90 secondes — trop court pour une
session de suivi de commande qui peut durer 20-30 minutes.

### Fix
```dart
// Avant
.timeout(const Duration(seconds: 90), ...)

// Après
.timeout(const Duration(minutes: 10), ...)
```

### Fichier modifié
`lib/providers/active_order_notifier.dart`

---

## 7. Renommage terminologie "driver" → "livreur"

### Contexte
Confusion possible entre `drivers` (collection taxi) et `livreurs` (collection food delivery).
Demande du développeur : utiliser exclusivement le terme "livreur" dans tout le code food.

### Changements effectués
- `TrackDeliveryScreen` : paramètres `driverId` → `livreurId`, `driverName` → `livreurName`
- `DriverLocation` → `LivreurLocation` (classe définie localement dans `track_delivery_screen.dart`)
- Toutes les méthodes et variables internes renommées : `driverPosition` → `livreurPosition`, etc.
- Suppression de la dépendance à `driver_service.dart` pour le tracking food
- Collection Firestore confirmée : `livreurs` (pas `drivers`)

### Fichier modifié
`lib/screens/food/food_tracking/track_delivery_screen.dart`

---

## 8. Optimisation — Navigation vers OrderTracking trop lente (> 1 minute)

### Symptôme
Après confirmation d'une commande, plus d'une minute s'écoulait avant que l'utilisateur
soit redirigé vers `OrderTrackingScreen`.

### Analyse
La séquence des logs révélait le blocage :
```
✅ [OrderService] Commande créée: z33DUhYOYgnHBMPhAyN0
🔗 [ActiveOrder] attachOrder appelé: z33DUhYOYgnHBMPhAyN0
                  ← isLoading: true, navigation BLOQUÉE
✅ [FoodNotification] Notification envoyée (Cloud Function)
✅ [ActiveOrder] Commande attachée  ← fetch Firestore terminé
🔄 [MyApp] navigation vers OrderTracking  ← seulement ICI
```

Dans `main.dart`, `_listenForActiveOrder()` ne déclenchait la navigation que quand
`!next.isLoading && next.hasActiveOrder`. Or, `isLoading` restait `true` pendant toute
la durée du one-time Firestore fetch dans `attachOrder` — un round-trip réseau inutile
puisque l'Order venait d'être créé et ses données étaient déjà connues localement.

### Fix — Paramètre `initialOrder` dans `attachOrder`

**`active_order_notifier.dart`** — nouveau chemin rapide :
```dart
Future<void> attachOrder(String orderId, {Order? initialOrder}) async {
  ...
  if (initialOrder != null) {
    // Skip fetch — state set immédiatement → navigation instantanée
    state = state.copyWith(order: initialOrder, isLoading: false, clearError: true);
    await _persistToHive(initialOrder);
  } else {
    // Fetch Firestore normal (restauration depuis Hive au démarrage)
    ...
  }
  _startStream(orderId); // stream temps réel démarré dans tous les cas
}
```

**`cart_notifier.dart`** — reconstruction de l'Order avec le vrai ID :
```dart
final createdOrder = Order(
  id: orderId,
  // ... tous les champs déjà connus localement
);

unawaited(
  _ref.read(activeOrderProvider.notifier)
      .attachOrder(orderId, initialOrder: createdOrder)
      ...
);
```

**Résultat** : navigation déclenchée en < 1 seconde après confirmation de commande
au lieu de plusieurs dizaines de secondes.

### Fichiers modifiés
- `lib/providers/active_order_notifier.dart`
- `lib/providers/cart_notifier.dart`

---

## Bilan des fichiers modifiés

| Fichier | Nature de la modification |
|---|---|
| `lib/screens/food/food_tracking/track_delivery_screen.dart` | Réécriture complète — GeoPoint, renommage livreur, LivreurLocation |
| `lib/screens/food/food_tracking/order_tracking_screen.dart` | Cache `_completedOrder` pour bouton "Confirmer livraison" |
| `lib/screens/food/food_tracking/order_completed_screen.dart` | 4 écritures Firestore pour notation |
| `lib/screens/food/details/details_screen.dart` | Ajout `_AvisSection` avec StreamBuilder |
| `lib/providers/active_order_notifier.dart` | Timeout 10min + paramètre `initialOrder` |
| `lib/providers/cart_notifier.dart` | Reconstruction Order + `initialOrder` dans attachOrder |

---

## Tests de validation effectués

- [x] Commande créée → notification restaurant envoyée ✅
- [x] Restaurant accepte → prépare → prêt → livreurs notifiés ✅
- [x] Statut commande : `pending` → `delivering` → `completed` ✅
- [x] Bouton "Confirmer livraison" reste visible après `completed` ✅
- [x] `OrderCompletedScreen` s'ouvre après confirmation ✅
- [x] Page "Voir livreur" affiche la carte avec position GPS en temps réel ✅
- [x] Navigation vers `OrderTrackingScreen` instantanée après correction ✅
- [x] Stream ActiveOrder sans faux timeouts ✅
