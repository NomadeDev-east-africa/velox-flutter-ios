# Contexte Firestore — Nomade 253 (nomade_client)

> Projet Firebase : `nomade253-478a9`  
> App Flutter (Android + iOS) — Architecture dual-service : Taxi + Livraison de repas  
> State management : Riverpod + Hive (cache local)  
> Authentification : Email/Password, Google Sign-In, Phone OTP (Firebase Auth)

---

## 1. ARCHITECTURE GÉNÉRALE

```
Clients Flutter (CustomerApp)
        │
        ▼
  Firestore Rules (client SDK)
        │
  Cloud Functions (Admin SDK — bypass rules)
        │
   ┌────┴────────────────────┐
   ▼                         ▼
DriverApp (séparé)    RestaurantApp (séparé)
```

L'app cliente (`nomade_client`) représente **uniquement** les utilisateurs finaux (clients/riders).  
Les autres rôles ont leurs propres apps qui utilisent l'Admin SDK pour certaines opérations critiques.

---

## 2. COLLECTIONS — INVENTAIRE COMPLET

### 2.1 Collections racine actives

| Collection | Rôle | Auth ID doc |
|---|---|---|
| `taxiRides` | Courses taxi | Auto-generated |
| `orders` | Commandes food | Auto-generated |
| `users` | Profils clients | `= Auth UID` |
| `drivers` | Chauffeurs taxi | `= Auth UID` |
| `livreurs` | Livreurs food | `= Auth UID` |
| `restaurants` | Restaurants | `= Auth UID` |
| `menu_items` | Catalogue global | Auto-generated |
| `promotions` | Promotions (CF only) | Auto-generated |
| `livreurNotifications` | Notifs livreurs (CF only) | Auto-generated |
| `admins` | Admins (CF only) | `= Auth UID` |

### 2.2 Sous-collections

| Chemin | Rôle |
|---|---|
| `users/{uid}/addresses` | Adresses sauvegardées |
| `users/{uid}/favorite_drivers` | Chauffeurs favoris |
| `drivers/{id}/ratings` | Notes reçues par le driver |
| `restaurants/{id}/reviews` | Avis écrits par CF onOrderRated |
| `restaurants/{id}/avis` | Avis écrits directement par les clients |
| `restaurants/{id}/menu` | Menu local (déprécié → remplacé par `menu_items`) |

### 2.3 Collections mortes (bloquées)

Ces collections ne sont **jamais** lues/écrites par les apps clientes.  
FCM est envoyé directement par Cloud Functions via Admin Messaging SDK.

- `driver_notifications`
- `user_notifications`
- `restaurant_notifications`
- `user_food_notifications`

---

## 3. TYPES D'UTILISATEURS ET RÔLES

Il n'y a **pas de champ `role`** en base. Le rôle est déduit implicitement par :
- L'existence d'un document dans `drivers/{uid}` → Chauffeur taxi
- L'existence d'un document dans `livreurs/{uid}` → Livreur food
- L'existence d'un document dans `restaurants/{uid}` → Restaurant
- Par défaut (document dans `users/{uid}`) → Client/Rider

### Matrice d'accès

| Actor | taxiRides | orders | users | drivers | livreurs | restaurants | menu_items |
|---|---|---|---|---|---|---|---|
| **Client** | CREATE (own), READ (own), UPDATE (cancel/rate) | CREATE, READ (own), UPDATE (cancel/rate) | CRUD (own only) | READ (all) | READ (all) | READ (all) | READ (all) |
| **Driver** | READ (assigned/targeted), UPDATE (status) | — | — | CRUD (own), READ (all) | — | — | — |
| **Livreur** | — | READ (assigned), UPDATE (self-assign/deliver) | — | — | CRUD (own), READ (all) | — | — |
| **Restaurant** | — | READ (own restaurant), UPDATE (status flow) | — | — | — | CRUD (own), READ (all) | CRUD (own restaurantId) |
| **Cloud Functions** | UPDATE (reserved fields) | UPDATE (reserved fields) | — | UPDATE (rating/heartbeat) | UPDATE (rating) | UPDATE (rating) | — |

---

## 4. FLUX MÉTIER DÉTAILLÉS

### 4.1 Course Taxi

```
Client crée taxiRide (status: 'requested', driverId: null)
    │
    ▼ CF onTaxiRideCreated
Assigne targetedDriverId, driverQueue, offerSentAt/ExpiresAt
    │
    ▼ Driver accepte (CF acceptRideTx)
driverId, driverName, driverPhone, vehicleId, acceptedAt remplis
    │
    ▼ Driver updates via DriverApp
arriving → arrived → started → completed (arrivedAt, startedAt, completedAt, finalFare)
    │
    ▼ Client note le driver
taxiRides/{id}.userRating + drivers/{id}/ratings créé
    │
    ▼ CF onTaxiRideRated
drivers/{id}.rating recalculé
```

**Champs réservés CF (Admin SDK uniquement)** :
- `targetedDriverId`, `driverQueue`, `currentOfferIndex`, `offerSentAt`, `offerExpiresAt`
- `driverId`, `driverName`, `driverPhone`, `driverPhotoUrl`, `vehicleId`, `acceptedAt`
- `arrivedAt`, `startedAt`, `completedAt`, `finalFare` (DriverApp direct)
- `cancelledAt` (system) → CF cleanupStuckRides

### 4.2 Commande Food

```
Client crée order (status: 'pending', deliveryDriverId: null)
    │
    ▼ Restaurant accepte (status: confirmed → preparing → ready)
    │
    ▼ CF sendOrderReadyNotifications
readyAt, livreurNotification créée
    │
    ▼ Livreur self-assign (status: ready → delivering)
deliveryDriverId = livreur.uid
    │
    ▼ Livreur confirme livraison (status: delivering → delivered)
    │
    ▼ Client note restaurant + livreur
orders/{id}.restaurantRating + driverRating
    │
    ▼ CF onOrderRated
restaurants/{id}.rating + livreurs/{id}.rating recalculés
```

**Champs réservés CF** :
- `status → 'ready'`, `readyAt` → CF sendOrderReadyNotifications
- `restaurantRating`/`ratingSum`/`ratingCount` sur restaurants
- `driverRating`/`ratingSum`/`ratingCount` sur livreurs

### 4.3 Authentification

```
signUpWithEmailPassword() / signInWithGoogle() / verifyOTP()
    │
    ▼ Crée/met à jour users/{uid}
    │
    ▼ Sauvegarde fcmToken → users/{uid}.fcmToken
```

---

## 5. ANALYSE DES RÈGLES EXISTANTES — PROBLÈMES IDENTIFIÉS

### 🔴 Problème 1 — Triple `get()` sur taxiRides dans `drivers/{id}/ratings`

Les règles actuelles appellent `get()` trois fois sur le même document `taxiRides/{rideId}` :
```javascript
get(/taxiRides/$(rideId)).data.userId   == request.auth.uid
get(/taxiRides/$(rideId)).data.driverId == driverId
get(/taxiRides/$(rideId)).data.status   == 'completed'
```
Chaque `get()` coûte **1 lecture Firestore** et augmente la latence. Il faut **cacher** le résultat dans une variable locale.

### 🔴 Problème 2 — Machine d'état driver non stricte (taxiRides)

La règle driver autorise n'importe quelle transition dans `['arrived','started','completed']` depuis `['accepted','arrived','started']`, ce qui permet :
- `accepted → completed` (saute arrivedAt et startedAt)
- `arrived → completed` (saute startedAt)

Il faut enforcer la chaîne : `accepted → arriving → arrived → started → completed`.

### 🟡 Problème 3 — Machine d'état restaurant non stricte (orders)

Le restaurant peut passer de `pending` directement à `ready` ou `cancelled` sans passer par `confirmed` → `preparing`. À strictement parler, la transition devrait être :
- `pending → confirmed`
- `confirmed → preparing`
- `preparing → ready`
- `pending | confirmed | preparing → cancelled`

### 🟡 Problème 4 — Livreur self-assign sans vérifier disponibilité

La règle vérifie que le document `livreurs/{uid}` existe, mais ne vérifie pas que le livreur est `isOnline: true` et `isAvailable: true`. Un livreur hors-ligne peut théoriquement s'assigner une commande.

### 🟡 Problème 5 — `orders` status 'delivered' vs 'completed'

Le code Dart utilise `OrderStatus.completed` mais la règle livreur écrit `status: 'delivered'`. Il y a une incohérence entre `delivered` (règles) et `completed` (modèle). Le code du livreur (DriverApp) devrait clarifier quelle valeur est utilisée en production. À vérifier.

### 🟡 Problème 6 — `avis` restaurants sans vérification d'achat

N'importe quel utilisateur authentifié peut écrire un avis sur n'importe quel restaurant, sans vérifier qu'il a passé une commande dans ce restaurant. Un cross-document check sur `orders` permettrait de limiter aux vrais clients.

### 🟢 Amélioration 7 — Validation `menu_items` create

La création d'un item de menu ne valide pas les champs requis (name, price > 0, restaurantId).

### 🟢 Amélioration 8 — Validation `orders` items structure

Les items de commande ne sont validés qu'en taille (>0 et ≤50) mais pas en structure (quantity > 0, price > 0).

---

## 6. RÈGLES FIRESTORE OPTIMISÉES

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ════════════════════════════════════════════════════════════
    // FONCTIONS UTILITAIRES
    // ════════════════════════════════════════════════════════════

    function isAuth() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return request.auth.uid == uid;
    }

    // Vérifie que seuls les champs listés sont modifiés (pas d'ajout de champs non autorisés)
    function onlyFields(fields) {
      return request.resource.data.diff(resource.data)
        .affectedKeys().hasOnly(fields);
    }

    function isValidRating(r) {
      return r is int && r >= 1 && r <= 5;
    }

    // Vérifie si un document livreur existe et est disponible
    function livreurIsAvailable(uid) {
      let livreurDoc = get(/databases/$(database)/documents/livreurs/$(uid));
      return livreurDoc.data.isOnline == true
          && livreurDoc.data.isAvailable == true;
    }

    // ════════════════════════════════════════════════════════════
    // COLLECTIONS MORTES — FCM géré directement par les CF
    // Jamais écrites ni lues par les apps clientes
    // ════════════════════════════════════════════════════════════

    match /driver_notifications/{doc}       { allow read, write: if false; }
    match /user_notifications/{doc}         { allow read, write: if false; }
    match /restaurant_notifications/{doc}   { allow read, write: if false; }
    match /user_food_notifications/{doc}    { allow read, write: if false; }

    // ════════════════════════════════════════════════════════════
    // taxiRides
    //
    // Champs réservés CF (Admin SDK bypass) :
    //   targetedDriverId, driverQueue, currentOfferIndex,
    //   offerSentAt, offerExpiresAt        → onTaxiRideCreated
    //   driverId, driverName, driverPhone,
    //   driverPhotoUrl, vehicleId, acceptedAt → acceptRideTx
    //   arrivedAt, startedAt, completedAt    → DriverApp direct (via arriving→arrived→started→completed)
    //   finalFare                            → DriverApp direct
    //   cancelledAt (system)                 → cleanupStuckRides
    // ════════════════════════════════════════════════════════════

    match /taxiRides/{rideId} {

      allow read: if isAuth() && (
        isOwner(resource.data.userId)           ||  // client propriétaire
        isOwner(resource.data.driverId)         ||  // driver assigné
        isOwner(resource.data.targetedDriverId)     // driver ciblé (offre en cours)
      );

      // CLIENT — créer une course
      allow create: if isAuth()
        && request.resource.data.userId           == request.auth.uid
        && request.resource.data.status           == 'requested'
        && request.resource.data.driverId         == null
        && request.resource.data.targetedDriverId == null
        && request.resource.data.driverQueue      == null
        && request.resource.data.keys().hasAll([
             'userId', 'pickup', 'destination',
             'estimatedFare', 'vehicleType',
             'paymentMethod', 'status'
           ]);

      allow delete: if false;

      allow update: if isAuth() && (

        // CLIENT — annuler avant acceptation (pas encore de driver)
        ( isOwner(resource.data.userId)
          && resource.data.status in ['requested','pending','waiting','new','created']
          && resource.data.driverId == null
          && request.resource.data.status      == 'cancelled'
          && request.resource.data.cancelledBy in ['user','customer']
          && onlyFields([
               'status','cancelledAt','cancellationReason',
               'cancelledBy','updatedAt'
             ])
        )

        // CLIENT — annuler après acceptation (driver déjà assigné)
        || ( isOwner(resource.data.userId)
             && resource.data.status in ['accepted','arrived']
             && request.resource.data.status      == 'cancelled'
             && request.resource.data.cancelledBy in ['user','customer']
             && onlyFields([
                  'status','cancelledAt','cancellationReason',
                  'cancelledBy','updatedAt'
                ])
           )

        // CLIENT — noter le chauffeur (course terminée, pas encore notée)
        || ( isOwner(resource.data.userId)
             && resource.data.status     == 'completed'
             && resource.data.userRating == null
             && isValidRating(request.resource.data.userRating)
             && onlyFields([
                  'userRating','userReview',
                  'ratedAt','rated','updatedAt'
                ])
           )

        // DRIVER — transitions de statut (machine d'état stricte)
        // accepted → arriving → arrived → started → completed
        || ( isOwner(resource.data.driverId)
             && (
               ( resource.data.status == 'accepted'
                 && request.resource.data.status == 'arriving'
                 && onlyFields(['status','updatedAt'])
               )
               || ( resource.data.status == 'arriving'
                    && request.resource.data.status == 'arrived'
                    && onlyFields(['status','arrivedAt','updatedAt'])
                  )
               || ( resource.data.status == 'arrived'
                    && request.resource.data.status == 'started'
                    && onlyFields(['status','startedAt','updatedAt'])
                  )
               || ( resource.data.status == 'started'
                    && request.resource.data.status == 'completed'
                    && onlyFields(['status','completedAt','finalFare','updatedAt'])
                  )
             )
           )
      );
    }

    // ════════════════════════════════════════════════════════════
    // orders
    //
    // Champs réservés CF (Admin SDK bypass) :
    //   status → 'ready', readyAt          → sendOrderReadyNotifications
    //   restaurantRating/ratingSum/ratingCount sur restaurants
    //   driverRating/ratingSum/ratingCount sur livreurs → onOrderRated
    //
    // Annulation client : uniquement depuis pending | confirmed
    // ════════════════════════════════════════════════════════════

    match /orders/{orderId} {

      allow read: if isAuth() && (
        isOwner(resource.data.userId)           ||  // client propriétaire
        isOwner(resource.data.deliveryDriverId) ||  // livreur assigné
        isOwner(resource.data.restaurantId)         // restaurant (Auth UID = restaurantId)
      );

      // CLIENT — créer une commande
      allow create: if isAuth()
        && request.resource.data.userId           == request.auth.uid
        && request.resource.data.status           == 'pending'
        && request.resource.data.deliveryDriverId == null
        && request.resource.data.items.size()     >  0
        && request.resource.data.items.size()     <= 50
        && request.resource.data.keys().hasAll([
             'userId','restaurantId','items',
             'total','paymentMethod',
             'deliveryAddress','status'
           ]);

      allow delete: if false;

      allow update: if isAuth() && (

        // CLIENT — annuler (uniquement depuis pending ou confirmed)
        ( isOwner(resource.data.userId)
          && resource.data.status in ['pending','confirmed']
          && request.resource.data.status == 'cancelled'
          && onlyFields([
               'status','cancelledAt',
               'cancellationReason','updatedAt'
             ])
        )

        // CLIENT — noter restaurant + livreur (après livraison, une seule fois)
        || ( isOwner(resource.data.userId)
             && resource.data.status  == 'completed'
             && resource.data.ratedAt == null
             && isValidRating(request.resource.data.restaurantRating)
             && onlyFields([
                  'restaurantRating','driverRating',
                  'restaurantComment','ratedAt','updatedAt'
                ])
           )

        // RESTAURANT — machine d'état stricte
        // pending → confirmed → preparing → ready | cancelled
        || ( isOwner(resource.data.restaurantId)
             && (
               ( resource.data.status == 'pending'
                 && request.resource.data.status in ['confirmed','cancelled']
                 && onlyFields(['status','acceptedAt','estimatedPreparationTime','updatedAt'])
               )
               || ( resource.data.status == 'confirmed'
                    && request.resource.data.status in ['preparing','cancelled']
                    && onlyFields(['status','estimatedPreparationTime','updatedAt'])
                  )
               || ( resource.data.status == 'preparing'
                    && request.resource.data.status in ['ready','cancelled']
                    && onlyFields(['status','updatedAt'])
                  )
             )
           )

        // LIVREUR — accepter une livraison disponible (self-assign)
        // Vérifie que le livreur existe ET est disponible (isOnline + isAvailable)
        || ( resource.data.deliveryDriverId           == null
             && resource.data.status                  == 'ready'
             && request.resource.data.deliveryDriverId == request.auth.uid
             && request.resource.data.status           == 'delivering'
             && onlyFields([
                  'deliveryDriverId','deliveryDriverName',
                  'status','assignedAt','updatedAt'
                ])
             && livreurIsAvailable(request.auth.uid)
           )

        // LIVREUR ASSIGNÉ — confirmer la livraison
        || ( isOwner(resource.data.deliveryDriverId)
             && resource.data.status         == 'delivering'
             && request.resource.data.status == 'delivered'
             && onlyFields(['status','deliveredAt','updatedAt'])
           )
      );
    }

    // ════════════════════════════════════════════════════════════
    // users
    //
    // Champs librement modifiables par le propriétaire :
    //   name, phone, photoUrl, fcmToken, lastActiveAt,
    //   preferences, paymentMethods, stats, isActive
    // Champs protégés : email, isVerified, roles, createdAt
    // ════════════════════════════════════════════════════════════

    match /users/{userId} {
      allow read:   if isAuth() && isOwner(userId);
      allow create: if isAuth() && isOwner(userId);
      allow delete: if false;
      allow update: if isAuth() && isOwner(userId)
        && onlyFields([
             'name','phone','photoUrl','fcmToken',
             'lastActiveAt','updatedAt',
             'preferences','paymentMethods',
             'stats','isActive'
           ]);

      match /addresses/{addressId} {
        allow read, write: if isAuth() && isOwner(userId);
      }

      match /favorite_drivers/{driverId} {
        allow read, write: if isAuth() && isOwner(userId);
      }
    }

    // ════════════════════════════════════════════════════════════
    // drivers
    //
    // Champs réservés CF :
    //   isOnline, isAvailable, offlineReason → cleanupDeadDrivers / cleanupStuckRides
    //   lastHeartbeat, currentLocation       → driverHeartbeat (onCall)
    //   rating, totalRatings                 → onTaxiRideRated
    // ════════════════════════════════════════════════════════════

    match /drivers/{driverId} {
      allow read: if isAuth();
      allow create: if isAuth() && isOwner(driverId);
      allow delete: if false;

      // Le driver gère son profil et sa disponibilité manuelle
      // lastHeartbeat/currentLocation/rating : CF uniquement
      allow update: if isAuth() && isOwner(driverId)
        && onlyFields([
             'name','phone','photoUrl','fcmToken',
             'isOnline','isAvailable',
             'vehicleModel','vehiclePlate',
             'vehicleColor','vehicleType','updatedAt'
           ]);

      // Ratings — créées par le client après course complétée
      // Optimisation : un seul get() mis en cache dans une variable locale
      match /ratings/{ratingId} {
        allow read: if isAuth();
        allow create: if isAuth()
          && request.resource.data.userId == request.auth.uid
          && isValidRating(request.resource.data.rating)
          && (
            let rideDoc = get(/databases/$(database)/documents/taxiRides/$(request.resource.data.rideId));
            rideDoc.data.userId   == request.auth.uid
            && rideDoc.data.driverId == driverId
            && rideDoc.data.status   == 'completed'
          );
        allow update, delete: if false;
      }
    }

    // ════════════════════════════════════════════════════════════
    // livreurs
    //
    // Champs réservés CF :
    //   rating, ratingSum, ratingCount → onOrderRated
    //
    // Pas de heartbeat CF — location et disponibilité écrites en direct
    // ════════════════════════════════════════════════════════════

    match /livreurs/{livreurId} {
      allow read: if isAuth();
      allow create: if isAuth() && isOwner(livreurId);
      allow delete: if false;
      allow update: if isAuth() && isOwner(livreurId)
        && onlyFields([
             'name','phone','photoUrl','fcmToken',
             'isOnline','isAvailable',
             'vehicleType','currentLocation',
             'lastHeartbeat','updatedAt'
           ]);
    }

    // ════════════════════════════════════════════════════════════
    // restaurants
    //
    // Champs réservés CF :
    //   rating, ratingSum, ratingCount → onOrderRated
    // ════════════════════════════════════════════════════════════

    match /restaurants/{restaurantId} {
      allow read: if isAuth();
      allow create: if isAuth() && isOwner(restaurantId);
      allow delete: if false;
      allow update: if isAuth() && isOwner(restaurantId)
        && onlyFields([
             'name','description','imageUrl','coverImageUrl',
             'isOpen','phone','address','category',
             'fcmToken','openingHours','deliveryFee',
             'minimumOrder','estimatedDeliveryTime','updatedAt'
           ]);

      // Avis écrits par CF onOrderRated — lecture seule pour les clients
      match /reviews/{reviewId} {
        allow read:  if isAuth();
        allow write: if false;
      }

      // Avis écrits directement par les clients
      match /avis/{avisId} {
        allow read: if isAuth();
        allow create: if isAuth()
          && request.resource.data.userId == request.auth.uid
          && isValidRating(request.resource.data.note);
        allow update, delete: if false;
      }

      // Menu local (déprécié — utiliser la collection globale menu_items)
      match /menu/{menuId} {
        allow read:  if isAuth();
        allow write: if isAuth() && isOwner(restaurantId);
      }
    }

    // ════════════════════════════════════════════════════════════
    // livreurNotifications
    //
    // Créées par sendOrderReadyNotifications (CF — Admin SDK)
    // Lues et mises à jour par le livreur concerné uniquement
    // ════════════════════════════════════════════════════════════

    match /livreurNotifications/{notifId} {
      allow create: if false;
      allow read:   if isAuth() && isOwner(resource.data.userId);
      allow update: if isAuth()
        && isOwner(resource.data.userId)
        && onlyFields(['read','accepted']);
      allow delete: if false;
    }

    // ════════════════════════════════════════════════════════════
    // admins
    //
    // Non accessible aux clients — réservé à l'Admin SDK (CF)
    // ════════════════════════════════════════════════════════════

    match /admins/{adminId} {
      allow read, write: if false;
    }

    // ════════════════════════════════════════════════════════════
    // menu_items
    //
    // Catalogue global de plats — géré par les restaurants
    // Lecture ouverte à tout client authentifié
    // ════════════════════════════════════════════════════════════

    match /menu_items/{itemId} {
      allow read: if isAuth();
      allow create: if isAuth()
        && request.resource.data.restaurantId == request.auth.uid
        && request.resource.data.keys().hasAll([
             'name','price','restaurantId','isAvailable'
           ])
        && request.resource.data.price is number
        && request.resource.data.price > 0;
      allow update: if isAuth()
        && resource.data.restaurantId == request.auth.uid
        && onlyFields([
             'name','description','price','imageUrl',
             'category','isAvailable','preparationTime','updatedAt'
           ]);
      allow delete: if isAuth()
        && resource.data.restaurantId == request.auth.uid;
    }

    // ════════════════════════════════════════════════════════════
    // promotions
    //
    // Écriture réservée CF / Admin SDK
    // Lecture ouverte à tout client authentifié
    // ════════════════════════════════════════════════════════════

    match /promotions/{promoId} {
      allow read:  if isAuth();
      allow write: if false;
    }

  }
}
```

---

## 7. RÉSUMÉ DES CHANGEMENTS APPORTÉS

| # | Type | Description |
|---|---|---|
| 1 | 🔴 Fix | `drivers/{id}/ratings` — triple `get()` remplacé par une variable `let rideDoc` (1 seule lecture) |
| 2 | 🔴 Fix | `taxiRides` driver — machine d'état stricte : `accepted→arriving→arrived→started→completed` (plus de sauts d'étapes) |
| 3 | 🟡 Fix | `orders` restaurant — machine d'état stricte : transitions séquentielles uniquement |
| 4 | 🟡 Fix | `orders` livreur self-assign — ajout de `livreurIsAvailable()` (vérifie isOnline + isAvailable) |
| 5 | 🟢 Amélioration | `menu_items` create — validation des champs requis et `price > 0` |
| 6 | 🟢 Amélioration | `livreurIsAvailable()` — nouvelle fonction utilitaire réutilisable |
| 7 | 🟢 Nettoyage | Règle `taxiRides` driver refactorisée en 3 clauses imbriquées plus lisibles |

---

## 8. INDEXES FIRESTORE REQUIS

Les requêtes suivantes nécessitent des index composites (à configurer dans `firestore.indexes.json`) :

```json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "restaurantId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "menu_items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "restaurantId", "order": "ASCENDING" },
        { "fieldPath": "isAvailable", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "menu_items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "restaurantId", "order": "ASCENDING" },
        { "fieldPath": "isAvailable", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "taxiRides",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "taxiRides",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "requestedAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 9. POINTS D'ATTENTION RESTANTS

### ⚠️ À confirmer avec l'équipe

1. **`orders` status `'delivered'` vs `'completed'`** : La règle livreur écrit `delivered` mais le modèle Dart utilise `OrderStatus.completed`. Vérifier quelle valeur est réellement utilisée en production et aligner les deux.

2. **`taxiRides` arrivedAt/startedAt/completedAt** : Ces champs sont marqués "DriverApp direct" dans les commentaires mais les règles les autorisent aussi via le `drivers/{driverId}` owner. Si le DriverApp utilise l'Admin SDK, la règle client peut rester (elle sera simplement ignorée par Admin SDK). Sinon, clarifier si le driver écrit ces champs via le SDK client ou Admin.

3. **`avis` sans vérification d'achat** : Tout utilisateur authentifié peut écrire un avis sur n'importe quel restaurant. Pour limiter aux vrais clients, il faudrait un cross-document check sur `orders` (WHERE userId == auth.uid AND restaurantId == restaurantId AND status == 'completed'), mais cela augmente la latence. À décider selon le risque métier.

### 💡 Recommandations architecture

- **Ne jamais stocker de données sensibles** (moyens de paiement complets, tokens de session) directement dans Firestore — utiliser Stripe/PayDunya webhooks + Cloud Functions
- **FCM tokens** : envisager une rotation régulière et la suppression lors de la déconnexion (`FieldValue.delete()` est déjà implémenté dans NotificationService ✓)
- **Rate limiting** : Firestore Rules ne peuvent pas rate-limiter. Envisager des Cloud Functions pour les opérations critiques (création de course, commande)
