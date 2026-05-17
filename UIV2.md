# UIV2 — Refonte Design Kinetic Monolith
*Session du 21 avril 2026*

---

## Système de design appliqué

Toutes les pages redesignées utilisent la palette **Kinetic Monolith** :

| Constante | Couleur | Rôle |
|---|---|---|
| `_bg` | `#0E0E0E` | Fond principal |
| `_surface` | `#1A1919` | Fond des cartes |
| `_surfaceHigh` | `#20201F` | Fond elevated |
| `_primary` | `#9FFF88` | Accent vert néon |
| `_onPrimary` | `#026400` | Texte sur boutons verts |
| `_onSurface` | `#FFFFFF` | Texte principal |
| `_onSurfaceVariant` | `#ADAAAA` | Texte secondaire / gris |
| `_outlineVariant` | `#484847` | Bordures subtiles |

---

## Pages redesignées

### 1. HomeFood — `lib/screens/food/home_food/home_screen_food.dart`
- Fond sombre `_bg`, AppBar dark avec localisation centrée
- Bouton "Filtrer" en vert néon
- Catégories : cartes 88×110px avec fond `_surface`, gradient overlay sombre
- Section "Meilleurs choix" : cartes horizontales 200px avec image + badge rating vert
- Section "Tous les restaurants" : nouveau widget `_DarkRestaurantCard`
  - Image 16:9, badge rating vert néon, chips infos (temps, livraison, commandes)

### 2. Profil — `lib/screens/profile/profile_screen.dart`
- Header : gradient `#0E0E0E → #1A1919` (remplace bleu/vert)
- Avatar : bordure verte néon `#9FFF88` (3px)
- Bouton caméra : fond vert néon, icône vert foncé
- Toutes les couleurs bleues `#6AB2E7` → vert `#9FFF88`
- Toggles : `activeThumbColor` → `#9FFF88`

### 3. HomeScreen principal — `lib/screens/homeScreen/home_screen_app.dart`
- Logo agrandi : `height: 64` → `height: 90`

### 4. Onboarding — `lib/screens/onboarding/onboarding_scrreen.dart` + `components/onboard_content.dart`
- Illustrations remplacées :
  - `nomade253.svg` → `velox1.svg`
  - `nomadeScooter.svg` → `velox2.svg`
  - `nomadeDriver.svg` → `velox3.svg`
- Fond : `_bg` (`#0E0E0E`)
- Titre : blanc `#FFFFFF` (était `Colors.black87` — illisible)
- Description : gris `#ADAAAA` (était `Colors.black54` — illisible)
- Bouton "COMMENCER" : vert néon + texte vert foncé
- Dots de pagination : animés, actif = vert néon allongé, inactif = gris

---

## Icône de l'application

Config ajoutée dans `pubspec.yaml` :
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo.png"
  min_sdk_android: 21
  adaptive_icon_background: "#0E0E0E"
  adaptive_icon_foreground: "assets/images/logo.png"
```

**Pour appliquer l'icône, exécuter :**
```bash
flutter pub get
dart run flutter_launcher_icons
```
Puis rebuild complet (pas hot reload).

---

## Pages restantes à redesigner

- `sign_in_screen.dart` / `sign_up_screen.dart`
- `details_screen.dart` (page restaurant)
- `order_tracking_screen.dart`
- `order_completed_screen.dart`
- `taxi_home_screen.dart`
- Autres écrans secondaires
