# iOS — Étapes Xcode (à faire sur le Mac)

App : **Nomade Client** · Bundle ID : **`dj.velox.client`** · Projet Firebase : `nomade253-478a9`

> Tout ce qui est faisable depuis Windows est déjà fait (bundle ID, `GoogleService-Info.plist`,
> `firebase_options.dart`, permissions + URL scheme dans `Info.plist`).
> Ce mémo couvre uniquement ce qui **exige macOS + Xcode**.

---

## 0. Prérequis sur le Mac
- [ ] macOS + **Xcode** installé (App Store)
- [ ] **CocoaPods** : `sudo gem install cocoapods`
- [ ] **Flutter** installé, projet cloné
- [ ] **Compte Apple Developer payant (99 $/an)** — obligatoire pour les push iOS

---

## 1. Récupérer les dépendances
```bash
cd nomade_client
flutter pub get
cd ios
pod install            # génère le Podfile + Pods/ (Firebase natif, geolocator, etc.)
cd ..
```
> Toujours ouvrir **`ios/Runner.xcworkspace`** (PAS `Runner.xcodeproj`) une fois les pods installés.

---

## 2. Vérifier que `GoogleService-Info.plist` est dans la target Runner ⚠️
Le fichier est déjà physiquement dans `ios/Runner/`, mais il doit être **référencé par la target**
(sinon il n'est pas embarqué dans le build et Firebase plante au lancement).

1. Ouvrir `ios/Runner.xcworkspace` dans Xcode
2. Dans le navigateur de gauche, vérifier que `GoogleService-Info.plist` apparaît sous le groupe **Runner**
   - S'il **n'apparaît pas** : clic droit sur le dossier `Runner` → **Add Files to "Runner"…** → sélectionner
     `ios/Runner/GoogleService-Info.plist` → cocher **« Copy items if needed »** et la case target **Runner** → Add
3. Sélectionner le fichier → onglet **File Inspector** (à droite) → vérifier que **Target Membership ▸ Runner** est coché ✅

---

## 3. Signing (compte de développement)
1. Sélectionner le projet **Runner** (racine, en haut du navigateur) → target **Runner** → onglet **Signing & Capabilities**
2. **Team** : sélectionner ton équipe Apple Developer
3. **Bundle Identifier** : doit afficher **`dj.velox.client`** (déjà configuré — vérifier)
4. Cocher **Automatically manage signing** (le plus simple)

---

## 4. Notifications push (APNs) — obligatoire pour `firebase_messaging`
### 4a. Activer les capabilities dans Xcode
Toujours dans **Signing & Capabilities** → bouton **+ Capability** :
- [ ] Ajouter **Push Notifications**
- [ ] Ajouter **Background Modes** → cocher **Remote notifications**

> Cela crée/complète le fichier `Runner.entitlements`. Garder ce fichier (le committer).

### 4b. Créer la clé APNs chez Apple
1. https://developer.apple.com → **Certificates, Identifiers & Profiles** → **Keys** → **+**
2. Cocher **Apple Push Notifications service (APNs)** → Continue → Register
3. **Télécharger le fichier `.p8`** (⚠️ téléchargeable **une seule fois**) et noter :
   - **Key ID** (10 caractères)
   - **Team ID** (en haut à droite du portail Apple)

### 4c. Uploader la clé dans Firebase
1. Console Firebase → ⚙️ **Project settings** → onglet **Cloud Messaging**
2. Section **Apple app configuration** → app **`dj.velox.client`** → **APNs Authentication Key** → **Upload**
3. Charger le `.p8` + renseigner **Key ID** et **Team ID**

---

## 5. Permissions (déjà dans `Info.plist` — juste à vérifier)
Présentes et OK depuis Windows :
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `CFBundleURLTypes` → scheme `com.googleusercontent.apps.91637120258-5q0fa6o0oapl6aema8ss0tj3vauona78`

---

## 6. Lancer / tester
```bash
flutter devices                       # repérer le simulateur ou l'iPhone
flutter run -d <id>                   # build + lancement
# ou build release sans signer (CI) :
flutter build ios --release --no-codesign
```
> Le **simulateur** ne reçoit PAS les push APNs réels — tester les notifications sur un **iPhone physique**.

---

## 7. Checklist finale avant TestFlight
- [ ] App se lance, Firebase s'initialise (pas d'erreur `GoogleService-Info`)
- [ ] Connexion Google fonctionne (scheme URL OK)
- [ ] GPS demande l'autorisation et fonctionne (suivi livreur / taxi)
- [ ] Photo de profil (caméra + photothèque) OK
- [ ] Push reçue sur iPhone physique
- [ ] Archive (Xcode ▸ Product ▸ Archive) → upload TestFlight

---

### Rappels de cohérence (ne pas casser)
- Bundle ID partout = **`dj.velox.client`** (Android + iOS alignés)
- `appId` iOS = `1:91637120258:ios:4626636d3ca3a96759d61b`
- `iosClientId` = `91637120258-5q0fa6o0oapl6aema8ss0tj3vauona78.apps.googleusercontent.com`
- Si tu régénères la config via `flutterfire configure`, vérifier que ces valeurs restent identiques.
