import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ride.dart';
import '../services/ride_service.dart';
import '../services/driver_notification_service.dart';
import '../services/hive_service.dart';
import '../utils/retry_helper.dart';

// ════════════════════════════════════════════════════════════════
// ÉTAT
// ════════════════════════════════════════════════════════════════

class ActiveRideState {
  final Ride? ride;
  final bool isLoading;
  final bool isCreating;
  final bool isWatching;
  final String? error;

  const ActiveRideState({
    this.ride,
    this.isLoading = false,
    this.isCreating = false,
    this.isWatching = false,
    this.error,
  });

  // ─── Getters métier ──────────────────────────────────────────

  bool get hasActiveRide => ride != null && ride!.isActive;
  bool get isWaitingForDriver =>
      ride?.status == RideStatus.requested;
  bool get hasDriver => ride?.driverId != null;
  bool get isCompleted => ride?.status == RideStatus.completed;
  bool get isCancelled => ride?.status == RideStatus.cancelled;
  bool get isTerminated =>
      ride == null ||
      ride!.status == RideStatus.completed ||
      ride!.status == RideStatus.cancelled ||
      ride!.status == RideStatus.noDriverAvailable;

  String? get rideId => ride?.rideId;

  ActiveRideState copyWith({
    Ride? ride,
    bool? isLoading,
    bool? isCreating,
    bool? isWatching,
    String? error,
    bool clearRide = false,
    bool clearError = false,
  }) {
    return ActiveRideState(
      ride:       clearRide  ? null  : (ride      ?? this.ride),
      isLoading:  isLoading  ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isWatching: isWatching ?? this.isWatching,
      error:      clearError ? null  : (error     ?? this.error),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NOTIFIER
// ════════════════════════════════════════════════════════════════

class ActiveRideNotifier extends StateNotifier<ActiveRideState> {
  final RideService              _rideService;
  final DriverNotificationService _notifService;

  StreamSubscription<Ride>? _sub;
  Timer?                    _reconnectTimer;
  bool                      _isPaused = false;

  ActiveRideNotifier(this._rideService, this._notifService)
      : super(const ActiveRideState()) {
    _init();
  }

  // ════════════════════════════════════════════════════════════
  // INIT — cycle de démarrage
  // ════════════════════════════════════════════════════════════

  /// Séquence :
  ///   1. Lire le cache Hive → affichage immédiat
  ///   2. One-time Firestore  → données fraîches + vérif statut
  ///   3. Démarrer le stream  → mises à jour temps réel
  Future<void> _init() async {
    if (!mounted) return;

    state = state.copyWith(isLoading: true);

    // ── Étape 1 : cache Hive ─────────────────────────────────
    final cachedJson = HiveService.getRideJson();
    if (cachedJson != null) {
      try {
        final ride = Ride.fromJson(
            Map<String, dynamic>.from(jsonDecode(cachedJson) as Map));
        if (!ride.isActive) {
          // Course terminée en cache → nettoyer sans démarrer de stream
          await HiveService.clearRide();
          if (mounted) state = state.copyWith(isLoading: false, clearRide: true);
          return;
        }
        if (mounted) {
          state = state.copyWith(ride: ride, isLoading: false);
        }
        debugPrint('📦 [ActiveRide] Cache Hive restauré: ${ride.rideId}');
      } catch (e) {
        debugPrint('⚠️ [ActiveRide] Cache corrompu, effacement: $e');
        await HiveService.clearRide();
      }
    }

    // ── Étape 2 : vérifier si un rideId connu en Hive ────────
    final rideId = HiveService.getRideId();
    if (rideId == null) {
      if (mounted) state = state.copyWith(isLoading: false);
      return;
    }

    // ── Étape 3 : one-time Firestore ─────────────────────────
    try {
      final ride = await _rideService.getRideById(rideId);

      if (!mounted) return;

      if (ride == null) {
        // Document supprimé de Firestore → nettoyer Hive
        debugPrint('⚠️ [ActiveRide] Course $rideId introuvable, nettoyage');
        await _clearAndReset();
        return;
      }

      if (!ride.isActive) {
        // Course déjà terminée côté serveur → nettoyer
        debugPrint('ℹ️ [ActiveRide] Course $rideId terminée (${ride.status.name})');
        await _clearAndReset();
        return;
      }

      state = state.copyWith(ride: ride, isLoading: false, clearError: true);
      await _persistToHive(ride);
      debugPrint('✅ [ActiveRide] One-time Firestore OK: ${ride.rideId}');
    } catch (e) {
      // Réseau indisponible → garder le cache Hive
      debugPrint('⚠️ [ActiveRide] One-time fetch échoué (offline?): $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }

    // ── Étape 4 : démarrer le stream ──────────────────────────
    _startStream(rideId);
  }

  // ════════════════════════════════════════════════════════════
  // STREAM TEMPS RÉEL
  // ════════════════════════════════════════════════════════════

  void _startStream(String rideId) {
    if (!mounted) return;

    _sub?.cancel();
    _reconnectTimer?.cancel();

    state = state.copyWith(isWatching: true);
    debugPrint('📡 [ActiveRide] Stream démarré: $rideId');

    _sub = _rideService.listenToRide(rideId).listen(
      (ride) async {
        if (!mounted) return;

        debugPrint('📥 [ActiveRide] Update: ${ride.status.name}');
        state = state.copyWith(ride: ride, isWatching: true, clearError: true);

        // Persister chaque mise à jour en Hive
        await _persistToHive(ride);

        // Réagir aux changements de statut
        _handleStatusChange(ride);

        // Course terminée → nettoyer après délai (laisse l'UI se mettre à jour)
        if (!ride.isActive) {
          debugPrint(
              '🏁 [ActiveRide] Terminée (${ride.status.name}) → nettoyage dans 4s');
          await Future.delayed(const Duration(seconds: 4));
          if (mounted) await _clearAndReset();
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        debugPrint('❌ [ActiveRide] Erreur stream: $error');
        state = state.copyWith(
          isWatching: false,
          error: error.toString(),
        );
        // Reconnexion avec backoff
        _scheduleReconnect(rideId);
      },
      onDone: () {
        if (!mounted) return;
        debugPrint('📡 [ActiveRide] Stream terminé');
        state = state.copyWith(isWatching: false);
      },
    );
  }

  /// Reconnexion progressive : 2s → 4s → 8s → 16s
  void _scheduleReconnect(String rideId, {int attempt = 1}) {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 * attempt).clamp(2, 16));
    debugPrint('🔄 [ActiveRide] Reconnexion dans $delay (tentative $attempt)');

    _reconnectTimer = Timer(delay, () {
      if (mounted && !state.isTerminated && !_isPaused) {
        _startStream(rideId);
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // LIFECYCLE — appelé par _MyAppState.didChangeAppLifecycleState
  // ════════════════════════════════════════════════════════════

  /// Pause le stream GPS/Firestore quand l'app passe en arrière-plan.
  /// Le timer de reconnexion est aussi stoppé pour éviter des tentatives inutiles.
  void pauseStream() {
    if (_isPaused) return;
    _isPaused = true;
    _sub?.pause();
    _reconnectTimer?.cancel();
    debugPrint('⏸️ [ActiveRide] Stream pausé (app en background)');
  }

  /// Reprend le stream quand l'app revient au premier plan.
  /// Si la subscription était pausée, on la reprend ; sinon on redémarre
  /// depuis le rideId en cache (cas d'un timeout pendant le background).
  void resumeStream() {
    if (!_isPaused) return;
    _isPaused = false;
    if (_sub != null && (_sub?.isPaused ?? false)) {
      _sub?.resume();
      debugPrint('▶️ [ActiveRide] Stream repris');
    } else {
      // Stream mort pendant le background → relancer depuis Hive
      final rideId = HiveService.getRideId();
      if (rideId != null && !state.isTerminated) {
        debugPrint('▶️ [ActiveRide] Redémarrage stream depuis cache Hive: $rideId');
        _startStream(rideId);
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // CRÉER UNE COURSE — avec RetryHelper
  // ════════════════════════════════════════════════════════════

  Future<String> createRide({
    required String userId,
    required String userName,
    required String userPhone,
    String? userPhotoUrl,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required String pickupPlaceName,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    required String destinationPlaceName,
    required double distance,
    required int estimatedDuration,
    required double estimatedFare,
    required String vehicleType,
    required String paymentMethod,
  }) async {
    if (!mounted) throw Exception('Provider disposed');

    state = state.copyWith(isCreating: true, isLoading: true, clearError: true);

    try {
      // ✅ RetryHelper : 3 tentatives avec backoff exponentiel
      final rideId = await RetryHelper.withExponentialBackoff<String>(
        label: 'createRide',
        maxRetries: 3,
        initialDelay: const Duration(seconds: 1),
        operation: () => _rideService.createRide(
          userId: userId,
          userName: userName,
          userPhone: userPhone,
          userPhotoUrl: userPhotoUrl,
          pickupLatitude: pickupLatitude,
          pickupLongitude: pickupLongitude,
          pickupAddress: pickupAddress,
          pickupPlaceName: pickupPlaceName,
          destinationLatitude: destinationLatitude,
          destinationLongitude: destinationLongitude,
          destinationAddress: destinationAddress,
          destinationPlaceName: destinationPlaceName,
          distance: distance,
          estimatedDuration: estimatedDuration,
          estimatedFare: estimatedFare,
          vehicleType: vehicleType,
          paymentMethod: paymentMethod,
        ),
      );

      debugPrint('✅ [ActiveRide] Course créée: $rideId');

      // ✅ Persister l'ID immédiatement en Hive (avant même le stream)
      // → Protection contre un kill pendant la création
      await HiveService.saveRideId(rideId);

      // Démarrer le stream (reçoit le premier snapshot Firestore)
      _startStream(rideId);

      // Notifications drivers en arrière-plan (non bloquant)
      unawaited(
        _notifService
            .notifyAvailableDrivers(
              rideId: rideId,
              pickupAddress: pickupAddress,
              destinationAddress: destinationAddress,
              estimatedFare: estimatedFare,
            )
            .catchError((e) =>
                debugPrint('⚠️ [ActiveRide] Notif drivers: $e')),
      );

      if (mounted) {
        state = state.copyWith(isCreating: false, isLoading: false);
      }

      return rideId;
    } catch (e) {
      debugPrint('❌ [ActiveRide] createRide échoué: $e');
      if (mounted) {
        state = state.copyWith(
          isCreating: false,
          isLoading: false,
          error: e.toString(),
        );
      }
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // ANNULER — avec RetryHelper
  // ════════════════════════════════════════════════════════════

  Future<void> cancelRide(String reason) async {
    final id = HiveService.getRideId() ?? state.rideId;
    if (id == null) {
      debugPrint('⚠️ [ActiveRide] cancelRide: aucun rideId');
      return;
    }

    try {
      await RetryHelper.withExponentialBackoff(
        label: 'cancelRide',
        maxRetries: 3,
        operation: () =>
            _rideService.cancelRide(id, reason, 'user'),
      );
      debugPrint('✅ [ActiveRide] Course annulée');
      // Le stream reçoit le statut 'cancelled' → _clearAndReset() auto
    } catch (e) {
      debugPrint('❌ [ActiveRide] cancelRide: $e');
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // RESET MANUEL (fin de course UI)
  // ════════════════════════════════════════════════════════════

  Future<void> clearRide() async {
    await _clearAndReset();
  }

  // ════════════════════════════════════════════════════════════
  // CALLBACKS STATUT — réactions aux transitions
  // ════════════════════════════════════════════════════════════

  void _handleStatusChange(Ride ride) {
    switch (ride.status) {
      case RideStatus.accepted:
        debugPrint('🚗 [ActiveRide] Chauffeur assigné: ${ride.driverName}');
        if (ride.driverName != null && ride.driverPhone != null) {
          unawaited(
            _notifService
                .notifyRideAccepted(
                  userId: ride.userId,
                  driverName: ride.driverName!,
                  driverPhone: ride.driverPhone!,
                )
                .catchError((e) => debugPrint('⚠️ notifyAccepted: $e')),
          );
        }
        break;
      case RideStatus.arrived:
        debugPrint('📍 [ActiveRide] Chauffeur arrivé');
        if (ride.driverName != null) {
          unawaited(
            _notifService
                .notifyDriverArrived(
                  userId: ride.userId,
                  driverName: ride.driverName!,
                )
                .catchError((e) => debugPrint('⚠️ notifyArrived: $e')),
          );
        }
        break;
      case RideStatus.started:
        debugPrint('🚦 [ActiveRide] Course démarrée');
        unawaited(
          _notifService
              .notifyRideStarted(userId: ride.userId)
              .catchError((e) => debugPrint('⚠️ notifyStarted: $e')),
        );
        break;
      case RideStatus.completed:
        debugPrint('🎉 [ActiveRide] Course terminée — ${ride.finalFare} FDJ');
        break;
      case RideStatus.noDriverAvailable:
        debugPrint('😔 [ActiveRide] Aucun chauffeur disponible');
        break;
      default:
        break;
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS PRIVÉS
  // ════════════════════════════════════════════════════════════

  Future<void> _persistToHive(Ride ride) async {
    try {
      // Écritures parallèles — minimise la fenêtre d'incohérence entre ID et JSON
      await Future.wait([
        HiveService.saveRideId(ride.rideId),
        HiveService.saveRideJson(jsonEncode(ride.toJson())),
      ]);
    } catch (e) {
      debugPrint('⚠️ [ActiveRide] Hive persist échoué: $e');
    }
  }

  Future<void> _clearAndReset() async {
    _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await HiveService.clearRide();

    if (mounted) {
      state = const ActiveRideState();
      debugPrint('🧹 [ActiveRide] État réinitialisé');
    }
  }

  void clearError() {
    if (mounted) state = state.copyWith(clearError: true);
  }

  // ════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _sub?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
// PROVIDER GLOBAL
// Utilisation dans les screens :
//   ref.watch(activeRideProvider)                       → ActiveRideState
//   ref.read(activeRideProvider.notifier).createRide()
//   ref.read(activeRideProvider.notifier).cancelRide()
//   ref.read(activeRideProvider.notifier).clearRide()
// ════════════════════════════════════════════════════════════════

final activeRideProvider =
    StateNotifierProvider<ActiveRideNotifier, ActiveRideState>(
  (ref) => ActiveRideNotifier(
    RideService(),
    DriverNotificationService(),
  ),
);
