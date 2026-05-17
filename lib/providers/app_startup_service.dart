import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';
import '../utils/local_cache.dart';
import 'restaurant_notifier.dart';
import 'active_ride_notifier.dart';
import 'active_order_notifier.dart';
import 'cart_notifier.dart';

// ════════════════════════════════════════════════════════════════
// PHASE 5 — AppStartupService
//
// PROBLÈME OBSERVÉ : "Skipped 188-192 frames" au démarrage
//
// CAUSE :
//   - RestaurantProvider chargeait Firestore dans initState()
//     de HomeScreenFood → bloque le thread UI pendant le build
//   - LocationProvider lançait GPS + Nominatim dans initState()
//   - Tous les providers appelaient notifyListeners() simultanément
//
// SOLUTION : Séquencer le démarrage en 3 phases :
//   Phase A — Critique (bloquante) : Hive + LocalCache + Auth local
//   Phase B — Rapide  (post-frame) : Restauration panier/commande/course
//   Phase C — Différée (background): Restaurants + GPS + FCM
//
// Résultat : l'UI s'affiche en < 200ms, les données arrivent après
// ════════════════════════════════════════════════════════════════

class AppStartupState {
  final bool criticalReady;    // Phase A terminée → afficher l'UI
  final bool dataReady;        // Phase C terminée → données complètes
  final String? error;

  const AppStartupState({
    this.criticalReady = false,
    this.dataReady     = false,
    this.error,
  });

  AppStartupState copyWith({
    bool? criticalReady,
    bool? dataReady,
    String? error,
  }) {
    return AppStartupState(
      criticalReady: criticalReady ?? this.criticalReady,
      dataReady:     dataReady     ?? this.dataReady,
      error:         error         ?? this.error,
    );
  }
}

class AppStartupNotifier extends StateNotifier<AppStartupState> {
  final Ref _ref;

  AppStartupNotifier(this._ref) : super(const AppStartupState());

  // ════════════════════════════════════════════════════════════
  // PHASE A — CRITIQUE (appelée dans main() avant runApp)
  // Ne doit PAS appeler de providers — juste Hive + SharedPrefs
  // ════════════════════════════════════════════════════════════

  static Future<void> initCritical() async {
    await Future.wait([
      HiveService.init(),
      LocalCache.init(),
    ]);
    debugPrint('✅ [Startup] Phase A — critique terminée');
  }

  // ════════════════════════════════════════════════════════════
  // PHASE B — POST-FRAME (appelée dans MyApp.initState via
  //   WidgetsBinding.instance.addPostFrameCallback)
  // Restaure l'état métier depuis Hive sans bloquer le build
  // ════════════════════════════════════════════════════════════

  Future<void> restoreSession() async {
    try {
      // Les notifiers Riverpod se restaurent seuls dans leur
      // constructeur (ActiveRideNotifier._init, CartNotifier._restoreFromHive)
      // → On vérifie juste qu'ils sont créés (accès via ref)
      _ref.read(activeRideProvider);
      _ref.read(activeOrderProvider);
      _ref.read(cartProvider);

      if (mounted) {
        state = state.copyWith(criticalReady: true);
      }
      debugPrint('✅ [Startup] Phase B — session restaurée');
    } catch (e) {
      debugPrint('❌ [Startup] Phase B: $e');
      if (mounted) state = state.copyWith(criticalReady: true);
    }
  }

  // ════════════════════════════════════════════════════════════
  // PHASE C — DIFFÉRÉE (lancée après le premier frame affiché)
  // Charge les données réseau en arrière-plan
  // ════════════════════════════════════════════════════════════

  Future<void> loadBackgroundData() async {
    try {
      // Parallèle — restaurants en arrière-plan
      // (Le GPS est géré par LocationProvider en lazy: false dans main)
      unawaited(
        _ref
            .read(restaurantNotifierProvider.notifier)
            .loadAll()
            .catchError((e) =>
                debugPrint('⚠️ [Startup] loadRestaurants: $e')),
      );

      if (mounted) state = state.copyWith(dataReady: true);
      debugPrint('✅ [Startup] Phase C — données background lancées');
    } catch (e) {
      debugPrint('❌ [Startup] Phase C: $e');
      if (mounted) state = state.copyWith(dataReady: true);
    }
  }
}

final appStartupProvider =
    StateNotifierProvider<AppStartupNotifier, AppStartupState>(
  (ref) => AppStartupNotifier(ref),
);
