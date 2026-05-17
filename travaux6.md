# Travaux Session 6 — Optimisations performances & corrections

## Résultats obtenus

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Davey! durée | 1318ms | 721ms | **−597ms (−46%)** |
| Pire pic frames skipped | 192 frames | 155 frames | −37 frames |
| Frames skipped total | 250+ | ~196 | −54+ |
| Erreurs App Check | Nombreuses (403) | **0** | ✅ |
| Login premier coup | ❌ (popup erreur) | ✅ | ✅ |

---

## Corrections appliquées

### 1. Warnings & infos du linter (7 fichiers)

| Fichier | Correction |
|---------|-----------|
| `lib/providers/active_order_notifier.dart` | Import `retry_helper.dart` inutilisé supprimé |
| `lib/screens/food/food_tracking/order_tracking_screen.dart` | Variable locale `isPending` inutilisée supprimée |
| `lib/screens/food/home_food/home_screen_food.dart` | Import `flutter_svg` + constante `_onPrimary` supprimés ; `__`/`___` → `_` dans tous les callbacks |
| `lib/screens/onboarding/onboarding_scrreen.dart` | Import `dot_indicators` + constantes `_surface` et `_onSurface` supprimés |
| `lib/providers/order_stats_provider.dart` | Paramètre `sum` → `acc` (conflit avec type name) |
| `lib/screens/food/food_tracking/delivery_address_picker_screen.dart` | Accolades ajoutées aux 3 blocs `if (mounted)` |
| `lib/screens/homeScreen/home_screen_app.dart` | `__, ___` → `_, _` dans `errorBuilder` |

---

### 2. Performance démarrage — GoogleFonts `static final`

**Fichier :** `lib/main.dart`

**Problème :** 16 appels `GoogleFonts.poppins()` / `GoogleFonts.inter()` dans `initState()` de `_MyAppState` → recalculés à chaque mount sur le main thread pendant le premier frame.

**Fix :** Champs `late TextTheme` → `static final TextTheme` déclarés au niveau de la classe. Calculés une seule fois au premier accès, puis mis en cache pour toute la session.

```dart
// AVANT — dans initState(), recalculé à chaque mount
_lightTextTheme = GoogleFonts.poppinsTextTheme(TextTheme(...)); // 16 appels

// APRÈS — static final, calculé une seule fois
static final TextTheme _lightTextTheme = GoogleFonts.poppinsTextTheme(TextTheme(...));
static final TextTheme _darkTextTheme  = GoogleFonts.poppinsTextTheme(const TextTheme(...));
```

---

### 3. Firebase App Check — désactivé en debug

**Fichier :** `lib/main.dart`

**Problème :** App Check en debug causait des erreurs 403 / `DEVELOPER_ERROR` et bloquait l'initialisation (~100 frames).

**Fix :** App Check uniquement activé en production (`!kDebugMode`).

```dart
if (!kDebugMode) {
  unawaited(FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidPlayIntegrityProvider(),
    providerApple: AppleDeviceCheckProvider(),
  ).catchError((e) => debugPrint('⚠️ App Check: $e')));
}
```

---

### 4. Firebase.initializeApp() — revenu en `await`

**Fichier :** `lib/main.dart`

**Problème :** Tentative de rendre Firebase non-bloquant → race condition : `FirebaseAuth.authStateChanges()` et `userNotifierProvider` accédaient à Firebase avant que l'init soit terminée → 192 frames (pire qu'avant).

**Fix :** Revenir à `await Firebase.initializeApp()` avant `runApp()`. Le vrai freeze venait de l'App Check (fix 3), pas de Firebase.init lui-même.

---

### 5. Double appel `requestPermission()` — garde concurrence

**Fichier :** `lib/services/notification_service.dart`

**Problème :** `authStateChanges()` pouvait firer plusieurs fois lors de la restauration de session → `NotificationService.initialize()` appelé en double → `requestPermission()` lancé 2 fois simultanément → popup rouge `"A request for permissions is already running"` au login.

**Fix :** Flag statique `_permissionInProgress` avec bloc `try/finally`.

```dart
static bool _permissionInProgress = false;

if (_permissionInProgress) {
  debugPrint('⏭️ requestPermission déjà en cours — annulé');
  return;
}
_permissionInProgress = true;
try {
  settings = await _messaging.requestPermission(...);
} finally {
  _permissionInProgress = false;
}
```

---

### 6. Performance tracking — Timer isolé (session précédente)

**Fichier :** `lib/screens/taxi/tracking_screen.dart`

**Problème :** `Timer.periodic` dans `_TrackingScreenState` appelait `setState()` toutes les secondes → reconstruisait la carte entière → 125 frames skipped.

**Fix :** Chrono extrait dans un widget `_ElapsedTimer` avec son propre `Timer` interne. Seul le texte du chrono se rafraîchit.

---

### 7. Performance home food (session précédente)

**Fichier :** `lib/screens/food/home_food/home_screen_food.dart`

| Problème | Fix |
|----------|-----|
| `Column.map()` chargeait tous les restaurants | `ListView.builder` avec virtualisation |
| Requêtes Firestore séquentielles (5 awaits) | `Future.wait` → requêtes parallèles |
| `.elementAt(index)` O(n) sur chaque item | `_categoryKeys[index]` accès direct O(1) |

---

## Erreurs résiduelles (non bloquantes)

```
E/GoogleApiManager: Failed to get service from broker.
java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
```

- Apparaissent **après** login, en arrière-plan
- Viennent de Google Play Services, pas du code Flutter
- L'utilisateur ne les voit pas
- Aucune action possible côté app

---

## État final

| Catégorie | Statut |
|-----------|--------|
| Erreurs App Check visibles | ✅ 0 |
| Login premier coup | ✅ |
| Frames skipped au démarrage | 🟡 ~196 (réseau Firestore, incompressible) |
| Scroll home food | ✅ Fluide |
| Chrono tracking | ✅ Isolé |
| Warnings linter | ✅ 0 |
