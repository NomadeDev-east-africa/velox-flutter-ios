# TRAVAUX 13 — Récapitulatif complet de la session

Branche : `feature/design-review` — Projet : Velox (nomade_client) — Firebase : `nomade253-478a9`
Toutes les modifications décrites ci-dessous sont **dans le working tree (non commitées)** sauf mention contraire.

---

## 0. Récupération du projet (reset Git)

Le projet était cassé. On est revenu à la dernière version saine du serveur :
- `git fetch origin`
- `git reset --hard origin/feature/design-review`
- `git clean -fd`

→ Toutes les modifications locales non sauvegardées ont été supprimées (assets restaurés, fichiers `TRAVAUX11.txt`, `travaux10.md`, dossiers components/support/search supprimés). Base propre = commit `2b0f29c` « Mise à jour majeure ».

**Conséquence importante** : ce reset a fait régresser du travail déjà fait avant (points fidélité, gestion timestamps, i18n…) qu'il a fallu **ré-implémenter** ensuite.

---

## 1. Tâche 5 — Onboarding (3 écrans → 1 seul écran)

Fichier : `lib/screens/onboarding/onboarding_screen.dart`
- Suppression du `PageView`, des indicateurs (dots), de la navigation entre slides et de la liste `demoData`.
- Un seul écran : illustration `velox1.svg`, titre « Bienvenue sur Velox », texte court, bouton **DÉMARRER**.
- `Navigator.push` → `Navigator.pushReplacement` (pas de retour arrière vers l'onboarding).
- Widget passé de `ConsumerStatefulWidget` à `ConsumerWidget`.
- Illustrations `velox2.svg` / `velox3.svg` supprimées (voir nettoyage assets).

---

## 2. Tâche 4 — Écran Support & Aide

- **Nouveau** : `lib/screens/profile/support/support_screen.dart`
  - Signaler un bug : `tel:77591823`
  - Email support : `mailto:devchirdon@gmail.com`
  - Responsable plateforme : `tel:77453817`
  - Email responsable : `mailto:Ouzeurb@gmail.com`
  - Chaque contact en carte cliquable via `url_launcher`.
- `lib/screens/profile/profile_screen.dart` : le menu « Centre d'aide » ouvre désormais `SupportScreen`.

---

## 3. Nettoyage des assets (≈53 fichiers supprimés)

Méthode : suppression vérifiée par `grep` de chaque référence dans le code (pas confiance aveugle au plan).
- **Images** supprimées : Header-image, big_1..4, featured_items_1..3, medium_1..4, logo.png.
- **Illustrations** supprimées : Illustrations_1/2/3, chauffeur, nomade1, nomade253, nomadeDriver, nomadeScooter, velox2, velox3.
- **Polices** : dossier `assets/font/` entier (SFProText x4) — bloc `fonts:` retiré de `pubspec.yaml` (l'app utilise Poppins via google_fonts).
- **Véhicules** : sedan, taxi-comfort, taxi-standard, taxi-van.
- **Icônes** (25 SVG) : back, camera, card, cart, close, document, done, fast-delivery, fb, fire, food, forward, home, invisible, location, logout, marker, minus, notify, order, phone, plus, profile, recomended, visible.
- **Gardés** : logo-velox.png, banner.png, fast-food.png ; taxi-A/B/taxiprobox.png ; velox1.svg ; icônes google/facebook/search/clock/delivery/share/rating/lock.
- **Bug corrigé** : `lib/data/mock_taxi_data.dart` — chemin `assets/images/taxiprobox.png` → `assets/vehicule/taxiprobox.png`.

Note : la liste d'icônes du plan d'origine était inexacte (apple/twitter/instagram… inexistants ; facebook utilisé) → corrigée via grep réel.

---

## 4. Tâche 1 — Recherche repas

- **Nouveau** : `lib/screens/food/search/food_search_screen.dart`
  - `TextField` avec **debounce 300 ms** (Timer).
  - Chargement unique restaurants + plats, puis **filtrage en mémoire** (instantané).
  - Deux sections : **Restaurants** (par nom) et **Plats** (par nom + description), avec compteurs.
  - Résultat cliquable → `DetailsScreen` (un plat ouvre le restaurant qui le propose).
- `lib/screens/food/home_food/home_screen_food.dart` : icône `shopping_cart_outlined` remplacée par `Icons.search` (GestureDetector → FoodSearchScreen). Le panier reste accessible via le `FloatingCartButton`.

---

## 5. Tâche 2 — Carousels automatiques (best-sellers + catégories)

Fichier : `lib/screens/food/home_food/home_screen_food.dart`
- Nouveau widget réutilisable `_AutoScrollCarousel` :
  - `PageController` + `Timer.periodic` (défilement toutes les **4 s**, boucle infinie via modulo).
  - **Pause sur interaction** détectée proprement via `NotificationListener` (`dragDetails != null`) — évite le bug du plan d'origine où l'auto-scroll se déclenchait lui-même comme une interaction.
  - **Reprise après 5 s** d'inactivité.
  - Indicateurs (dots) animés dans un `Wrap` (anti-débordement).
  - `dispose()` (timers + controller) + `didUpdateWidget` (changement de nombre d'items, providers réactifs).
- `_CategoryRow` et `_PopularList` utilisent ce carousel ; cartes `_PopularCard` / catégorie réutilisées.

---

## 6. Tâche 3 — Points fidélité (9 étapes)

Architecture : **Points = gagnés (dérivés) − dépensés (stockés)**.

1. `lib/constants.dart` : `kPointsPerOrder = 10`, `kPointValue = 15` (FDJ/point).
2. `lib/providers/order_stats_provider.dart` :
   - `redeemedPointsProvider` (stream `users/{uid}.redeemedPoints`).
   - `availablePointsProvider` = gagnés − dépensés (jamais négatif).
3. `lib/models/order.dart` : champs `pointsUsed` + `discount` ; `total = subtotal + deliveryFee − discount` ; ajoutés à toMap / fromFirestore / toJson / fromJson / copyWith.
4. `lib/providers/cart_notifier.dart` : paramètre `pointsUsed`, calcul `discount` **plafonné aux frais de livraison** (`deliveryFee ~/ kPointValue`), débit non bloquant via `redeemPoints`, notification sur `order.total`.
5. `lib/providers/user_notifier.dart` : méthode `redeemPoints()` (`FieldValue.increment` + merge).
6. `lib/screens/food/orderDetails/order_details_screen.dart` : section promo → **section points fidélité** (appliquer / retirer), ligne de réduction dans le récap, `pointsUsed` passé au checkout.
7. `lib/screens/homeScreen/home_screen_app.dart` : solde **disponible** affiché ; badge VIP/GOLD/MEMBER basé sur le **cumul gagné** (ne régresse pas après dépense).
8. `firestore.rules` : `redeemedPoints` ajouté à la whitelist `users.update` + **contrainte de monotonie** (ne peut que croître = anti-triche). Le fichier de **prod** (Bureau : `.../production/firestores regles unique/firestore_rules.rules`) avait déjà cette règle (survécu au reset).
9. `functions/index.js` : `validatePrices` recalcule `pointsUsed`/`discount`/`total` côté serveur (plafond inclus) ; revenu restaurant = `total + discount` (le restaurant touche le prix plein, la remise est plateforme).

⚠️ **À déployer** : `firebase deploy --only functions` + coller les règles de prod dans la console Firebase.

---

## 7. Bug « historique des commandes » (timestamps + locale)

Le reset avait fait régresser la gestion des dates → crash + historique vide.

### 7.1 Lecture tolérante
`lib/models/order.dart` : helper `Order._parseTs(dynamic)` qui accepte `Timestamp`, `String` ISO 8601 ou `int` (ms). Appliqué à tous les champs date de `fromFirestore` (createdAt, updatedAt, acceptedAt, readyAt, pickedUpAt, deliveredAt, cancelledAt). → Plus de crash « String is not a subtype of Timestamp », et lit les deux formats.

### 7.2 Tri sans index ni crash
`lib/services/order_service.dart` : `getUserOrders` / `streamUserOrders` — suppression de `.orderBy('createdAt')` (qui regroupe par type sur un champ mixte → historique partiel) → lecture filtrée par `userId` + **tri client** décroissant + `take(20)`.

### 7.3 Format d'écriture — DÉCISION FINALE = Timestamp
- D'abord passé en écriture ISO, puis **REVENU à Timestamp** sur demande du client (l'écosystème — apps restaurant/admin/livreur — utilise des `Timestamp`).
- `toMap()` écrit les `Timestamp` bruts ; `OrderService.updateOrderStatus`/`cancelOrder` et `order_completed_screen` (orders ratedAt/updatedAt) utilisent `FieldValue.serverTimestamp()`. La sous-collection `restaurants/avis` reste en serverTimestamp.
- ⚠️ **Piège MCP** : le MCP Firebase sérialise les `Timestamp` en chaîne ISO dans son JSON — il ne permet PAS de distinguer le vrai type de stockage ; seule la console Firebase le montre.

### 7.4 Vrai crash de l'écran historique = locale
`LocaleDataException: Locale data has not been initialized` à `order_history_screen.dart` (`DateFormat(..., 'fr_FR')`).
- `lib/main.dart` : ajout de `initializeDateFormatting('fr_FR', null)` avant `runApp` (import `package:intl/date_symbol_data_local.dart`). C'était la vraie cause, indépendante du type des dates.

---

## 8. Moyens de paiement → cash, Waafi, D-Money, CAC Pay

Valeurs canoniques : `cash` / `waafi` / `d_money` / `cac_pay` (icônes : `payments_outlined` pour cash, `account_balance_wallet` pour les wallets).
- Food : `order_details_screen.dart` (`_buildPaymentSection`, défaut `cash`).
- Taxi : `ride_confirmation_screen.dart` (`_showPaymentMethods` + `_paymentLabel`, défaut `cash`).
- Historique : `order_history_screen.dart` (helpers `_paymentLabel` / `_paymentIcon`, gèrent aussi les anciens `card` / `mobile_wallet`).
- Anciennes valeurs retirées des sélecteurs : `card`, `mobile_wallet`.

---

## 9. Changement de langue (3 bugs corrigés)

Système maison `tr(key)` → map **statique** `AppTranslations._currentTranslations`.
1. **Réactivité** : `lib/main.dart` — `MyApp` écoute `languageNotifierProvider` et keye le sous-arbre : `home: KeyedSubtree(key: ValueKey('lang_$language'), child: AuthWrapper())`. Au changement, l'arbre se reconstruit (retour à l'onglet Accueil — voulu).
2. **Ordre** : `LanguageNotifier.setLanguage` appelle `AppTranslations.setLanguage(code)` **avant** `state = copyWith(...)` (sinon le rebuild lit l'ancienne map).
3. **Code Afar** : le sélecteur envoyait `'AF'` mais `AppTranslations` attend `'aa'` → l'afar ne changeait jamais. Aligné sur `'AA'` partout (`language_notifier.dart` + dialog `profile_screen.dart`).

Codes : `fr / en / so / ar / aa` (Afar = **aa**).

---

## 10. Internationalisation des écrans principaux (i18n)

Constat : au départ seulement ~15 `tr()` dans 51 écrans (≈95 % codé en dur).
Dictionnaires `fr/en/ar/so/aa` portés de **115 → 227 clés**, **parité parfaite** (aucune clé brute possible).

**Écrans entièrement câblés (`flutter analyze` OK) :**
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/homeScreen/home_screen_app.dart`
- `lib/screens/food/orderDetails/order_details_screen.dart` (checkout)
- `lib/screens/food/details/details_screen.dart` (avis)
- `lib/screens/history/order_history_screen.dart`
- `lib/screens/taxi/taxi_home_screen.dart`
- `lib/screens/taxi/ride_confirmation_screen.dart`

Méthode : import `translations/app_translations.dart`, chaînes en dur → `tr('clé')`, réutilisation max des clés, ajout des manquantes aux 5 fichiers en gardant la parité.

**Laissé en dur volontairement** : marque (DJIBOUTI, VTC DJIB, Velox, badges VIP/GOLD), noms de wallets (Waafi/D-Money/CAC Pay), labels « techy » stylisés (CURRENT_GPS, v1.0_ID), données mock.

**Limites connues / à faire :**
- Traductions **somali (so)** et **afar (aa)** des nouvelles clés = best-effort → à faire **relire par un natif**.
- **RTL arabe** non géré (texte en arabe mais layout LTR).
- **Dates** historique restent en `fr_FR` (seul locale initialisé ; changer le locale sans l'initialiser planterait).
- Il reste ~44 **écrans secondaires** non traduits (auth, food_tracking, adresses, recherche, edit_profile…).

---

## 11. Route livreur → client (suivi de livraison)

Fichier : `lib/screens/food/food_tracking/track_delivery_screen.dart` (écran « Position du livreur », ouvert depuis `OrderTrackingScreen` via « Voir le livreur », statut `delivering`).
- Ajout d'une **route routière** entre le pin du **livreur** et le pin du **client**, via `LocationService.getRoute()` (OpenRouteService, repli ligne droite si pas de clé/réseau).
- **Recalcul dynamique** quand le livreur bouge de plus de **40 m** (throttle), branché sur le `StreamBuilder` GPS temps réel.
- `PolylineLayer` (couleur primaire + contour blanc) dessinée sous les marqueurs.
- Vérifié : `OrderTrackingScreen` transmet bien `deliveryLocation` (pin client) → la route s'affiche.
- Option non faite (au choix) : cadrer les 2 pins simultanément (`fitCamera`) au lieu de centrer sur le livreur.

---

## Récapitulatif des fichiers modifiés / créés

**Créés :**
- `lib/screens/profile/support/support_screen.dart`
- `lib/screens/food/search/food_search_screen.dart`

**Modifiés (principaux) :**
- `lib/main.dart`
- `lib/constants.dart`
- `lib/models/order.dart`
- `lib/services/order_service.dart`
- `lib/providers/order_stats_provider.dart`, `cart_notifier.dart`, `user_notifier.dart`, `language_notifier.dart`
- `lib/data/mock_taxi_data.dart`
- `lib/screens/onboarding/onboarding_screen.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/homeScreen/home_screen_app.dart`
- `lib/screens/food/home_food/home_screen_food.dart`
- `lib/screens/food/orderDetails/order_details_screen.dart`
- `lib/screens/food/details/details_screen.dart`
- `lib/screens/history/order_history_screen.dart`
- `lib/screens/taxi/taxi_home_screen.dart`, `ride_confirmation_screen.dart`
- `lib/screens/food/food_tracking/track_delivery_screen.dart`, `order_completed_screen.dart`
- `lib/translations/fr.dart`, `en.dart`, `ar.dart`, `so.dart`, `aa.dart` (227 clés chacun)
- `pubspec.yaml`
- `firestore.rules`
- `functions/index.js`

---

## Actions restantes (déploiement / suivi)

1. **Déployer les Cloud Functions** : `firebase deploy --only functions` (validation prix/points serveur).
2. **Coller les règles Firestore de prod** dans la console Firebase (le fichier Bureau est déjà à jour).
3. **Faire relire** les traductions somali/afar par un natif.
4. (Optionnel) RTL arabe, dates localisées, i18n des écrans secondaires, cadrage 2 pins sur le suivi livreur.
5. **Commiter** le travail (rien n'est commité pour l'instant).

---

## Vérifications faites pendant la session
- `flutter analyze` : 0 problème sur tous les fichiers Dart touchés.
- `node --check functions/index.js` : OK.
- Parité des 5 fichiers de langue : 227 clés chacun.
- Format des dates `orders` confirmé via MCP Firebase + console (Timestamp côté écosystème).
