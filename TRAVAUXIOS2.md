# Travaux iOS — Velox (session 2)

## Ce qui a été fait (session 2)

### 1. Correction Google Sign-In (crash iOS)
- **Cause** : clé `GIDClientID` absente de `Info.plist` — le SDK `google_sign_in` 5.x ne trouvait pas le client ID et crashait immédiatement
- **Fix** : ajout de `GIDClientID` dans `ios/Runner/Info.plist` avec la valeur `91637120258-5q0fa6o0oapl6aema8ss0tj3vauona78.apps.googleusercontent.com`
- **Résultat** : Google Sign-In fonctionne sur les deux iPhones ✅

### 2. Correction bug navigation OTP
- **Cause** : le callback `verificationCompleted` dans `phone_login_screen.dart` naviguait vers la route nommée `/home_food` qui n'existe pas → crash si auto-vérification déclenchée
- **Fix** : remplacé par `Navigator.pushAndRemoveUntil` vers `HomeScreenApp()` (même pattern que le reste du code)

### 3. Passage APNs en production
- `ios/Runner/Runner.entitlements` : `aps-environment` passé de `development` → `production`

### 4. Correction bug FCM token permission-denied à la déconnexion
- **Cause** : deux chemins de déconnexion existaient :
  - `AuthService.signOut()` → clearToken **avant** signOut ✅ correct
  - `UserNotifier.logout()` → signOut **sans** clearToken ❌
  - En plus, `main.dart` ligne 226 appelait `clearToken()` dans le listener `authStateChanges` (user == null), soit **après** que l'auth soit déjà coupée → `permission-denied` Firestore
- **Fix 1** : ajout de `await NotificationService().clearToken()` **avant** `_auth.signOut()` dans `UserNotifier.logout()`
- **Fix 2** : suppression du `clearToken()` redondant dans le listener `main.dart`
- Import `notification_service.dart` ajouté dans `user_notifier.dart`

### 5. Bouton retour page Checkout
- `order_details_screen.dart` : l'icône `location_on` n'était pas identifiable comme bouton retour
- Remplacé par `Icons.arrow_back_ios_rounded` + conservation de l'icône `location_on` à côté du label "checkout"

### 6. Skill velox-deploy créé
- Fichier : `.claude/skills/velox-deploy/SKILL.md`
- Commande : `/velox-deploy` → build release iOS + install sur les 2 iPhones automatiquement
- Téléphones configurés :
  - iPhone mus (wireless) : `0E351098-C88C-58A9-B284-E4E551718827`
  - iPhone 12 (câble) : `26B894D9-22F2-5176-BECA-4AD66199D8D3`
- Bundle ID : `dj.velox.client`

### 7. Installation MCPs
- **Dart MCP** (`dart_mcp_server 1.0.2`) : installé via `dart pub global activate dart_mcp_server`, configuré dans `~/.claude/settings.json`
- **Firebase MCP** : configuré dans `~/.claude/settings.json` via `npx @firebase/mcp`, en attente que Firebase CLI soit installé (Homebrew en cours)
- **⚠️ À faire** : redémarrer Claude Code pour activer les MCPs + tester qu'ils répondent

---

## Ce qui a été fait (session 3)

### 1. Icône App Store régénérée ✅
- L'icône précédente (`Icon-App-1024x1024@1x.png`) était invalide : canal alpha présent + coins arrondis/glow déjà incrustés dans le fichier (double-arrondi une fois masqué par Apple)
- Régénérée depuis `assets/images/logo-velox.png` (carré plein, sans transparence) → toutes les 21 tailles du `AppIcon.appiconset` recréées via `sips`
- Ancien set sauvegardé dans `AppIcon.appiconset.bak.20260702234153`
- Vérifié : 1024×1024, `hasAlpha: no` ✅

### 2. Privacy Policy trouvée ✅
- URL existante et déjà rédigée : **`https://veloxdj.com/confidentialite`**
- Contient : données collectées (compte, GPS, historique commandes, token FCM), usage, partage (partenaires, Firebase, cartographie — jamais de vente), sécurité HTTPS, droits utilisateur, contact (`Haboneabdoulrazak@gmail.com`, `+253 77 45 38 17`)
- À renseigner tel quel dans App Store Connect
- ℹ️ Site `veloxdj.com` n'a actuellement qu'un lien "Google Play" (hero + CTA final) — pas de lien iOS. Pas urgent : à ajouter seulement une fois l'app publiée sur l'App Store (le lien `apps.apple.com/app/id...` n'existera qu'à ce moment-là). Code source du site non trouvé sur cette machine.

### 3. Clé APNs Firebase — créée, uploadée et TESTÉE ✅
- Clé `.p8` créée sur developer.apple.com (Team ID `7XH7YBK9H6`)
- Uploadée dans Firebase Console → Cloud Messaging → Apple app configuration (Key ID + Team ID)
- **Test réel effectué** : build release installé sur iPhone mus, login avec `devchirdon@gmail.com`, token FCM récupéré depuis Firestore (`users/{uid}.fcmToken`), notification test envoyée depuis Firebase Console (Engage → Messaging → Send test message) → **reçue avec succès** ✅
- Note technique importante : un build signé avec le certificat **Apple Development** force automatiquement `aps-environment` à `development` dans le binaire final (Xcode réécrit l'entitlement selon le profil utilisé), même si le fichier source dit `production`. Vérifié via `codesign -d --entitlements`. La même clé `.p8` fonctionne pour sandbox et prod, donc le test reste valide.

### 4. App créée sur App Store Connect ✅
- Bundle ID `dj.velox.client` (déjà enregistré comme Identifier sur developer.apple.com)
- App "Velox" créée sur appstoreconnect.apple.com (plateforme iOS)

### 5. Certificat de distribution + build IPA ✅
- `flutter build ipa --release` exécuté avec succès
- Xcode a généré automatiquement le certificat **"Apple Distribution: HODA BARKHADLE (7XH7YBK9H6)"**
- Vérifié via `codesign -dvvv` sur l'app extraite de l'IPA : signature = Apple Distribution ✅, `aps-environment: production` ✅ (cette fois correctement appliqué, contrairement au build de test)
- IPA généré : `build/ios/ipa/nomade_client.ipa` (41 Mo)

### 6. Launch Image corrigée ✅
- Flutter signalait : "Launch image is set to the default placeholder icon"
- Remplacé le placeholder (`LaunchImage.imageset/*.png`, ~68 octets chacun) par le logo Velox généré depuis `logo-velox.png` (fond noir, cohérent avec le fond noir du `LaunchScreen.storyboard`)
- Tailles générées : @1x 200×200, @2x 400×400, @3x 600×600
- Storyboard mis à jour (dimensions de référence 200×200)
- Rebuild confirmé : l'avertissement `[!] App Icon and Launch Image Assets Validation` a disparu

### 7. Logo HomeScreen adapté au thème clair ✅
- Problème : sur la page d'accueil (VTC/Food, message de bienvenu), le logo `logo-velox.png` a un fond noir qui « fait tache » en thème blanc
- Fix : remplacé uniquement dans `lib/screens/homeScreen/home_screen_app.dart:146` par `assets/images/logo-velox-sansBG.png` (fond transparent, `hasAlpha: yes`)
- **Pas touché ailleurs** : `velox_loader.dart` (écran de chargement) garde `logo-velox.png` avec fond noir, comme demandé
- Testé sur iPhone mus dans les deux thèmes (clair + sombre) → confirmé ✅

### 8. Firebase CLI installé ✅
- `npm install -g firebase-tools` → version installée : `15.22.4`
- **Reste à faire** : `firebase login` (authentification interactive) + redémarrer Claude Code pour activer le MCP Firebase

### 9. Contenu de la fiche App Store Connect rédigé (prêt à copier-coller)
- **Sous-titre** : `Taxi & livraison à Djibouti`
- **Catégorie primaire** : Voyage — **secondaire** : Nourriture et boissons
- **Description** : texte complet rédigé (VTC, livraison de repas, programme fidélité, simplicité/fiabilité)
- **Mots-clés** : `taxi,djibouti,vtc,livraison,repas,nourriture,course,chauffeur,commande,restaurant`
- **URL marketing/support** : `https://veloxdj.com`
- **URL politique de confidentialité** : `https://veloxdj.com/confidentialite`
- **Contact review Apple** : `Haboneabdoulrazak@gmail.com` / `+253 77 45 38 17`
- **⏳ À faire** : coller ce contenu dans App Store Connect + ajouter les captures d'écran (vérifier si celles mentionnées en session 1 comme "déjà faites" sont bien aux bonnes dimensions : iPhone 6.5" = 1284×2778 ou 1242×2688 minimum)

---

## Ce qui a été fait (session 4)

> Suite de la session 3 + soumission App Store complète : voir `travauxIOSfinal.md` pour le détail
> (migration thème clair/sombre, fix recherche Djibouti, captures d'écran, upload TestFlight réussi
> via `xcrun altool`). Cette section couvre les 2 derniers correctifs appliqués après l'upload.

### 1. Correction notifications push iOS (basé sur `PROMPT_AGENT_IOS.md`) ✅
- **Confirmé fonctionnel côté infra** : clé APNs .p8 correctement configurée (notifications test envoyées avec succès depuis Firebase Console)
- **Cause du souci restant** : `lib/services/notification_service.dart` n'appelait jamais `getAPNSToken()` avant `getToken()` → race condition possible au 1er lancement (le token FCM peut être `null` si l'OS n'a pas fini d'enregistrer l'app auprès d'APNs)
- **Fix 1** : ajout de `_waitForApnsToken()` — attend le token APNs avec retry (5 tentatives, 1s de délai) avant d'appeler `getToken()`
- **Fix 2** : ajout de `FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert/badge/sound: true)` sur iOS dans `initialize()` — garantit l'affichage correct quand l'app est au premier plan
- `AppDelegate.swift` vérifié correct (proxy Firebase `FirebaseAppDelegateProxyEnabled=true` gère le pont APNs automatiquement, pas de modification nécessaire)
- Installé et testé sur iPhone mus

### 2. Correction extras/sauces en dur (aligné sur le fix déjà appliqué côté Android Kotlin) ✅
- **Fichier** : `lib/screens/food/addToOrder/add_to_order_screen.dart`
- **Problème** : un plat sans `optionGroups` affichait des extras/sauces inventés (Frites, Tailles L/XL/XXL, sauces Samouraï/Mayo...) qui n'existaient pas réellement pour ce plat
- **Fix** : suppression complète de `_initializeExtrasAndSauces()`, des champs `_extras`/`_sauces`, des getters `_extrasTotal`/`_saucesTotal`, et des widgets `_buildExtraItem`/`_buildSauceGrid`. Un plat sans options affiche maintenant juste image + prix + quantité + bouton, sans aucune section d'options
- `_optionsSurcharge` retourne `0` et `OrderItem` reçoit `extras: []`/`sauces: []` pour ces plats
- Vérifié : `dart analyze lib` propre, `flutter test` → 24/24 tests passent (aucune régression sur le pricing)
- Installé et testé sur iPhone mus

---

## Ce qu'il reste à faire avant publication App Store

### ✅ RÉSOLU

1. ~~Clé APNs Firebase~~ ✅ créée, uploadée, testée
2. ~~Certificat de distribution~~ ✅ généré automatiquement par Xcode
3. ~~Créer l'app sur App Store Connect~~ ✅ fait (Bundle ID `dj.velox.client`)
4. ~~Uploader le build vers TestFlight~~ ✅ fait via `xcrun altool` (clé API App Store Connect) — voir `travauxIOSfinal.md`
5. ~~Remplir la fiche App Store Connect~~ ✅ description, mots-clés, catégories, captures d'écran (1284×2778) — voir `travauxIOSfinal.md`
6. ~~Notifications push iOS~~ ✅ corrigées (session 4, ci-dessus)
7. ~~Extras/sauces en dur~~ ✅ corrigés (session 4, ci-dessus)

### À FAIRE

8. **Activer le MCP Firebase**
   - `! firebase login` (authentification interactive)
   - Redémarrer Claude Code
   - Vérifier que `mcp__firebase__*` et `mcp__dart__*` répondent

9. **Test interne TestFlight**
   - Utilisateur ajouté et visible dans la liste des testeurs internes
   - Installation à valider sur iPhone (email d'invitation Apple)

10. **Soumission finale à la review Apple** une fois le test interne validé

### RECOMMANDÉ

11. **Firebase App Check** — activer DeviceCheck pour protéger Firestore
12. **Vérifier Crashlytics** — déjà vérifié en session 2 ✅

---

## Commandes utiles

```bash
# Build + install sur les 2 téléphones (dev, aps-environment forcé en development)
/velox-deploy

# Build IPA distribution (App Store / TestFlight) — aps-environment production, cert Apple Distribution
flutter build ipa --release

# Vérifier la signature et les entitlements d'un build
codesign -dvvv build/ios/iphoneos/Runner.app
codesign -d --entitlements :- build/ios/iphoneos/Runner.app

# Lancer uniquement sur iPhone mus
xcrun devicectl device process launch --device 0E351098-C88C-58A9-B284-E4E551718827 dj.velox.client

# Installer un build sur iPhone mus
xcrun devicectl device install app --device 0E351098-C88C-58A9-B284-E4E551718827 build/ios/iphoneos/Runner.app
```
