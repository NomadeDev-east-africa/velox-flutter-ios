# Android — Signature & publication Play Store

App : **Nomade Client** · `applicationId` = **`dj.velox.client`** · Projet Firebase : `nomade253-478a9`

> ✅ **La signature est DÉJÀ configurée** — rien à mettre en place. Ce mémo sert à
> comprendre l'existant, **sécuriser le keystore**, et publier proprement.

---

## 1. État actuel (déjà en place)
- **Keystore** : `android/nomade-release.keystore` (alias `nomade`)
- **`android/key.properties`** : contient `storeFile`, `keyAlias`, `storePassword`, `keyPassword`
- **`build.gradle.kts`** : lit `key.properties` → `signingConfigs["release"]` appliqué au `buildTypes.release`
- **Optimisations release** : `isMinifyEnabled`, `isShrinkResources`, ProGuard activés ✅
- **Gitignore** : `key.properties`, `*.keystore`, `*.jks` sont ignorés → **ne sont PAS dans le dépôt** ✅

---

## 2. 🔴 CRITIQUE — Sauvegarder le keystore (sinon app condamnée)
Le keystore et `key.properties` **ne sont pas dans Git** (volontairement). S'ils sont perdus,
**tu ne pourras plus JAMAIS mettre à jour l'app** sur le Play Store (Google refuse toute
nouvelle version non signée par la même clé). Il faudrait republier une app neuve.

- [ ] Copier `android/nomade-release.keystore` **hors du projet** (gestionnaire de mots de passe,
      coffre chiffré, cloud privé)
- [ ] Noter en lieu sûr : **mot de passe du store, mot de passe de la clé, alias (`nomade`)**
- [ ] Garder au moins **2 sauvegardes** à des endroits différents

---

## 3. Numéro de version (avant chaque publication)
`versionCode` / `versionName` viennent de **`pubspec.yaml`** (champ `version:`), via
`flutter.versionCode` / `flutter.versionName`.

```yaml
# pubspec.yaml
version: 1.0.0+1     #  <nom_version> + <code_version>
#         ^^^^^   ^
#         nom     code (entier, DOIT augmenter à chaque upload)
```
- À chaque envoi au Play Store : **incrémenter le `+N`** (ex. `1.0.0+2`, puis `1.0.1+3`…)
- Google **refuse** un AAB avec un `versionCode` déjà utilisé.

---

## 4. Construire l'AAB signé (format Play Store)
> Le Play Store veut un **App Bundle (.aab)**, pas un APK.

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
Sortie : `build/app/outputs/bundle/release/app-release.aab`

Vérifier que c'est bien signé en release (pas debug) :
```bash
# le build échoue si key.properties/keystore manquent → preuve que la signature release est active
```

Pour un APK de test signé (installation directe, hors store) :
```bash
flutter build apk --release
```

---

## 5. Play Console — première publication
1. https://play.google.com/console → **Créer une application**
2. **Play App Signing** : laisser Google gérer la clé d'app (recommandé). Ta clé `nomade-release`
   devient la **clé d'upload** → tu signes tes AAB avec, Google re-signe pour la distribution.
3. **Configurer la fiche** : nom, description, icône, captures, catégorie, coordonnées
4. **Politique de confidentialité** (URL obligatoire) + **questionnaire contenu/data safety**
5. **Importer l'AAB** dans un canal (Test interne → Test fermé → Production)

---

## 6. ⚠️ Permissions sensibles à déclarer (spécifique à cette app)
Le `AndroidManifest` demande des permissions qui déclenchent une **déclaration obligatoire**
dans le Play Console (sinon rejet) :

| Permission | Exigence Play Console |
|---|---|
| `ACCESS_BACKGROUND_LOCATION` | **Déclaration + justification (souvent vidéo de démo)** prouvant l'usage en arrière-plan (suivi livraison). La plus stricte. |
| `CALL_PHONE` | Déclaration d'usage (appel livreur/restaurant) |
| `POST_NOTIFICATIONS` | OK, pas de déclaration spéciale |

> Prépare une **vidéo/écran de démo** montrant pourquoi la localisation en arrière-plan est
> nécessaire — c'est le motif de rejet n°1 pour ce type d'app.

---

## 7. Cibles SDK (vérifier la conformité Play)
- `targetSdk` = `flutter.targetSdkVersion` (géré par Flutter). Google impose un targetSdk récent
  pour les nouvelles soumissions — vérifier qu'il correspond à l'exigence en vigueur le jour de
  la publication (sinon upload refusé).
- `minSdk` = `flutter.minSdkVersion`.

---

## 8. Checklist avant envoi
- [ ] Keystore **sauvegardé hors projet** (point #2)
- [ ] `version:` du `pubspec.yaml` incrémentée
- [ ] `flutter build appbundle --release` OK (signé release)
- [ ] `google-services.json` contient bien l'app `dj.velox.client` ✅ (déjà le cas)
- [ ] Déclarations permissions sensibles prêtes (background location !)
- [ ] Fiche + politique de confidentialité + data safety remplies
- [ ] AAB importé dans un canal de test d'abord, puis Production

---

### Rappels de cohérence
- `applicationId` = `namespace` = **`dj.velox.client`** (aligné avec iOS) ✅
- App Firebase Android `dj.velox.client` déjà enregistrée (appId `…android:be262e5c…`)
- Ne jamais committer `key.properties` ni le `.keystore` (déjà gitignorés)
