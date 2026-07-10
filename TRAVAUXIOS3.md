# Travaux iOS — Velox (session 3 : rejet App Review + corrections)

> Suite de `TRAVAUXIOS2.md` et `travauxIOSfinal.md`. Cette session couvre : le debug des
> notifications push TestFlight (bug réel trouvé après plusieurs fausses pistes), la
> première soumission App Store, le rejet Apple, et les 3 corrections qui ont suivi.

---

## 1. Notifications push TestFlight — enfin résolu ✅

**Symptôme** : les notifications marchaient parfaitement en local (build signé Apple
Development, sandbox) mais jamais sur un vrai build TestFlight (Apple Distribution),
sur 5 builds successifs (1.0.3+2 à +5), malgré signature/entitlements/profil de
provisionnement strictement identiques et vérifiés à chaque fois.

**Fausses pistes explorées (et écartées avec preuves)** :
- Re-signer/rebuild plusieurs fois → aucun changement, la signature était déjà correcte
- `DEVELOPMENT_TEAM` absent du projet Xcode → corrigé (bonne pratique), mais sans effet
  sur le bug
- Théorie fausse : TestFlight utiliserait l'environnement sandbox APNs tant que l'app
  n'est pas publiée. **Faux** — confirmé par un ingénieur Apple sur les forums
  développeurs : TestFlight est **toujours** en environnement production. Un correctif
  basé sur cette fausse théorie (forcer `.sandbox` via détection `sandboxReceipt`) a
  été écrit puis **entièrement retiré** après vérification.

**Cause réelle** : dans Firebase Console → Cloud Messaging → Apple app configuration
(app **VELOX CLIENT**), seule la clé **"Development APNs auth key"** était configurée —
le champ **"Production APNs auth key" était vide**. Fix : ré-upload de la même clé
`.p8` (Key ID `Q5KC4J92NR`, Team ID `7XH7YBK9H6`) dans le champ Production. Aucun
changement de code nécessaire au final.

Confirmé fonctionnel sur build **1.0.3+6** (VTC, resto, test manuel Firebase).

---

## 2. Première soumission App Store ✅ (puis rejet, voir section 3)

- Repo GitHub séparé créé : `NomadeDev-east-africa/velox-flutter-ios` (public), en plus
  du repo existant `Velox_Client`
- Vérification des métadonnées App Store Connect via l'API (JWT signé avec la clé
  App Store Connect existante, `8PN6V7YQBT`) : nom, sous-titre, description,
  catégories (Voyage + Cuisine et boissons), classification d'âge, contact review,
  10 captures iPhone 6.5″ — tout confirmé complet
- Soumis à la review Apple le **2026-07-07**

---

## 3. Rejet Apple (2026-07-09) — 3 problèmes, tous corrigés

Reçu le 2026-07-09, review effectuée sur **iPad Air 11-inch (M3)**, version 1.0.3 (6).

### 3.1 — Guideline 2.3.3 (métadonnées) : captures iPad = splash uniquement

Le screenshot iPad 13″ généré rapidement pour débloquer la première soumission ne
montrait que l'écran de bienvenue Velox — pas l'app en fonctionnement.

**Fix** : 5 nouvelles captures prises par l'utilisateur sur simulateur iPad Pro 13″
(M4), montrant du vrai contenu : accueil (VTC/Restaurants), liste restaurants, détail
plat, commande en cours, livraison + notation. Uploadées via l'API App Store Connect
(création d'`appScreenshots`, upload par chunks, commit avec checksum MD5), ancienne
capture supprimée.

### 3.2 — Guideline 4.8 (login tiers) : Sign in with Apple manquant

L'app proposait Google Sign-In sans alternative respectueuse de la vie privée exigée
par Apple dès qu'un login tiers est présent.

**Fix** :
- Package `sign_in_with_apple` ajouté
- `AuthService.signInWithApple()` (`lib/services/auth_service.dart`) : génération
  nonce + SHA-256, `SignInWithApple.getAppleIDCredential`, échange du credential
  Firebase via `OAuthProvider('apple.com')`, réutilisation de
  `_createOrUpdateUserDocument` (même logique que Google)
- Bouton "Connect with Apple" ajouté sur `sign_in_screen.dart`
- Entitlement `com.apple.developer.applesignin` ajouté à `Runner.entitlements` +
  capability Xcode (`SystemCapabilities` dans `project.pbxproj`)
- Capability activée manuellement sur developer.apple.com (App ID `dj.velox.client`)
- Provider "Apple" activé dans Firebase Console → Authentication → Sign-in method

**Bug rencontré et corrigé** : après toute la config ci-dessus, erreur persistante
`firebase_auth/invalid-credential — Invalid OAuth response from apple.com`. Cause
réelle : il manquait `accessToken: appleCredential.authorizationCode` dans
`OAuthProvider('apple.com').credential(...)` — Firebase exige ce paramètre en plus de
`idToken`/`rawNonce`, sinon il rejette la connexion même si tout le reste (entitlement,
capability, provider, nonce) est correct. Testé fonctionnel après ce fix, sur
iPhone mus puis sur un vrai build TestFlight.

### 3.3 — Guideline 5.1.1(v) (vie privée) : connexion forcée avant navigation

L'app forçait la création de compte avant même de pouvoir consulter les restaurants ou
les options VTC.

**Fix** :
- `onboarding_screen.dart` : bouton **"Continuer sans compte"** ajouté à côté de
  "DÉMARRER", mène directement à `HomeScreenApp` (mode invité)
- `home_screen_app.dart` : suppression du bloc plein écran "connexion requise" ;
  accueil accessible sans compte ; carte points fidélité remplacée par une invite de
  connexion pour les invités ; action rapide "Historique" redirige vers la connexion
  pour les invités
- Connexion exigée **uniquement** aux deux points d'action réels :
  `order_details_screen.dart:_processOrder()` et
  `ride_confirmation_screen.dart:_confirmRide()` — redirigent maintenant vers
  `SignInScreen` au lieu de bloquer silencieusement (`return` sans rien afficher)

**Bug découvert en testant** : une fois le mode invité en place, les restaurants
n'apparaissaient plus ("aucun restaurant disponible") — en réalité un refus silencieux
de Firestore, pas une vraie liste vide. Cause : `firestore.rules` exigeait `isAuth()`
pour lire `restaurants`, `menu_items`, `promotions`, et les sous-collections
`menu`/`avis`/`reviews`. Corrigé (lecture publique sur ces collections de catalogue
uniquement, écriture inchangée) — déployé via l'agent Claude tournant sur la machine
Windows (`C:\Users\PC\StudioProjects\nomade_client`), qui héberge la copie de
`firestore.rules` réellement utilisée en déploiement.

---

## 4. Build final et re-soumission

- Version passée à **1.0.4+1**
- `flutter analyze` propre, `flutter test` → 24/24 tests métier (seul échec :
  test template Flutter par défaut, préexistant, sans rapport avec l'app)
- Build IPA vérifié : signature Apple Distribution, `aps-environment: production`,
  `com.apple.developer.applesignin` présent dans les entitlements **et** dans le
  profil de provisionnement Apple embarqué (double vérification comme pour les push)
- Uploadé sur TestFlight, **testé sur le vrai build TestFlight** (pas seulement en
  local) : mode invité + Sign in with Apple + navigation restaurants, tout fonctionnel

## À faire

1. Répondre au message du Resolution Center dans App Store Connect en résumant les
   3 corrections
2. Recliquer sur "Ajouter pour vérification" pour resoumettre à la review Apple

## Rappel technique

- Build iOS = macOS/Xcode uniquement (ce Mac)
- `firestore.rules` sur ce Mac peut être une copie non déployée — vérifier avec
  l'utilisateur avant de modifier les règles Firestore depuis ici
- Deux repos GitHub existent : `Velox_Client` (origin) et `velox-flutter-ios` (ajouté
  cette session, remote `ios-repo`)
