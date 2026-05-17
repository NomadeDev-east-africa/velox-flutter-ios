# Récapitulatif des Accomplissements — Session 2

---

## 1. Affichage des catégories alimentaires en horizontal (HomeScreen Food)

**Fichier modifié :** `lib/screens/food/home_food/home_screen_food.dart`

**Problème :** Les catégories n'étaient visibles que via le bouton "See All", pas directement sur le HomeScreen.

**Solution :**
- Remplacement du widget `_FeaturedSection` par un nouveau widget `_CategoryHorizontalSection`
- Chargement des catégories via `MenuService.getAllMenus()` → regroupement par catégorie → sélection aléatoire d'un menu avec image par catégorie
- Affichage horizontal `ListView.builder` avec des cartes 100×120px
- Overlay gradient + nom de la catégorie en bas de chaque carte
- État de chargement : squelettes gris animés
- Tap sur une carte → navigation vers `DetailsScreen` du restaurant associé

---

## 2. Système de notation (Ratings) des commandes

**Fichiers modifiés :**
- `lib/screens/food/food_tracking/order_completed_screen.dart`
- `functions/index.js`

**Problème :** Aucun système de notation n'existait après la livraison d'une commande.

**Solution côté client :**
- Ajout d'un champ commentaire (TextField 3 lignes, max 300 caractères) dans la section notation restaurant
- Sauvegarde dans la collection `orders` :
  ```
  restaurantRating, driverRating, restaurantComment, ratedAt
  ```

**Solution côté serveur (Cloud Function) :**
- Nouvelle fonction `onOrderRated` déclenchée par `onDocumentUpdated("orders/{orderId}")`
- Détection : se déclenche uniquement quand `ratedAt` passe de `null` → valeur
- Propagation atomique via `db.runTransaction` :
  - `restaurants/{id}` : `ratingSum +=`, `ratingCount +=`, `rating = avg`
  - `livreurs/{id}` : `ratingSum +=`, `ratingCount +=`, `rating = avg`
- Création d'un document `restaurants/{id}/reviews/{orderId}` avec `{ orderId, rating, comment, customerName, createdAt }`
- Architecture choisie : orders = source de vérité, Cloud Function = agrégateur (évite les race conditions et manipulations côté client)

---

## 3. Changement de police globale → SFProText

**Fichier modifié :** `lib/main.dart`

**Problème :** La police `SFProText` était déclarée dans `pubspec.yaml` mais jamais appliquée. Certains textes étaient invisibles (blanc sur blanc).

**Solution :**
- Injection de `SFProText` via `.merge().apply(fontFamily: 'SFProText')` sur le `textTheme` complet
- Correction du bug `labelLarge: Colors.white` → remplacé par `labelLarge: TextStyle(color: titleColor)`
- `AppBarTheme` complété avec `foregroundColor`, `titleTextStyle`, `iconTheme` pour chaque mode (dark/light)
- `ElevatedButtonThemeData.foregroundColor: Colors.white` conservé séparément pour les boutons

---

## 4. Correction des icônes SVG dans l'AppBar (DetailsScreen)

**Fichier modifié :** `lib/screens/food/details/details_screen.dart`

**Problème :** Les icônes SVG (share, search) dans l'AppBar étaient invisibles car sans `colorFilter`.

**Solution :**
- Ajout d'un `ColorFilter.mode(Theme.of(context).appBarTheme.foregroundColor ?? Colors.black87, BlendMode.srcIn)` sur chaque `SvgPicture.asset`
- Les icônes s'adaptent automatiquement au mode sombre/clair

---

## 5. Correction du bug NotificationService — initialisation 3× par session

**Fichier modifié :** `lib/services/notification_service.dart`

**Problème :** `authStateChanges()` émet plusieurs événements pour le même utilisateur (cache → réseau → confirmation), ce qui déclenchait `initialize()` 3 fois par session. Chaque appel enregistrait un nouveau listener `FirebaseMessaging.onMessage` → chaque notification foreground s'affichait 3 fois.

**Solution :**
- Ajout de deux variables statiques (persistantes au niveau du Dart VM) :
  - `static String? _initializedForUserId` — si le même userId est déjà initialisé, les appels suivants font uniquement un refresh du token et retournent
  - `static bool _handlersSetup` — `onMessage` et `onTokenRefresh` ne sont enregistrés qu'une seule fois
- `clearToken()` (déconnexion) remet les deux flags à `null`/`false` pour permettre une future réinitialisation

**Résultat dans les logs :**
```
✅ [NotificationService] Initialisé avec succès       ← 1 seule fois
⏭️ [NotificationService] Déjà initialisé pour xxx — refresh token uniquement
```

---

## 6. Restauration automatique vers OrderTrackingScreen après crash / "Don't keep activities"

**Fichiers modifiés :** `lib/main.dart`

**Problème :** Avec l'option "Ne pas conserver les activités" activée dans les options développeur Android, basculer vers une autre app détruisait l'Activity Flutter. Au retour, l'app redémarrait sur le HomeScreen même si une commande était en cours.

**Architecture existante :** `ActiveOrderNotifier` persistait déjà l'orderId dans Hive et le restaurait au redémarrage — mais rien ne naviguait vers `OrderTrackingScreen` une fois l'ordre restauré.

**Solution :**
- Ajout de `_listenForActiveOrder()` dans `_MyAppState.initState` via `addPostFrameCallback`
- Utilisation de `ref.listenManual<ActiveOrderState>` avec `fireImmediately: true` pour capter l'état initial (Hive déjà chargé) ET les mises à jour
- Dès que `hasActiveOrder == true` et `isLoading == false`, navigation vers `/order-tracking`
- Flag `_activeOrderNavigated` : empêche la double navigation dans la même session VM (se remet à `false` automatiquement si le moteur Flutter est recréé)
- Coordination avec `_consumePendingNotification()` : si une notification pending gère déjà la navigation, `_activeOrderNavigated = true` est posé pour éviter un doublon

**Flux complet :**
```
App client crée commande → Hive persiste orderId
  ↓ Bascule vers app restaurant → Android détruit l'Activity
  ↓ Retour sur app client → moteur Flutter redémarre
  ↓ activeOrderProvider._init() lit Hive → hasActiveOrder = true
  ↓ _listenForActiveOrder → pushNamed('/order-tracking')
  ↓ OrderTrackingScreen reçoit orderId → attachOrder() → stream Firestore reprend
```

---

## Récapitulatif des fichiers touchés

| Fichier | Type de modification |
|---|---|
| `lib/screens/food/home_food/home_screen_food.dart` | Nouveau widget `_CategoryHorizontalSection` |
| `lib/screens/food/food_tracking/order_completed_screen.dart` | Champ commentaire + sauvegarde ratings |
| `lib/screens/food/details/details_screen.dart` | ColorFilter sur icônes SVG |
| `lib/main.dart` | SFProText global + restauration commande active |
| `lib/services/notification_service.dart` | Guards anti re-init + anti double-listener |
| `functions/index.js` | Cloud Function `onOrderRated` |
