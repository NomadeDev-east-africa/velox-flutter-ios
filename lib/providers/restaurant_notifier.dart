import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';

// ════════════════════════════════════════════════════════════════
// PHASE 5 — RestaurantNotifier
// Remplacement du RestaurantProvider (ChangeNotifier) qui
// appelait notifyListeners() 3 fois de suite dans initState.
//
// OPTIMISATIONS APPLIQUÉES :
//   1. loadAll() — un seul state update après Future.wait([...])
//      au lieu de 3 notifyListeners() séquentiels
//   2. select() dans les screens pour reconstruire uniquement
//      le sous-widget concerné (restaurants, featured, popular)
//   3. Données préchargées silencieusement → écran instanta­né
// ════════════════════════════════════════════════════════════════

class RestaurantState {
  final List<Restaurant> restaurants;
  final List<Restaurant> featured;
  final List<Restaurant> popular;
  final Restaurant?      selected;
  final bool             isLoading;
  final String?          error;

  const RestaurantState({
    this.restaurants = const [],
    this.featured    = const [],
    this.popular     = const [],
    this.selected,
    this.isLoading   = false,
    this.error,
  });

  RestaurantState copyWith({
    List<Restaurant>? restaurants,
    List<Restaurant>? featured,
    List<Restaurant>? popular,
    Restaurant?       selected,
    bool?             isLoading,
    String?           error,
    bool              clearError    = false,
    bool              clearSelected = false,
  }) {
    return RestaurantState(
      restaurants: restaurants ?? this.restaurants,
      featured:    featured    ?? this.featured,
      popular:     popular     ?? this.popular,
      selected:    clearSelected ? null : (selected ?? this.selected),
      isLoading:   isLoading   ?? this.isLoading,
      error:       clearError  ? null : (error ?? this.error),
    );
  }
}

class RestaurantNotifier extends StateNotifier<RestaurantState> {
  final RestaurantService _service;

  RestaurantNotifier(this._service) : super(const RestaurantState());

  // ─── Chargement groupé — UN SEUL setState ───────────────────
  //
  // AVANT (RestaurantProvider) :
  //   await loadRestaurants();     // notifyListeners() x2
  //   await loadFeatured();        // notifyListeners() x1
  //   await loadPopular();         // notifyListeners() x1
  //   → 4 reconstructions du widget tree
  //
  // APRÈS :
  //   await loadAll();
  //   → 2 reconstructions : début + fin
  Future<void> loadAll({int featuredLimit = 4, int popularLimit = 4}) async {
    if (!mounted) return;

    // ✅ Un seul setState pour marquer le début du chargement
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // ✅ Future.wait → parallèle, une seule attente réseau
      final results = await Future.wait([
        _service.getRestaurants(),
        _service.getTopRatedRestaurants(limit: featuredLimit),
        _service.getPopularRestaurants(limit: popularLimit),
      ]);

      if (!mounted) return;

      // ✅ Un seul setState pour tout le résultat
      state = state.copyWith(
        restaurants: results[0],
        featured:    results[1],
        popular:     results[2],
        isLoading:   false,
        clearError:  true,
      );

      debugPrint(
          '✅ [RestaurantNotifier] Chargé: ${results[0].length} restos, '
          '${results[1].length} featured, ${results[2].length} popular');
    } catch (e) {
      debugPrint('❌ [RestaurantNotifier] loadAll: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error:     'Erreur chargement restaurants',
        );
      }
    }
  }

  Future<void> selectRestaurant(String restaurantId) async {
    try {
      final r = await _service.getRestaurantById(restaurantId);
      if (mounted && r != null) {
        state = state.copyWith(selected: r);
      }
    } catch (e) {
      debugPrint('❌ [RestaurantNotifier] selectRestaurant: $e');
    }
  }

  void clearSelection() {
    if (mounted) state = state.copyWith(clearSelected: true);
  }
}

// ════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════

final restaurantNotifierProvider =
    StateNotifierProvider<RestaurantNotifier, RestaurantState>(
  (ref) => RestaurantNotifier(RestaurantService()),
);

// ── Providers sélecteurs — reconstruisent UNIQUEMENT le widget concerné ──

/// Juste la liste principale — HomeScreen food list
final allRestaurantsProvider = Provider<List<Restaurant>>(
  (ref) => ref.watch(restaurantNotifierProvider).restaurants,
);

/// Juste les featured — BigCardImageSlide
final featuredRestaurantsProvider = Provider<List<Restaurant>>(
  (ref) => ref.watch(restaurantNotifierProvider).featured,
);

/// Juste les popular — MediumCardList
final popularRestaurantsProvider = Provider<List<Restaurant>>(
  (ref) => ref.watch(restaurantNotifierProvider).popular,
);

/// Juste le flag loading — spinner
final restaurantsLoadingProvider = Provider<bool>(
  (ref) => ref.watch(restaurantNotifierProvider).isLoading,
);
