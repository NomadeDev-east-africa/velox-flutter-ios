# UICorrection — Récapitulatif des corrections UI (Dark Mode + Renommage Velox)

Date : 2026-04-16

---

## Objectifs

1. **Thème sombre activé par défaut** sur toute l'app
2. **Correction des textes invisibles** en mode sombre (texte noir sur fond noir)
3. **Renommage Nomade → Velox** dans l'UI uniquement (pas le code backend, pas Firestore, pas les noms de fichiers)

---

## 1. Thème sombre par défaut

### `lib/utils/local_cache.dart`
- `getDarkMode()` : valeur par défaut changée de `false` → `true`
- Les nouvelles installations démarrent en mode sombre

### `lib/providers/theme_notifier.dart`
- `ThemeState` : `isDarkMode` passe à `true` par défaut
- `ThemeNotifier()` démarre avec le thème sombre

---

## 2. TextTheme global (textes invisibles partout)

### `lib/main.dart`
- Les 6 slots du `TextTheme` (`bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall`) étaient en couleur sombre fixe
- Remplacés par des valeurs conditionnelles selon `themeState.isDarkMode`
- `hintStyle` et `labelStyle` de `InputDecorationTheme` aussi corrigés

---

## 3. Renommage Nomade → Velox (UI uniquement)

| Fichier | Texte modifié |
|---|---|
| `lib/main.dart` | `title: 'Velox'` |
| `lib/screens/homeScreen/home_screen_app.dart` | `'Nomade 253'` → `'Velox'` |
| `lib/screens/auth-firebase/phoneLogin/phone_login_screen.dart` | AppBar + WelcomeText (×3) |
| `lib/screens/auth-firebase/phoneLogin/number_verify_screen.dart` | `'Vérification Nomade 253'` → `'Vérification Velox'` |
| `lib/screens/profile/profile_screen.dart` | `'À propos de Nomade253'` → `'À propos de Velox'` |
| `lib/screens/taxi/taxi_home_screen.dart` | `Text('Nomade ') + Text('253')` → `Text('Velox')` |
| `lib/screens/onboarding/onboarding_scrreen.dart` | `'Bienvenue sur Nomade 253'` → `'Bienvenue sur Velox'` |
| `lib/screens/taxi/ride_completion_screen.dart` | `'…avec Nomade 💙'` → `'…avec Velox 💙'` |
| `lib/screens/food/food_tracking/order_completed_screen.dart` | `'…livraison Nomade253 🇩🇯'` → `'…livraison Velox 🇩🇯'` |

---

## 4. Écran order_details_screen (complètement cassé)

### `lib/screens/food/orderDetails/order_details_screen.dart`
- Palette hardcodée crème clair (`0xFFFFF5EE`, `0xFFFEEDE4`) incompatible dark mode
- Remplacé `static const Color` → `late Color` avec calcul dynamique dans `build()`
- Couleurs dynamiques selon `isDarkMode` :
  - `_bg` : `0xFF121212` / `0xFFFFF5EE`
  - `_card` : `0xFF1E1E1E` / `0xFFFEEDE4`
  - `_itemCard` : `0xFF2A2A2A` / `Colors.white`
  - `_mapBg` : `0xFF241A10` / `0xFFE8C9B0`
  - `_textPrimary` : `Colors.white` / `0xFF1A1A1A`
  - `_textSecondary` : `grey.shade400` / `grey.shade600`
  - `_disabledBg` : `0xFF424242` / `grey.shade300`
- Suppression de `const` sur tous les `BoxDecoration` utilisant ces couleurs

---

## 5. Composants partagés

| Fichier | Correction |
|---|---|
| `lib/components/section_title.dart` | `titleColor` → `colorScheme.onSurface` |
| `lib/components/cards/iteam_card.dart` | `titleColor` → `colorScheme.onSurface` |
| `lib/components/rating_with_counter.dart` | `titleColor` (×2) → `colorScheme.onSurface` |
| `lib/components/cards/medium/restaurant_info_medium_card.dart` | `titleColor` (×2) → `colorScheme.onSurface` |

---

## 6. Écrans Food

| Fichier | Correction |
|---|---|
| `lib/screens/food/home_food/home_screen_food.dart` | `'Ville de Djibouti'` `Colors.black` → adaptatif ; wildcards `__`/`___` → `_` |
| `lib/screens/food/home_food/components/promotion_banner.dart` | `titleColor` + `bodyTextColor` → adaptatifs |
| `lib/screens/food/details/components/featured_item_card.dart` | `titleColor` (×2) → `colorScheme.onSurface` |
| `lib/screens/food/food_tracking/order_completed_screen.dart` | Fond `Colors.white` → `scaffoldBackgroundColor` ; `titleColor`/`bodyTextColor` (×5) → adaptatifs ; container rating card → `colorScheme.surface` |
| `lib/screens/food/orderDetails/components/price_row.dart` | `titleColor` (×2) → `colorScheme.onSurface` ; import inutile supprimé |
| `lib/screens/food/orderDetails/components/total_price.dart` | `titleColor` (×2) → `colorScheme.onSurface` ; import inutile supprimé |
| `lib/screens/food/addToOrder/components/rounded_checkedbox_list_tile.dart` | `titleColor` → `colorScheme.onSurface` |

---

## 7. Écrans Taxi

| Fichier | Correction |
|---|---|
| `lib/screens/taxi/ride_confirmation_screen.dart` | Fond `Colors.white` → `scaffoldBackgroundColor` |
| `lib/screens/taxi/my_favorites_screen.dart` | Fond + AppBar `Colors.white` → `scaffoldBackgroundColor` / `colorScheme.surface` |
| `lib/screens/taxi/ride_details_screen.dart` | Container `Colors.white` + `titleColor` → `colorScheme.surface` / `colorScheme.onSurface` |
| `lib/screens/taxi/components/ride/trip_details_card.dart` | Container `Colors.white` + `titleColor` (×3) → adaptatifs |
| `lib/screens/taxi/components/locations/location_card.dart` | Container `Colors.white` + `titleColor` → adaptatifs |
| `lib/screens/taxi/components/locations/suggestions_cards.dart` | `titleColor` → `colorScheme.onSurface` |
| `lib/screens/taxi/components/search/search_results_list.dart` | `titleColor` → `colorScheme.onSurface` |

---

## 8. Auth

| Fichier | Correction |
|---|---|
| `lib/screens/auth-firebase/phoneLogin/phone_login_screen.dart` | Input text `titleColor` → `colorScheme.onSurface` |
| `lib/screens/auth-firebase/auth/components/sign_in_form.dart` | Icônes visibilité `bodyTextColor` → `colorScheme.onSurface` |
| `lib/screens/auth-firebase/auth/sign_in_screen.dart` | `kOrText` → `const KOrText()` |
| `lib/screens/auth-firebase/auth/sign_up_screen.dart` | `kOrText` → `const KOrText()` |
| `lib/screens/auth-firebase/signUp/components/sign_up_form.dart` | Icônes visibilité `bodyTextColor` → `colorScheme.onSurface` |
| `lib/screens/signUp/components/sign_up_form.dart` | Icônes visibilité `bodyTextColor` (×2) → `colorScheme.onSurface` |
| `lib/screens/signUp/components/body.dart` | `kOrText` → `const KOrText()` |

---

## 9. Profil & Autres

| Fichier | Correction |
|---|---|
| `lib/screens/profile/components/body.dart` | Icône SVG `titleColor` + sous-titre `titleColor` → `colorScheme.onSurface` |
| `lib/screens/language/language_selection_screen.dart` | Fond container `Colors.white` → `colorScheme.surface` ; `titleColor`/`bodyTextColor` → adaptatifs |
| `lib/screens/onboarding/onboarding_scrreen.dart` | Fond `Colors.white` → `scaffoldBackgroundColor` |
| `lib/screens/profile/adresses/add_address_screen.dart` | Fond loading state `Colors.white` → `scaffoldBackgroundColor` |

---

## 10. Global — `lib/constants.dart`

- `kOrText` (widget global pré-construit) refactorisé en classe `KOrText extends StatelessWidget`
- Peut désormais utiliser `Theme.of(context)` pour adapter la couleur au thème

---

## 11. Nettoyage détecté par l'analyseur

| Fichier | Problème | Fix |
|---|---|---|
| `lib/main.dart` | Import `active_order_notifier.dart` inutile | Supprimé |
| `lib/screens/homeScreen/home_screen_app.dart` | Méthode `_logout()` déclarée mais jamais appelée | Supprimée |
| `lib/screens/food/home_food/home_screen_food.dart` | Wildcards `__`/`___` non valides | Remplacés par `_` |
| `lib/screens/food/orderDetails/components/price_row.dart` | Import `constants.dart` inutile | Supprimé |
| `lib/screens/food/orderDetails/components/total_price.dart` | Import `constants.dart` inutile | Supprimé |

---

## Résultat final

```
dart analyze → No errors
```

Toutes les corrections sont purement UI/front-end.
Aucun fichier backend, Firestore, ni logique métier n'a été modifié.
