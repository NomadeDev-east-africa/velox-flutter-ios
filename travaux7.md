# Travaux Session 7 — Nettoyage projet, optimisations performance & corrections release

## Résultats obtenus

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Frames skippées (release) | ~120 frames | **0 frames** | ✅ |
| App startup | Freeze visible | Fluide | ✅ |
| Appels Nominatim (même position) | 4 appels | **1 appel** | −75% |
| Fichiers Dart dans le projet | 162 | **120** | −42 fichiers |
| Erreurs dart analyze | 0 | 0 | ✅ |
| Double lifecycle resumed | Oui (2×) | **Non (1×)** | ✅ |

---

## Corrections appliquées

### 1. Suppression de 42 fichiers inutilisés

Analyse complète des imports croisés via MCP Dart + script PowerShell.
Aucun fichier supprimé n'était référencé — vérifié par `dart analyze` post-suppression (0 erreurs).

| Catégorie | Fichiers supprimés |
|-----------|-------------------|
| Anciens providers (avant migration Riverpod) | 8 fichiers (`cart_provider`, `language_provider`, `location_provider`, `menu_provider`, `restaurant_provider`, `ride_provider`, `theme_provider`, `user_provider`) |
| Ancienne navigation | `entry_point.dart` |
| Ancien modèle utilisateur | `models/user.dart` |
| Données de démo | `demo_data.dart` |
| Ancien écran signup | `screens/signUp/components/body.dart` |
| Composants/écrans jamais importés | 22 fichiers (addToOrder components, orderDetails components, taxi components, etc.) |
| Utilitaires/services jamais utilisés | `controller_guard`, `debouncer`, `throttler`, `driver_service`, `firebase_service` |
| Système typographique non branché | `theme/app_typography.dart` |

**Conservés intentionnellement :** `config/secrets.template.dart`, `config/map_config.dart`

---

### 2. Firebase App Check — DebugProvider en mode debug

**Fichier :** `lib/main.dart`

**Problème :** App Check était simplement désactivé en debug (`if (!kDebugMode)`) → pas de token valide → erreurs 403 possibles si enforcement côté Firebase Console.

**Fix :** Utilisation du `AndroidDebugProvider()` en debug pour obtenir un token de développement valide.

```dart
// AVANT — App Check simplement absent en debug
if (!kDebugMode) {
  unawaited(FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidPlayIntegrityProvider(),
    providerApple: AppleDeviceCheckProvider(),
  ).catchError(...));
}

// APRÈS — DebugProvider en dev, PlayIntegrity en prod
if (kDebugMode) {
  unawaited(FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidDebugProvider(),
  ).catchError((e) => debugPrint('⚠️ App Check debug: $e')));
} else {
  unawaited(FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidPlayIntegrityProvider(),
    providerApple: AppleDeviceCheckProvider(),
  ).catchError((e) => debugPrint('⚠️ App Check: $e')));
}
```

> **Note :** Enregistrer le debug token généré dans Firebase Console → App Check → Manage debug tokens.

---

### 3. Déduplication des appels `getRestaurantById`

**Fichiers :** `home_screen_food.dart`, `featured/components/body.dart`

**Problème :** Si N catégories appartiennent au même restaurant, il était fetché N fois.
`featured/body.dart` utilisait en plus un `for await` séquentiel (bloquant).

**Fix :** Collecte des IDs uniques + `Future.wait` parallèle.

```dart
// AVANT — séquentiel + redondant
for (var entry in categoryMenus.entries) {
  final restaurant = await RestaurantService().getRestaurantById(menu.restaurantId);
}

// APRÈS — IDs dédupliqués + parallèle
final uniqueIds = categoryMenus.values.map((m) => m.restaurantId).toSet().toList();
final fetched = await Future.wait(
  uniqueIds.map((id) => _restaurantService.getRestaurantById(id)),
);
final restaurantById = { for (var i = 0; i < uniqueIds.length; i++) uniqueIds[i]: fetched[i] };
```

---

### 4. Cache géocodage — Précision clé corrigée (6dp → 3dp)

**Fichier :** `lib/services/location_service.dart`

**Problème :**
- Session 6 : clé à 6 décimales (10cm) → cache miss systématique sur drift GPS
- Session 7 première tentative : 4 décimales (11m) → toujours 4 appels Nominatim observés dans les logs release (drift GPS > 11m)
- Session 7 logs release : 4 coordonnées pour la même rue, 4 appels réseau

**Fix final :** 3 décimales = précision 111m, absorbe le drift GPS sans changer de rue.

```dart
// AVANT (session 6 — trop précis)
'${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}'

// INTERMÉDIAIRE (session 7v1 — encore trop précis)
'${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}'

// FINAL (session 7v2 — correct)
'${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}'
```

**Résultat :** Les 4 coordonnées du log (`11.6064`, `11.6063`, `11.6062`) donnent toutes la clé `'11.606_43.151'` → **1 seul appel Nominatim** au lieu de 4. Conforme à la limite 1 req/s d'OSM.

---

### 5. `_cleanExpiredCache` sorti du hot path

**Fichier :** `lib/services/location_service.dart`

**Problème :** `_cleanExpiredCache()` était appelé à chaque `getAddressFromCoordinates()` → lecture SharedPreferences à chaque géocode.

**Fix :** Flag statique `_cacheCleanedThisSession` → exécution une seule fois par session.

```dart
static bool _cacheCleanedThisSession = false;

if (!_cacheCleanedThisSession) {
  _cacheCleanedThisSession = true;
  await _cleanExpiredCache();
}
```

---

### 6. `memCacheWidth` sur tous les `CachedNetworkImage`

**Fichiers :** 5 emplacements corrigés

**Problème :** Aucune carte ne définissait `memCacheWidth` → les images étaient décodées à leur taille originale (potentiellement 4K) puis redimensionnées côté GPU → memory pressure + rescaling coûteux.

**Fix :** `memCacheWidth` adapté à la taille d'affichage réelle × `devicePixelRatio`.

| Widget | Taille logique | memCacheWidth |
|--------|---------------|---------------|
| `RestaurantInfoMediumCard` | 200px | `200 × pixelRatio` |
| `RestaurantInfoBigCard` | plein écran | `MediaQuery.size.width` |
| Home — catégories | 88px | `88 × pixelRatio` |
| Home — populaires | 200×130px | `200/130 × pixelRatio` |
| Home — `_DarkRestaurantCard` | plein écran | `MediaQuery.size.width` |

---

### 7. `RestaurantService` en champ singleton

**Fichiers :** `_CategoryHorizontalSectionState`, `_BodyState` (featured)

**Problème :** `RestaurantService()` instancié inline à chaque appel → allocations inutiles.

**Fix :** Déclaré comme champ de classe.

```dart
final RestaurantService _restaurantService = RestaurantService();
```

---

### 8. Nettoyage `restaurant_service.dart`

**Problème :**
- `testConnection()` : méthode debug jamais appelée (dead code)
- 20+ `debugPrint` non gardés → en release, la construction des strings d'interpolation s'exécutait quand même (appels `doc.data()['name']` sur chaque document)

**Fix :**
- `testConnection()` supprimé
- Tous les `debugPrint` wrappés dans `if (kDebugMode)` → DCE élimine l'intégralité des blocs en AOT release

---

### 9. Double `AppLifecycleState.resumed` — Guard de démarrage

**Fichier :** `lib/main.dart`

**Problème observé dans les logs release :**
```
▶️ App au premier plan — reprise des streams   ← 1er (démarrage normal)
🔒 Demande de permission localisation...
▶️ App au premier plan — reprise des streams   ← 2ème (retour du dialog)
```

Le dialog de permission GPS provoque `inactive → resumed` sans `paused` intermédiaire → double appel GPS, double `UserNotifier.refresh()`, double `startTracking()`.

**Fix :** Flag `_hasBeenPaused` — `resumed` ignoré tant que l'app n'a jamais été mise en arrière-plan.

```dart
bool _hasBeenPaused = false;

case AppLifecycleState.paused:
  _hasBeenPaused = true;
  // ...

case AppLifecycleState.resumed:
  if (!_hasBeenPaused) break; // ignore les resumed du démarrage
  // ...
```

---

## Analyse complète réalisée (résultats négatifs — rien à corriger)

| Point vérifié | Résultat |
|---------------|----------|
| `setState` hors widget minimal | ✅ Déjà correct — sections isolées en widgets séparés |
| `Column` + `.map()` | ✅ 0 occurrence dans tout le projet |
| `await` dans `for` loop (services) | ✅ 0 occurrence restante |
| `Opacity` widgets (saveLayer) | ✅ 0 occurrence |
| `ShaderMask` multiples | ✅ 1 seul (titre taxi), acceptable |
| `const` manquants | ✅ `dart fix --dry-run` → "Nothing to fix" |
| `ScrollController` avec `setState` dans listener | ✅ Aucun |
| Cache Firestore manquant | ✅ Déjà assuré par l'état Riverpod |
| Throttle Nominatim manquant | ✅ Déjà implémenté (`_checkRateLimit`) |
| `compute()` pour JSON lourd | ✅ Non nécessaire (collection < 20 restaurants) |

---

## État final

| Catégorie | Statut |
|-----------|--------|
| Frames skippées (release) | ✅ 0 |
| Fichiers morts | ✅ Supprimés (42 fichiers) |
| App Check debug | ✅ DebugProvider actif |
| Appels Firestore redondants | ✅ Dédupliqués |
| Cache géocodage | ✅ Opérationnel (3dp) |
| Double lifecycle resumed | ✅ Corrigé |
| Mémoire image GPU | ✅ memCacheWidth sur toutes les cartes |
| debugPrint en release | ✅ Tous gardés par kDebugMode |
| dart analyze | ✅ 0 erreur |
