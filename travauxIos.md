# Travaux iOS — Velox (nomade_client)

## Ce qui a été fait dans cette session

### 1. Résolution des erreurs de build Xcode
- Correction de l'erreur "Missing package product 'FlutterGeneratedPluginSwiftPackage'"
- Activation de Swift Package Manager pour Flutter : `flutter config --enable-swift-package-manager`
- Correction de "Module 'cloud_firestore' not found" dans GeneratedPluginRegistrant.m
- Copie des xcframeworks Firebase/gRPC depuis DerivedData vers `build/ios/SourcePackages/artifacts/`
- Suppression des répertoires SPM corrompus (stale artifacts)

### 2. Mise à jour de la cible iOS
- Deployment target : `13.0` → `15.0` (requis par cloud_firestore)
- Mis à jour dans : `ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj` (3 configurations : Debug, Release, Profile)

### 3. Code signing
- Team ID identifié : `7XH7YBK9H6` (HODA BARKHADLE)
- Ajout de `DEVELOPMENT_TEAM = 7XH7YBK9H6` dans `project.pbxproj` (3 configs)
- Certificat créé automatiquement : "Apple Development: HODA BARKHADLE (8YWK8QMC74)"
- Activation du Mode Développeur sur les deux iPhones de test
- Enregistrement des UDIDs dans le portail Apple Developer :
  - iPhone mus : `00008110-001C446C2E29801E`
  - Deuxième iPhone : `00008101-00113D291E84001E`

### 4. Push Notifications & Entitlements
- Création du fichier `ios/Runner/Runner.entitlements` avec `aps-environment: development`
- Ajout de `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` dans les 3 configs
- Activation des SystemCapabilities dans project.pbxproj : `com.apple.Push` + `com.apple.BackgroundModes`
- `Info.plist` déjà configuré avec `UIBackgroundModes: [remote-notification, fetch]`

### 5. Fonctionnalités alignées avec l'app Android (Kotlin)
- `kPointValue` : 15 → 2 (1 point = 2 FDJ de réduction)
- Design VTC : neon green (`#9FFF88`) remplace les gradients drapeau
- Couleurs ajoutées : `kNeonGreen`, `kNeonGreenDark`
- Véhicules VTC : Van supprimé, prix ajustés (Standard 500 FDJ, Confort 650 FDJ)
- `RideChoiceCard` : image agrandie (65px), temps d'arrivée affiché, fond vert uni
- `TaxiHomeScreen` : titre plain vert, gradient AppBar supprimé, sélecteur véhicule toujours visible
- `RideConfirmationScreen` : bouton confirmer vert uni
- `OrderTrackingScreen` : suppression bouton X et hamburger, logo Velox centré
- `TrackDeliveryScreen` : icône livreur `delivery_dining`, icône client `person_pin_circle`
- `PendingOrderScreen` : nouvel écran pré-confirmation avec countdown 60s
- `OrderDetailsScreen` : "Commander" → navigue vers PendingOrderScreen
- Suppression de tous les boutons "Voir tout" (HomeScreen + FoodHomeScreen)

### 6. Installation sur appareils physiques
- Build release installé sur iPhone mus via `devicectl`
- Build release installé sur deuxième iPhone via xcodebuild + DerivedData

---

## Ce qu'il reste à faire avant publication App Store

### OBLIGATOIRE

1. **Clé APNs pour Firebase (Push Notifications)**
   - Créer une clé APNs sur developer.apple.com → Certificates, IDs & Profiles → Keys
   - Cocher "Apple Push Notifications service (APNs)"
   - Télécharger le fichier `.p8` (une seule fois !)
   - L'uploader dans Firebase Console → Project Settings → Cloud Messaging → Apple app configuration
   - Renseigner Key ID + Team ID `7XH7YBK9H6`

2. **Changer aps-environment de development → production**
   - Dans `ios/Runner/Runner.entitlements` : `<string>development</string>` → `<string>production</string>`
   - Obligatoire pour les push en production

3. **Créer un App Store Connect Record**
   - Sur appstoreconnect.apple.com → Mes apps → +
   - Bundle ID : `dj.velox.client`
   - Nom : Velox
   - Langue principale, catégorie (Transport ou Livraison de nourriture)

4. **Icône App (1024x1024px)**
   - L'icône doit être fournie en 1024x1024px sans arrondi, sans transparence
   - À placer dans `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

5. **Captures d'écran pour l'App Store**
   - Minimum : iPhone 6.5" (iPhone 14 Pro Max) et iPhone 5.5"
   - Recommandé : iPad aussi si l'app supporte iPad
   - Faire les screenshots sur simulateur ou vrai device

6. **Build de distribution (Archive)**
   ```
   flutter build ipa
   ```
   - Crée un fichier `.ipa` signé avec un profil App Store Distribution
   - Nécessite un certificat "Apple Distribution" (différent du "Apple Development" actuel)
   - Uploader via Xcode Organizer ou `xcrun altool`

7. **Créer un certificat de distribution App Store**
   - Sur developer.apple.com → Certificates → + → "Apple Distribution"
   - Ou laisser Xcode le créer automatiquement avec `CODE_SIGN_STYLE = Automatic`

8. **Privacy Policy URL**
   - Apple exige une URL de politique de confidentialité
   - À renseigner dans App Store Connect

9. **Tester avec TestFlight avant publication**
   - Uploader le build → App Store Connect → TestFlight
   - Inviter les testeurs internes (toi + équipe)
   - Valider que tout fonctionne : auth, commandes, notifications, GPS

### RECOMMANDÉ

10. **Firebase App Check** (optionnel mais recommandé en production)
    - Protège Firestore et Cloud Functions contre les accès non autorisés
    - Provider recommandé pour iOS : DeviceCheck

11. **Crashlytics**
    - Firebase Crashlytics est déjà dans le projet
    - Vérifier qu'il remonte bien les crashes dans la Firebase Console

12. **Vérifier les règles Firestore en production**
    - S'assurer que les règles de sécurité sont correctes et ne sont pas en mode "test ouvert"

---

## Commande pour builder le IPA final (distribution)

```bash
flutter build ipa --release
```

Le fichier `.ipa` sera dans `build/ios/ipa/`
À uploader sur App Store Connect via :
```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios --apiKey <KEY> --apiIssuer <ISSUER>
```
