# Rapport de corrections — Nomade Client
*Session du 2026-04-09*

---

## Origine : Analyse du log de débogage

L'analyse du log Android (device Samsung SM M055F, debug mode) a permis d'identifier
9 bugs répartis en deux phases de correction.

---

## Phase 1 — Corrections issues du log

### Bug 1 · MAJEUR — Adresse de livraison toujours `"null"`
**Fichier :** `lib/screens/food/food_tracking/delivery_address_picker_screen.dart`

**Symptôme dans le log :**
```
🎯 Adresse: "null"  ← répété 3 fois lors de la confirmation
```

**Cause :** `getAddressForPosition()` ne met à jour `state.address` que si
`position == state.position` (position GPS). Or `_customDeliveryPosition`
(centre de la carte déplacée par l'utilisateur) est différente de la position GPS
→ l'adresse geocodée n'était jamais persistée dans le state du provider.

**Correction :**
- Ajout du champ local `String? _customAddress` dans le widget
- Les 3 points d'entrée (init, déplacement carte, sélection recherche) capturent
  l'adresse via `.then()` et la stockent dans `_customAddress`
- `_confirmDeliveryAddress()` et le panneau d'affichage utilisent
  `_customAddress ?? locState.address`

---

### Bug 2 · MAJEUR — Double `attachOrder` sur la même commande
**Fichiers :** `lib/providers/active_order_notifier.dart`
           `lib/screens/food/food_tracking/order_tracking_screen.dart`

**Symptôme dans le log :**
```
🔗 [ActiveOrder] attachOrder appelé: 6mcXMSz8Op9JfWSL5Kh7  (×2)
📡 [ActiveOrder] Stream démarré: 6mcXMSz8Op9JfWSL5Kh7      (×3)
```

**Cause :** `CartNotifier.createOrder()` appelle `attachOrder()` qui fait
`clearOrder: true` → `state.order = null`. Le `addPostFrameCallback` de
`OrderTrackingScreen` se déclenche, trouve `order == null` et rappelle
`attachOrder()` une seconde fois. Race condition entre l'appel asynchrone
et la création du widget.

**Correction :**
- `active_order_notifier.dart` : vérification d'idempotence en tête de
  `attachOrder()` — si même orderId déjà en `isLoading` ou `isWatching`, retour immédiat
- `order_tracking_screen.dart` : `_tryAttachOrder()` vérifie aussi
  `!currentState.isLoading` avant de re-déclencher un attach

---

### Bug 3 · MAJEUR — Jank sévère au démarrage (104 frames skippés)
**Fichier :** `lib/main.dart`

**Symptôme dans le log :**
```
Skipped 39 frames!
Skipped 46 frames!
Skipped 104 frames!  ← Davey! duration=1317ms
Skipped 75 frames!
```

**Cause :** Le listener `authStateChanges()` appelait `NotificationService.initialize()`
immédiatement à la connexion, déclenchant la création d'un background Flutter engine
Firebase (`FLTFireBGExecutor`) pendant le rendu du premier frame.

**Correction :**
- Ajout de `await Future.delayed(const Duration(milliseconds: 200))` dans le
  listener auth avant l'init notifications → l'UI rend ses premiers frames avant
  que Firebase crée son background engine

---

### Bug 4 · AVERTISSEMENT — Timeout Firestore trop court
**Fichier :** `lib/providers/active_order_notifier.dart`

**Symptôme dans le log :**
```
❌ [ActiveOrder] Erreur stream: TimeoutException: Firestore stream timeout
🔄 [ActiveOrder] Reconnexion dans 0:00:02.000000 (tentative 1)
```

**Cause :** Timeout configuré à 45 secondes, trop court sur réseau lent.
La reconnexion automatique fonctionnait mais générait des erreurs inutiles.

**Correction :** Timeout 45s → **90s**

---

### Bug 5 · AVERTISSEMENT — GPS désactivé sans message utilisateur
**Fichier :** `lib/screens/food/food_tracking/delivery_address_picker_screen.dart`

**Symptôme dans le log :**
```
❌ Erreur getCurrentLocation: Les services de localisation sont désactivés (×5)
✅ Position initialisée: LatLng(latitude:11.588, longitude:43.145)  ← fallback silencieux
```

**Cause :** L'app utilisait silencieusement une position par défaut sans informer
l'utilisateur que son GPS était désactivé.

**Correction :**
- Import `geolocator` ajouté dans le picker
- Ajout de `_showGpsDisabledBanner()` : SnackBar de 6 secondes avec bouton
  **"Activer"** qui ouvre directement les paramètres de localisation Android
  via `Geolocator.openLocationSettings()`

---

## Phase 2 — Corrections issues de l'analyse statique complète du projet

### Bug 6 · MAJEUR — Crash context invalide après `popUntil`
**Fichier :** `lib/screens/food/food_tracking/order_completed_screen.dart:68`

**Cause :** `ScaffoldMessenger.of(context)` appelé après `Navigator.popUntil()`.
Après le dépilage du widget, `context` est invalide → crash potentiel.

```dart
// AVANT (bugué)
Navigator.of(context).popUntil((route) => route.isFirst);
ScaffoldMessenger.of(context).showSnackBar(...); // context invalide ici

// APRÈS (corrigé)
final messenger = ScaffoldMessenger.of(context); // sauvegardé avant pop
Navigator.of(context).popUntil((route) => route.isFirst);
messenger.showSnackBar(...);
```

---

### Bug 7 · MAJEUR — Logique incorrecte sur `state.address` null
**Fichier :** `lib/providers/location_notifier.dart:236`

**Cause :** `state.address.toString().startsWith(cached)` quand `state.address`
est `null` → `"null".startsWith(...)` → logique fausse et trompeuse, fonctionnait
par accident.

```dart
// AVANT (bugué)
if (position == state.position && !state.address.toString().startsWith(cached))

// APRÈS (corrigé)
if (position == state.position && state.address != cached)
```

---

### Bug 8 · MAJEUR — Memory leak : `Completer` jamais résolu au dispose
**Fichier :** `lib/providers/location_notifier.dart:244`

**Cause :** `getAddressForPosition()` crée un `Completer` dans un debounce Timer.
Si le widget est dispose ou si une nouvelle position arrive avant l'expiration
du Timer, l'ancien `Completer` n'est jamais complété → toutes les Futures `.then()`
en attente restent suspendues indéfiniment (memory leak).

**Correction :**
- Ajout du champ `Completer<String?>? _pendingCompleter`
- Chaque nouvel appel complète le `Completer` précédent avec `null` avant de
  le remplacer
- `dispose()` complète le dernier `Completer` en attente s'il existe

---

### Bug 9 · MINEUR — `attachOrder` sans gestion d'erreur dans `CartNotifier`
**Fichier :** `lib/providers/cart_notifier.dart:275`

**Cause :** Si `attachOrder()` lève une exception, elle remontait dans
`createOrder()` et laissait `isCreatingOrder: true` pour toujours,
bloquant le bouton "Commander".

**Correction :** Encapsulation dans un `try/catch` non bloquant avec log.
La commande est créée même si l'attach de tracking échoue.

---

## Récapitulatif

| # | Sévérité  | Fichier                              | Statut |
|---|-----------|--------------------------------------|--------|
| 1 | Majeur    | delivery_address_picker_screen.dart  | ✅ Corrigé |
| 2 | Majeur    | active_order_notifier.dart + order_tracking_screen.dart | ✅ Corrigé |
| 3 | Majeur    | main.dart                            | ✅ Corrigé |
| 4 | Avertissement | active_order_notifier.dart       | ✅ Corrigé |
| 5 | Avertissement | delivery_address_picker_screen.dart | ✅ Corrigé |
| 6 | Majeur    | order_completed_screen.dart          | ✅ Corrigé |
| 7 | Majeur    | location_notifier.dart               | ✅ Corrigé |
| 8 | Majeur    | location_notifier.dart               | ✅ Corrigé |
| 9 | Mineur    | cart_notifier.dart                   | ✅ Corrigé |

**9 bugs corrigés — 0 bug connu restant (hors non-critiques liés à l'environnement dev)**

---

## Non-critiques laissés volontairement

| Problème | Raison |
|----------|--------|
| `No AppCheckProvider installed` | À configurer en production uniquement |
| `GoogleApiManager SecurityException` | Spécifique au device Samsung de test, non bloquant |
| `FlagRegistrar / Phenotype.API` | API interne Google indisponible sur ce device, ignorable |
| Status commandes en `String` plutôt qu'enum | Refactoring, pas un bug fonctionnel |
