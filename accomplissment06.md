# Accomplissements — Session 06 — 26 avril 2026

## Contexte
App Flutter food delivery client — package `dj.velox.client` — projet Nomade253

---

## 1. Correction erreur fonts GoogleFonts
**Problème :** `GoogleFonts.config.allowRuntimeFetching is false but font Poppins-Bold was not found`
**Cause :** La ligne `GoogleFonts.config.allowRuntimeFetching = false` avait été ajoutée dans `main.dart` lors d'une session précédente, mais les fonts Poppins/Inter ne sont pas bundlées dans les assets du projet.
**Correction :** Ligne supprimée de `lib/main.dart`. Les fonts sont téléchargées à la volée par le package `google_fonts` (comportement par défaut).
**Statut :** ✅ Résolu — aucune erreur font dans le nouveau build (PID 25942+)

---

## 2. Enregistrement des fingerprints SHA dans Firebase Console
**Problème :** `INVALID_CERT_HASH 400` + `Failed to get reCAPTCHA token: There was an error while trying to get your package certificate hash.`
**Cause :** Seuls les fingerprints du keystore release avaient été ajoutés dans Firebase Console pour `dj.velox.client`. Le keystore debug (utilisé par `flutter run`) n'était pas enregistré.

**Fingerprints ajoutés dans Firebase Console → Project Settings → dj.velox.client :**

| Keystore | Type   | Valeur |
|----------|--------|--------|
| Debug    | SHA-1  | `AD:23:00:72:2E:62:50:1F:29:5E:13:D0:BF:30:8A:11:69:ED:82:CB` |
| Debug    | SHA-256 | `E6:C6:4B:9D:FF:5D:46:33:9E:3A:2F:37:AD:40:F7:A9:A1:94:4C:00:12:29:8E:BA:7A:FF:4C:51:21:47:10:DF` |
| Release  | SHA-1  | `38:AB:ED:C0:97:46:60:2E:4F:BF:49:DC:00:E5:01:DA:E3:66:37:1D` |
| Release  | SHA-256 | `59:77:E5:C9:F5:9C:90:8C:E4:46:A6:27:1A:91:A8:94:18:1E:8E:49:18:10:90:8B:01:A5:34:9C:43:6E:64:41` |

**Commandes keytool utilisées :**
```bash
# Debug
keytool -list -v -keystore C:/Users/PC/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release
keytool -list -v -keystore android/nomade-release.keystore -alias nomade -storepass Velox2025
```

**Statut :** ✅ Résolu

---

## 3. Enregistrement du token App Check debug
**Problème :** `Error getting App Check token; code: 403 body: App attestation failed.`
**Token debug à enregistrer :** `7d765793-a032-4623-ba09-b88f6baa2e41`
**Action :** Ajouté dans Firebase Console → App Check → dj.velox.client → Manage debug tokens
**Statut :** ✅ Résolu

---

## 4. OTP Phone Auth — opérationnel
**Problème initial :** Erreur 17006 `This operation is not allowed` puis 18002 `Invalid PlayIntegrity token` puis `INVALID_CERT_HASH 400`
**Résolution :** Les 4 fingerprints SHA enregistrés (point 2 ci-dessus) ont débloqué le flow reCAPTCHA de Firebase Auth.

**Confirmation dans le log :**
```
✅ [AuthService] OTP vérifié: HXMyT0SqE7OxJhCbxquyBbtYX5I2
```
**Statut :** ✅ Fonctionnel

---

## 5. Google Sign-In — opérationnel
**Confirmation dans le log :**
```
✅ [AuthService] Google Sign In: y52P28OG6Wa4gdhxVIn6gxZ0vwx1
```
**Statut :** ✅ Fonctionnel

---

## 6. Token FCM post-connexion — opérationnel
Après chaque connexion (OTP ou Google), le token FCM est correctement sauvegardé dans Firestore pour l'utilisateur connecté.
```
✅ [NotificationService] Token FCM sauvegardé pour HXMyT0SqE7OxJhCbxquyBbtYX5I2
✅ [NotificationService] Initialisé avec succès
```
**Statut :** ✅ Fonctionnel

---

## Récapitulatif de la configuration Firebase Console pour `dj.velox.client`

| Élément | Valeur | Statut |
|---------|--------|--------|
| Package Android | `dj.velox.client` | ✅ |
| App nickname | Velox Client | ✅ |
| SHA-1 debug | `AD:23:00:72...` | ✅ |
| SHA-256 debug | `E6:C6:4B:9D...` | ✅ |
| SHA-1 release | `38:AB:ED:C0...` | ✅ |
| SHA-256 release | `59:77:E5:C9...` | ✅ |
| Phone Auth activé | Oui | ✅ |
| App Check debug token | `7d765793-a032-4623-ba09-b88f6baa2e41` | ✅ |
| google-services.json | Téléchargé et replacé | ✅ |

---

## État final de l'app à la fin de la session

| Fonctionnalité | Statut |
|----------------|--------|
| Build release signé (nomade-release.keystore) | ✅ |
| Package renommé `dj.velox.client` | ✅ |
| Firebase Analytics intégré | ✅ |
| Firebase App Check configuré (debug + production) | ✅ |
| Fonts Poppins / Inter (runtime fetching) | ✅ |
| Google Sign-In | ✅ |
| OTP Phone Auth (+253 Djibouti) | ✅ |
| Token FCM sauvegardé après connexion | ✅ |
| UI Sign-Up redesignée (drapeau 🇩🇯 +253 pré-rempli) | ✅ |
| UI Phone Login (formatage auto XX XX XX XX) | ✅ |
| UI Number Verify (masquage numéro, renvoyer) | ✅ |
| Clé API OpenRouteService sécurisée dans secrets.dart | ✅ |
| .gitignore (secrets.dart, key.properties, keystore) | ✅ |
