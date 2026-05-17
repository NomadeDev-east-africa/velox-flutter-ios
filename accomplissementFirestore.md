# Accomplissements — Refonte Firestore Nomade 253

**Date :** 22 avril 2026  
**Périmètre :** ClientApp Flutter + Cloud Functions V2 + Firestore Security Rules

---

## Contexte

Audit complet de l'architecture Firestore de Nomade 253 (plateforme VTC + food delivery, Djibouti).  
Objectif : harmoniser les conventions de nommage, sécuriser les accès, supprimer le code mort et générer les règles de sécurité de production.

---

## 1. Analyse du code source

### 1.1 ClientApp Flutter
- Inventaire de toutes les collections lues/écrites (`taxiRides`, `orders`, `users`, `drivers`, `restaurants`, `livreurs`)
- Identification des sous-collections : `users/{uid}/addresses`, `users/{uid}/favorite_drivers`, `drivers/{id}/ratings`
- Audit de tous les champs écrits à la création (`taxiRides`, `orders`) et à la mise à jour (annulation, notation)
- Identification des règles métier côté client (statuts annulables, contraintes de notation)

### 1.2 Cloud Functions (index.js)
- Cartographie complète des 9 fonctions : triggers, schedulers, onCall
- Identification des champs réservés CF : `targetedDriverId`, `driverQueue`, `offerExpiresAt`, `driverId`, `rating`, `totalRatings`, etc.
- Confirmation de l'architecture FCM : notifications envoyées **directement** via `admin.messaging().send()` — pas via des collections intermédiaires
- Identification des collections de notifications mortes (`driver_notifications`, `user_notifications`, `restaurant_notifications`, `user_food_notifications`)

---

## 2. Harmonisation camelCase

**Problème :** La collection taxi s'appelait `taxi_rides` dans les Cloud Functions (snake_case) alors que le ClientApp Flutter utilisait déjà `taxiRides` (camelCase).

### `functions/index.js`
- Remplacement de **10 occurrences** de `"taxi_rides"` par `"taxiRides"`
  - Triggers : `onDocumentCreated("taxiRides/{rideId}")`, `onDocumentUpdated("taxiRides/{rideId}")`
  - Requêtes : `.collection("taxiRides")` dans `driverHasActiveRide`, `acceptRideTx`, `sendNextDriverOffer`, `cleanupExpiredOffers`, `cleanupStuckRides`, `onRideUpdated`

---

## 3. Nouvelle Cloud Function — onTaxiRideRated

**Problème :** Il n'existait pas de CF pour recalculer la note des chauffeurs taxi. Le client écrivait `rating` et `totalRatings` directement sur `drivers/{id}`, ce qui était un vecteur de manipulation de notes.

**Solution :** Ajout de `onTaxiRideRated` dans `functions/index.js`.

```
Trigger  : onDocumentUpdated("taxiRides/{rideId}")
Condition: userRating vient d'être défini (before.userRating != after.userRating)
Action   : agrégation sur toutes les courses notées du driver
           → calcul moyenne = Math.round((sum / count) * 10) / 10
           → écriture rating + totalRatings sur drivers/{driverId}
```

Aligné sur le pattern existant `onOrderRated` (restaurants + livreurs).

---

## 4. Suppression du code mort (services de notification)

### `lib/services/driver_notification_service.dart`
**Avant :** écrivait dans `driver_notifications` et `user_notifications` (collections jamais lues par les CF).  
**Après :** réduit à un **stub pur** — méthodes conservées (signature inchangée) pour ne pas casser `active_ride_notifier.dart` et `ride_provider.dart`, mais ne font plus aucune opération Firestore.  
Import `cloud_firestore` supprimé.

### `lib/services/food_notification_service.dart`
**Avant :** essayait d'appeler la CF `sendRestaurantNotification`, puis tombait en fallback sur `restaurant_notifications` (collection morte). Possédait aussi 5 méthodes écrivant dans `user_food_notifications` (collection morte).  
**Après :**
- Méthode `notifyRestaurantNewOrder` conservée — appel CF uniquement, fallback silencieux
- 5 méthodes `notifyOrder*` supprimées (non appelées)
- Enum `FoodNotificationType` supprimée
- Import `cloud_firestore` supprimé

### `lib/services/rating_service.dart`
**Avant :** `rateDriver()` appelait `_updateDriverRating()` qui écrivait `rating` et `totalRatings` directement sur `drivers/{id}`.  
**Après :**
- Méthode `_updateDriverRating()` supprimée
- Appel supprimé dans `rateDriver()`
- Le recalcul est désormais géré par la CF `onTaxiRideRated`

---

## 5. Firestore Security Rules — `firestore.rules`

Fichier généré à la racine du projet. Couvre l'ensemble de l'écosystème Nomade 253.

### Collections sécurisées

| Collection | CREATE | READ | UPDATE | DELETE |
|---|---|---|---|---|
| `taxiRides` | Client (userId) | Client + Driver assigné + Driver ciblé | Client (annul/note) + Driver (statut) | ❌ |
| `orders` | Client (userId) | Client + Livreur + Restaurant | Client (annul/note) + Restaurant + Livreur | ❌ |
| `users/{uid}` | Propriétaire | Propriétaire | Propriétaire (champs limités) | ❌ |
| `users/{uid}/addresses` | Propriétaire | Propriétaire | Propriétaire | Propriétaire |
| `users/{uid}/favorite_drivers` | Propriétaire | Propriétaire | Propriétaire | Propriétaire |
| `drivers/{id}` | Propriétaire | Tous (auth) | Propriétaire (champs limités) | ❌ |
| `drivers/{id}/ratings` | Client (course validée) | Tous (auth) | ❌ | ❌ |
| `livreurs/{id}` | Propriétaire | Tous (auth) | Propriétaire (champs limités) | ❌ |
| `restaurants/{id}` | Propriétaire | Tous (auth) | Propriétaire (champs limités) | ❌ |
| `restaurants/{id}/reviews` | ❌ (CF only) | Tous (auth) | ❌ | ❌ |
| `restaurants/{id}/menu` | Restaurant | Tous (auth) | Restaurant | Restaurant |
| `livreurNotifications` | ❌ (CF only) | Livreur concerné | Livreur (read/accepted) | ❌ |
| `driver_notifications` | ❌ | ❌ | ❌ | ❌ |
| `user_notifications` | ❌ | ❌ | ❌ | ❌ |
| `restaurant_notifications` | ❌ | ❌ | ❌ | ❌ |
| `user_food_notifications` | ❌ | ❌ | ❌ | ❌ |

### Règles métier enforced côté Firestore

- **Annulation taxi** : autorisée depuis `requested/pending/waiting/new/created/accepted/arrived` uniquement — `cancelledBy` forcément `'user'` ou `'customer'`
- **Annulation food** : autorisée depuis `pending` ou `confirmed` uniquement
- **Notation taxi** : uniquement si `status == 'completed'` ET `userRating == null` (une seule note)
- **Notation food** : uniquement si `status == 'delivered'` ET `ratedAt == null` (une seule note)
- **Note valide** : `isValidRating(r)` → `r is int && r >= 1 && r <= 5`
- **Champs réservés CF** : `rating`, `totalRatings`, `ratingSum`, `ratingCount`, `targetedDriverId`, `driverQueue`, `offerExpiresAt`, `driverId`, `acceptedAt`, `finalFare` — non modifiables par les clients
- **Anti-fraude notation driver** : création dans `drivers/{id}/ratings` validée par 3 lectures croisées sur `taxiRides` (userId, driverId, status)
- **Auto-assign livreur** : vérifié que le livreur existe dans `livreurs/{uid}` avant attribution

### Confirmation clé d'accès restaurants
`restaurantId` dans `orders` = Auth UID du gérant = doc ID dans `restaurants` → `isOwner(resource.data.restaurantId)` fonctionne sur toute la chaîne.

---

## 6. Politique de confidentialité — `politique_confidentialite.md`

Fichier généré à la racine du projet. Document complet en 12 sections :

1. Introduction
2. Données collectées (directes / automatiques / non collectées)
3. Finalités du traitement
4. Base légale
5. Partage des données (chauffeur, restaurant, livreur, Firebase, WaafiPay/D-Money)
6. Localisation géographique (premier plan uniquement)
7. Conservation des données (tableau par catégorie)
8. Sécurité (Firebase Auth, règles Firestore, TLS, Admin SDK)
9. Droits des utilisateurs
10. Cookies
11. Contact
12. Modifications

**À compléter avant publication :** adresse e-mail officielle et numéro de téléphone.

---

## 7. Inspection Firebase MCP — Données de production (22 avril 2026)

Inspection réelle du projet `nomade253-478a9` via Firebase MCP.

### 13 collections réelles identifiées

| Collection | Présente dans les règles (avant) | Action |
|---|---|---|
| `taxiRides` | ✅ | — |
| `orders` | ✅ | Bug `status` corrigé |
| `users` | ✅ | — |
| `drivers` | ✅ | — |
| `livreurs` | ✅ | — |
| `restaurants` | ✅ | — |
| `livreurNotifications` | ✅ | — |
| `driver_notifications` | ✅ (bloquée) | — |
| `user_notifications` | ✅ (bloquée) | — |
| `restaurant_notifications` | ✅ (bloquée) | — |
| `user_food_notifications` | ✅ (bloquée) | — |
| `admins` | ❌ | **Ajoutée — bloquée client** |
| `menu_items` | ❌ | **Ajoutée — lecture auth, écriture restaurant** |
| `promotions` | ❌ | **Ajoutée — lecture auth, écriture CF only** |

### Bugs critiques découverts

#### Bug 1 — `orders.status` ≠ `"delivered"`
- **Problème :** la règle de notation vérifiait `resource.data.status == 'delivered'` mais en production `status` vaut `"completed"` (c'est `deliveryStatus` qui vaut `"delivered"`).
- **Impact :** aucun client ne pouvait jamais noter une commande → la CF `onOrderRated` n'était jamais déclenchée.
- **Correction :** `status == 'delivered'` → `status == 'completed'` dans `firestore.rules`.

#### Bug 2 — `items` sérialisé en string
- **Problème :** toutes les commandes en production ont `items: "[[object Object]]"` — la liste d'items a été sérialisée via `.toString()` au lieu d'être encodée en JSON.
- **Impact :** données de commande corrompues, impossible de reconstruire les items commandés.
- **Statut :** bug identifié, à corriger côté Flutter dans le code de création de commande.

#### Bug 3 (pré-correction) — `livreurRating` vs `driverRating`
- La CF `onOrderRated` lisait `after.driverRating` mais le client écrivait `livreurRating`.
- Corrigé dans `order_completed_screen.dart`.

### Champs découverts non documentés
- `orders.deliveryStatus` — champ séparé de `status` (valeurs : `"delivered"`)
- `orders.driverEarnings` — montant gagné par le livreur
- `drivers.licensePlate`, `licenseNumber`, `vehicleBrand`, `vehicleYear`, `tokenUpdatedAt`
- `admins.role`, `admins.isAdmin`
- `promotions.type`, `targetId`, `targetName`

---

## Fichiers modifiés / créés

| Fichier | Action |
|---|---|
| `functions/index.js` | `taxi_rides` → `taxiRides` (×10) + ajout `onTaxiRideRated` |
| `lib/services/rating_service.dart` | Suppression `_updateDriverRating()` |
| `lib/services/driver_notification_service.dart` | Réduit en stub pur (0 opération Firestore) |
| `lib/services/food_notification_service.dart` | Suppression fallback + méthodes mortes |
| `lib/screens/food/food_tracking/order_completed_screen.dart` | `livreurRating` → `driverRating`, suppression writes directs sur restaurants/livreurs |
| `firestore.rules` | Règles complètes + 3 collections ajoutées + bug `status` corrigé |
| `politique_confidentialite.md` *(nouveau)* | Politique de confidentialité ClientApp |
| `accomplissementFirestore.md` *(nouveau)* | Ce fichier |
