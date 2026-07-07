# Travaux iOS — Velox (session finale, préparation & soumission App Store)

> Fait suite à `travauxIos.md` (session 1) et `TRAVAUXIOS2.md` (sessions 2-3).

---

## 1. Correction de la recherche d'adresse (priorité Djibouti)

**Problème** : la recherche d'adresse (destination VTC + adresse de livraison checkout) renvoyait des résultats du monde entier sans priorité pour Djibouti.

**Fix** — `lib/services/location_service.dart` (`searchPlaces`) :
- Ajout du filtre `countrycodes=dj` sur la requête Nominatim en priorité
- Fallback automatique vers une recherche mondiale si aucun résultat trouvé à Djibouti (évite les "aucun résultat" sur des lieux mal référencés localement)
- Testé et validé avec des recherches réelles ("mall", "Balbala", etc.)

---

## 2. Bug critique : texte invisible en thème sombre

**Symptôme rapporté** : recherche "mall" affichait des positions GPS (coordonnées) au lieu du nom du lieu, sur iPhone 12 uniquement.

**Cause racine** : le titre du résultat de recherche (`ListTile.title`) n'avait **aucune couleur explicite** → héritait de la couleur du thème sombre de l'app (blanc), rendu sur un container à fond **blanc figé en dur** (`Colors.white`) → texte blanc sur blanc = invisible.

**Fix immédiat** : couleur explicite `Colors.black87` ajoutée sur le titre dans :
- `lib/screens/taxi/destination_picker_screen.dart`
- `lib/screens/food/food_tracking/delivery_address_picker_screen.dart`

Ce bug ponctuel a révélé un problème plus large de cohérence des thèmes → voir section 3.

---

## 3. Migration complète du thème clair/sombre (alignement avec Android)

Suite à un prompt de tâche dédié (`PROMPT_THEME_ALIGNEMENT.md`), migration complète pour que le thème dérive uniquement de `lib/theme/app_colors.dart` (`AppColors.dark` / `AppColors.light`, déjà correct et non modifié).

### Moteur de thème central
- **`lib/providers/theme_notifier.dart`** : `ThemeState.themeData` entièrement réécrit pour construire `ColorScheme`/`ThemeData` à partir de `AppColors` (plus aucune couleur en dur, drapeau djiboutien retiré du rendu)
- **`lib/main.dart`** : bloc `theme:` du `MaterialApp` corrigé pour ne plus réécraser le thème avec les anciennes couleurs drapeau (`djiboutiBlue/Green`) — `TextTheme`, `AppBarTheme`, `ElevatedButtonTheme`, `InputDecorationTheme` dérivés de `AppColors`

### Écrans migrés (couleurs en dur remplacées par les rôles `AppColors`)
1. `destination_picker_screen.dart` (VTC)
2. `delivery_address_picker_screen.dart` (checkout food)
3. `sign_up_screen.dart` (auth)
4. `ride_completion_screen.dart` (fin de course VTC)
5. `details_screen.dart` (détail restaurant)
6. `search_screen.dart` (recherche food)
7. `featured_screen.dart` + `components/body.dart`
8. `order_completed_screen.dart` (notation commande)
9. Écrans auth restants : `reset_email_sent_screen.dart`, `phone_login_screen.dart`, `number_verify_screen.dart`
10. `language_selection_screen.dart`

**Découverte utile** : la majorité des écrans (profil, food, taxi, historique...) utilisaient déjà `AppColors` correctement — seuls le moteur central + une dizaine d'écrans legacy nécessitaient la migration.

**Vérifications** : `dart analyze lib` propre sur tout le projet, `flutter test` → 23/23 tests métier (pricing des commandes) passent (seul échec : test template Flutter par défaut, sans rapport avec l'app, préexistant).

---

## 4. Build IPA de distribution

Plusieurs IPA générés au fil des corrections (`flutter build ipa --release`), toujours vérifiés :
- Signature : **Apple Distribution: HODA BARKHADLE (7XH7YBK9H6)**
- `aps-environment` : `production`
- Bundle ID : `dj.velox.client`, Version 1.0.0 (build 1)

**Fix additionnel** : ajout de `ITSAppUsesNonExemptEncryption = false` dans `ios/Runner/Info.plist` (l'app n'utilise que du chiffrement standard HTTPS/TLS via Firebase) → évite qu'Apple repose la question de conformité export à chaque upload.

IPA final : `build/ios/ipa/nomade_client.ipa` (~40.5 Mo).

---

## 5. Préparation de la fiche App Store Connect

### Informations app
- Nom : **Velox** — Sous-titre : **Chaque Seconde Compte**
- Catégorie : Navigation (primaire) + Cuisine et boissons (secondaire)
- Texte promotionnel (147 car.) rédigé
- Description complète, mots-clés, URL marketing/confidentialité rédigés

### Classifications par âge
Questionnaire rempli — réponses "Non"/"Aucun" partout sauf **Contenu généré par les utilisateurs** (avis clients) → "Peu fréquent/léger". Classification attendue : **4+**.

### Chiffrement
Réglé via la clé Info.plist (section 4) — pas de document à uploader, chiffrement standard uniquement.

### Droits relatifs au contenu
Réponse : pas de contenu tiers sous licence (photos restaurants = contenu partenaire normal, pas de musique/vidéo sous droits).

### Réglementations (DSA, Vietnam, dispositifs médicaux, notifications serveur)
Non applicables : app distribuée hors UE (Djibouti uniquement), pas un jeu, pas d'app médicale, pas d'achats intégrés Apple (paiement FDJ hors Apple).

### App Privacy (étiquette de confidentialité)
Audit du code confirmé : collecte de nom, téléphone, email, position précise, photo de profil, avis (tous **liés à l'identité**, stockés Firestore) + données d'usage/diagnostic (Analytics, Crashlytics — **non liées** à l'identité, vérifié : aucun `setUserIdentifier`/`setUserId` dans le code). Pas de tracking publicitaire (pas de pub).

---

## 6. Captures d'écran App Store

**Erreur initiale** : captures prises sur simulateur iPhone 17 Pro Max → 1320×2868 px, refusées par Apple pour ce store (attendait le format 6.5 pouces : 1242×2688 ou 1284×2778).

**Fix** : création d'un simulateur **iPhone 13 Pro Max** (résolution native exacte 1284×2778 px). Connexion avec compte de test (`saida@live.fr`), position GPS réglée sur Djibouti-ville (11.5880, 43.1450), navigation complète dans l'app (onboarding, accueil, profil, VTC réservation/confirmation/suivi/fin de course, accueil restaurants, détail restaurant, checkout, suivi de commande).

**10 captures finales** sélectionnées et organisées dans `~/Desktop/screenshot/` :
```
01_onboarding.png
02_accueil.png
03_profil.png
04_vtc_reservation.png
05_suivi_commande.png
06_vtc_confirmation.png
07_vtc_suivi_chauffeur.png
08_vtc_course_terminee.png
09_accueil_restaurants.png
10_detail_restaurant.png
```
Toutes vérifiées à 1284×2778 px.

---

## 7. Upload TestFlight

**Contrainte** : pas d'accès à Transporter (problème de connexion iCloud). Solution alternative : upload en ligne de commande via `xcrun altool` (déjà présent avec Xcode, pas besoin d'installer Fastlane).

**Clé API App Store Connect créée** (rôle Admin) :
- Key ID : `8PN6V7YQBT`
- Issuer ID : `cf2a6fc7-a683-4ea9-beb4-b2553a171fe7`
- Fichier `.p8` placé dans `~/.appstoreconnect/private_keys/`

**Commande utilisée** :
```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/nomade_client.ipa \
  --apiKey 8PN6V7YQBT \
  --apiIssuer cf2a6fc7-a683-4ea9-beb4-b2553a171fe7
```

**Résultat : UPLOAD SUCCEEDED with no errors** ✅
Delivery UUID : `6735f4a7-3bcf-47b6-9288-d54361f2151f`

---

## 8. Notes de test (App Review / TestFlight)

Texte rédigé pour le champ "Notes" (App Review Information) :
- Compte de test : `saida@live.fr` / mot de passe fourni
- Instructions de connexion (email/mot de passe, pas OTP)
- Parcours de test recommandé : VTC (réservation → confirmation → suivi) et Restaurants (sélection → panier → commande)
- Remarque : l'app est scoping Djibouti — géolocalisation/recherche d'adresse optimisées pour cette zone

---

## Ce qu'il reste à faire

1. **Test interne TestFlight** : utilisateur ajouté et visible dans la liste des testeurs internes — installation à valider sur son iPhone (email d'invitation Apple)
2. **Test externe** (si besoin d'un lien public partageable type Play Store) : créer un groupe de test externe, soumettre à la Beta App Review (24-48h la première fois), puis activer le "Lien public" dans les réglages du groupe
3. **Captures d'écran** : à uploader dans App Store Connect (déjà prêtes dans `~/Desktop/screenshot/`)
4. **Soumission finale à la review Apple** : une fois le test interne validé et la fiche complètement remplie (description, captures, App Privacy, classification d'âge)

## Contraintes techniques à retenir

- **Build iOS = macOS uniquement.** Toute future modification de code nécessitant un nouvel IPA devra repasser par ce Mac (ou un autre Mac avec Xcode) — impossible depuis Windows.
- Gestion de la fiche App Store Connect, TestFlight, testeurs = 100% web, accessible depuis n'importe quel navigateur (Windows OK).
