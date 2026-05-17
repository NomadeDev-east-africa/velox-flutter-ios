# Résumé de session — 21 Avril 2026
**Projet :** nomade_client (Flutter / Firebase / Riverpod)
**Design system :** Kinetic Monolith (dark)

---

## 1. Redesign UI — Pages redesignées

### HomeFood `lib/screens/food/home_food/home_screen_food.dart`
- Fond sombre `#0E0E0E`, AppBar dark avec localisation centrée
- Bouton "Filtrer" vert néon `#9FFF88`
- Catégories horizontales : cartes 88×110px, fond `_surface`, gradient overlay
- Section "Meilleurs choix" : cartes 200px horizontales avec image + badge rating
- Section "Tous les restaurants" : widget `_DarkRestaurantCard` (image 16:9, rating badge, chips infos)

### Profil `lib/screens/profile/profile_screen.dart`
- Header : gradient `#0E0E0E → #1A1919` (remplace bleu/vert)
- Avatar : bordure vert néon 3px, bouton caméra vert néon
- Toutes les couleurs bleues `#6AB2E7` → vert primaire `#9FFF88`

### HomeScreen `lib/screens/homeScreen/home_screen_app.dart`
- Logo agrandi : 64px → 90px
- Greeting "Bonjour X" : Poppins Bold
- Tagline : Inter Italic

### Onboarding `lib/screens/onboarding/`
- Illustrations remplacées : `velox1.svg`, `velox2.svg`, `velox3.svg`
- Fond : `#0E0E0E`
- Titres : blanc (était noir — illisible)
- Descriptions : gris `#ADAAAA`
- Bouton "COMMENCER" : vert néon + texte vert foncé
- Dots animés : inactif gris, actif vert allongé

---

## 2. Système de polices

### Package ajouté
```yaml
google_fonts: ^6.2.1   # dans pubspec.yaml → dependencies
```

### Règle typographique
| Rôle | Police | Poids |
|---|---|---|
| Titres, sections, boutons | **Poppins** | Bold (700) / SemiBold (600) / Medium (500) |
| Corps, descriptions, labels | **Inter** | Regular (400) / Medium (500) |

### Fichier centralisé
`lib/theme/app_typography.dart` — à utiliser dans tous les nouveaux widgets :
```dart
import 'package:nomade_client/theme/app_typography.dart';

Text('Titre', style: AppTypography.h2())
Text('Description', style: AppTypography.body(color: _onSurfaceVariant))
Text('BOUTON', style: AppTypography.button())
Text('label', style: AppTypography.label())
```

### Application dans le thème global (`main.dart`)
- `textTheme` : Poppins pour display/headline/title, Inter pour body/label
- `appBarTheme.titleTextStyle` : Poppins SemiBold
- `elevatedButtonTheme.textStyle` : Poppins SemiBold 15

---

## 3. Icône de l'application

Config ajoutée dans `pubspec.yaml` :
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo.png"
  adaptive_icon_background: "#0E0E0E"
  adaptive_icon_foreground: "assets/images/logo.png"
```

**Commandes à exécuter (une seule fois) :**
```bash
flutter pub get
dart run flutter_launcher_icons
```
Puis rebuild complet (pas hot reload).

---

## 4. Couleurs du design system (Kinetic Monolith)

```dart
const _bg               = Color(0xFF0E0E0E);  // fond principal
const _surfaceLow       = Color(0xFF131313);  // fond secondaire
const _surface          = Color(0xFF1A1919);  // cartes
const _surfaceHigh      = Color(0xFF20201F);  // cartes élevées
const _primary          = Color(0xFF9FFF88);  // vert néon (accent)
const _onPrimary        = Color(0xFF026400);  // texte sur vert
const _onSurface        = Color(0xFFFFFFFF);  // texte principal
const _onSurfaceVariant = Color(0xFFADAAAA);  // texte secondaire
const _outlineVariant   = Color(0xFF484847);  // bordures
```

---

## 5. Pages restantes à redesigner

- `sign_in_screen.dart` / `sign_up_screen.dart`
- `details_screen.dart` (page restaurant)
- `order_tracking_screen.dart`
- `order_completed_screen.dart`
- `taxi_home_screen.dart`
- Écrans secondaires (filter, search, add_to_order…)
