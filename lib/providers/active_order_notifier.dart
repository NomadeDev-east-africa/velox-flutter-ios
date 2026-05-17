import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/order.dart';
import '../services/order_service.dart';
import '../services/hive_service.dart';

// ════════════════════════════════════════════════════════════════
// ÉTAT
// ════════════════════════════════════════════════════════════════

class ActiveOrderState {
  final Order? order;
  final bool isLoading;
  final bool isWatching;
  final String? error;

  const ActiveOrderState({
    this.order,
    this.isLoading = false,
    this.isWatching = false,
    this.error,
  });

  // ─── Getters métier ──────────────────────────────────────────

  bool get hasActiveOrder => order != null && !_isOrderTerminated(order!);
  bool get isTerminated   => order == null || _isOrderTerminated(order!);
  String? get orderId     => order?.id;

  static bool _isOrderTerminated(Order o) =>
      o.status == Order.statusCompleted ||
          o.status == Order.statusCancelled;

  ActiveOrderState copyWith({
    Order? order,
    bool? isLoading,
    bool? isWatching,
    String? error,
    bool clearOrder = false,
    bool clearError = false,
  }) {
    return ActiveOrderState(
      order:      clearOrder  ? null : (order      ?? this.order),
      isLoading:  isLoading  ?? this.isLoading,
      isWatching: isWatching ?? this.isWatching,
      error:      clearError  ? null : (error      ?? this.error),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NOTIFIER
// ════════════════════════════════════════════════════════════════

class ActiveOrderNotifier extends StateNotifier<ActiveOrderState> {
  final OrderService _orderService;

  StreamSubscription<DocumentSnapshot>? _sub;
  Timer?                                _reconnectTimer;
  bool                                  _isPaused = false;
  String?                               _lastProcessedStatus;

  // ✅ FIX : Flag pour bloquer _init() si attachOrder() a déjà été appelé
  bool _attachCalled = false;

  ActiveOrderNotifier(this._orderService)
      : super(const ActiveOrderState()) {
    _init();
  }

  // ════════════════════════════════════════════════════════════
  // INIT — Hive → one-time Firestore → stream
  // ════════════════════════════════════════════════════════════

  Future<void> _init() async {
    if (!mounted) return;

    state = state.copyWith(isLoading: true);

    // ── Étape 1 : cache Hive → affichage immédiat ────────────
    final cachedJson = HiveService.getOrderJson();
    if (cachedJson != null) {
      try {
        final order = Order.fromJson(
            Map<String, dynamic>.from(jsonDecode(cachedJson) as Map));

        if (ActiveOrderState._isOrderTerminated(order)) {
          await HiveService.clearOrder();
          if (mounted) state = state.copyWith(isLoading: false, clearOrder: true);
          return;
        }

        if (mounted) state = state.copyWith(order: order, isLoading: false);
        debugPrint('📦 [ActiveOrder] Cache Hive restauré: ${order.id}');
      } catch (e) {
        debugPrint('⚠️ [ActiveOrder] Cache corrompu, effacement: $e');
        await HiveService.clearOrder();
      }
    }

    // ── Étape 2 : orderId connu en Hive ? ────────────────────
    final orderId = HiveService.getOrderId();
    if (orderId == null) {
      if (mounted) state = state.copyWith(isLoading: false);
      return;
    }

    // ✅ FIX : Si attachOrder() a déjà été appelé avec un nouvel orderId,
    // on ne continue pas _init() pour éviter d'écraser le nouvel état
    if (_attachCalled) {
      debugPrint('⏭️ [ActiveOrder] _init() ignoré → attachOrder() déjà appelé');
      if (mounted) state = state.copyWith(isLoading: false);
      return;
    }

    // ── Étape 3 : one-time Firestore ─────────────────────────
    try {
      final order = await _orderService.getOrderById(orderId);

      if (!mounted) return;

      // ✅ FIX : Vérifier encore si attachOrder() a été appelé
      // pendant l'attente du fetch Firestore
      if (_attachCalled) {
        debugPrint('⏭️ [ActiveOrder] _init() fetch ignoré → attachOrder() appelé entre-temps');
        if (mounted) state = state.copyWith(isLoading: false);
        return;
      }

      if (order == null) {
        debugPrint('⚠️ [ActiveOrder] Commande $orderId introuvable en Firestore');
        await _clearAndReset();
        return;
      }

      if (ActiveOrderState._isOrderTerminated(order)) {
        debugPrint('ℹ️ [ActiveOrder] Commande $orderId déjà terminée (${order.status})');
        await _clearAndReset();
        return;
      }

      state = state.copyWith(order: order, isLoading: false, clearError: true);
      await _persistToHive(order);
      debugPrint('✅ [ActiveOrder] One-time Firestore OK: ${order.id}');
    } catch (e) {
      final msg = e is FirebaseException
          ? (e.code == 'unavailable' ? 'Pas de connexion réseau' : e.message ?? e.code)
          : e.toString();
      debugPrint('⚠️ [ActiveOrder] One-time fetch échoué (offline?): $e');
      if (mounted) state = state.copyWith(isLoading: false, error: msg);
    }

    // ── Étape 4 : démarrer le stream ─────────────────────────
    // ✅ FIX : Vérifier une dernière fois avant de démarrer le stream
    if (!_attachCalled) {
      _startStream(orderId);
    }
  }

  // ════════════════════════════════════════════════════════════
  // STREAM TEMPS RÉEL
  // ════════════════════════════════════════════════════════════

  void _startStream(String orderId) {
    if (!mounted) return;

    _sub?.cancel();
    _reconnectTimer?.cancel();
    _lastProcessedStatus = null;

    state = state.copyWith(isWatching: true);
    debugPrint('📡 [ActiveOrder] Stream démarré: $orderId');

    _sub = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .timeout(
          const Duration(minutes: 10),
          onTimeout: (sink) => sink.addError(
            TimeoutException('Firestore stream timeout — orderId: $orderId'),
          ),
        )
        .distinct()
        .listen(
          (snapshot) async {
        if (!mounted) return;

        if (!snapshot.exists) {
          debugPrint('⚠️ [ActiveOrder] Document supprimé de Firestore');
          await _clearAndReset();
          return;
        }

        final order = Order.fromFirestore(snapshot);

        // Skip duplicate status events (Firestore emits local cache + server confirmation)
        if (order.status == _lastProcessedStatus && state.order != null) {
          debugPrint('⏭️ [ActiveOrder] Statut dupliqué ignoré: ${order.status}');
          return;
        }
        _lastProcessedStatus = order.status;
        debugPrint('📥 [ActiveOrder] Update statut: ${order.status}');

        state = state.copyWith(order: order, isWatching: true, clearError: true);
        await _persistToHive(order);

        if (ActiveOrderState._isOrderTerminated(order)) {
          debugPrint(
              '🏁 [ActiveOrder] Terminée (${order.status}) → nettoyage dans 4s');
          await Future.delayed(const Duration(seconds: 4));
          if (mounted) await _clearAndReset();
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        debugPrint('❌ [ActiveOrder] Erreur stream: $error');
        state = state.copyWith(isWatching: false, error: error.toString());
        _scheduleReconnect(orderId);
      },
      onDone: () {
        if (!mounted) return;
        state = state.copyWith(isWatching: false);
      },
    );
  }

  void _scheduleReconnect(String orderId, {int attempt = 1}) {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 * attempt).clamp(2, 16));
    debugPrint('🔄 [ActiveOrder] Reconnexion dans $delay (tentative $attempt)');

    _reconnectTimer = Timer(delay, () {
      if (mounted && !state.isTerminated && !_isPaused) {
        _startStream(orderId);
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // LIFECYCLE — appelé par _MyAppState.didChangeAppLifecycleState
  // ════════════════════════════════════════════════════════════

  void pauseStream() {
    if (_isPaused) return;
    _isPaused = true;
    // Don't call _sub?.pause() — it buffers all Firestore events and delivers
    // them in a burst when resumed, making the UI appear stuck then jump.
    // Firestore handles connectivity natively; we just track the flag.
    _reconnectTimer?.cancel();
    debugPrint('⏸️ [ActiveOrder] Stream marqué en background (sans pause)');
  }

  void resumeStream() {
    if (!_isPaused) return;
    _isPaused = false;
    debugPrint('▶️ App au premier plan — refresh immédiat');

    // Do a one-shot get() to immediately show current state without waiting
    // for the next stream event (which could take seconds).
    final orderId = HiveService.getOrderId();
    if (orderId != null && !state.isTerminated) {
      _refreshOnce(orderId);
    }
  }

  Future<void> _refreshOnce(String orderId) async {
    try {
      final order = await _orderService.getOrderById(orderId);
      if (!mounted || order == null) return;
      if (order.status == _lastProcessedStatus && state.order != null) return;
      _lastProcessedStatus = order.status;
      debugPrint('🔄 [ActiveOrder] Refresh post-resume: ${order.status}');
      state = state.copyWith(order: order, clearError: true);
      await _persistToHive(order);
      if (ActiveOrderState._isOrderTerminated(order)) {
        await Future.delayed(const Duration(seconds: 4));
        if (mounted) await _clearAndReset();
      }
    } catch (e) {
      debugPrint('⚠️ [ActiveOrder] Refresh post-resume échoué: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // ATTACHER UNE COMMANDE CRÉÉE
  // ════════════════════════════════════════════════════════════

  /// [initialOrder] : si fourni (création immédiate), on skip le one-time Firestore
  /// fetch — la navigation se déclenche instantanément. Sans lui (restauration Hive),
  /// on fait un fetch normal pour s'assurer que les données sont à jour.
  Future<void> attachOrder(String orderId, {Order? initialOrder}) async {
    if (!mounted) return;

    // Idempotence : ignorer si le même orderId est déjà actif ou en cours de chargement
    final activeId = state.orderId ?? HiveService.getOrderId();
    if (activeId == orderId && (state.isLoading || state.isWatching)) {
      debugPrint('⏭️ [ActiveOrder] attachOrder ignoré → $orderId déjà actif/en cours');
      return;
    }

    _attachCalled = true;

    _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    debugPrint('🔗 [ActiveOrder] attachOrder appelé: $orderId');

    await HiveService.clearOrder();
    await HiveService.saveOrderId(orderId);

    if (initialOrder != null) {
      // ── Chemin rapide : Order déjà disponible → navigation immédiate ──
      if (mounted) {
        state = state.copyWith(order: initialOrder, isLoading: false, clearError: true);
        await _persistToHive(initialOrder);
        debugPrint('✅ [ActiveOrder] Commande attachée (direct): ${initialOrder.id}');
      }
    } else {
      // ── Chemin normal : fetch Firestore (restauration depuis Hive) ────
      if (mounted) state = state.copyWith(isLoading: true, clearOrder: true);
      try {
        final order = await _orderService.getOrderById(orderId);
        if (order != null && mounted) {
          state = state.copyWith(order: order, isLoading: false, clearError: true);
          await _persistToHive(order);
          debugPrint('✅ [ActiveOrder] Commande attachée: ${order.id}');
        } else {
          if (mounted) state = state.copyWith(isLoading: false);
        }
      } catch (e) {
        debugPrint('⚠️ [ActiveOrder] attachOrder fetch: $e');
        if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      }
    }

    // Démarrer le stream temps réel sur le NOUVEL orderId
    _startStream(orderId);
  }

  // ════════════════════════════════════════════════════════════
  // ANNULER — avec RetryHelper
  // ════════════════════════════════════════════════════════════

  Future<void> cancelOrder() async {
    final id = HiveService.getOrderId() ?? state.orderId;
    if (id == null) {
      throw Exception('Identifiant de commande introuvable');
    }

    try {
      final success = await _orderService.cancelOrder(id);
      if (!success) throw Exception('Échec de l\'annulation côté serveur');
      debugPrint('✅ [ActiveOrder] Commande annulée');
      // Le stream reçoit 'cancelled' → _clearAndReset() auto
    } catch (e) {
      debugPrint('❌ [ActiveOrder] cancelOrder: $e');
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════
  // RESET MANUEL
  // ════════════════════════════════════════════════════════════

  Future<void> clearOrder() async {
    await _clearAndReset();
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS PRIVÉS
  // ════════════════════════════════════════════════════════════

  Future<void> _persistToHive(Order order) async {
    try {
      // Écritures parallèles — minimise la fenêtre d'incohérence entre ID et JSON
      await Future.wait([
        HiveService.saveOrderId(order.id),
        HiveService.saveOrderJson(jsonEncode(order.toJson())),
      ]);
    } catch (e) {
      debugPrint('⚠️ [ActiveOrder] Hive persist: $e');
    }
  }

  Future<void> _clearAndReset() async {
    _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // ✅ FIX : Réinitialiser le flag pour permettre un futur _init()
    _attachCalled = false;

    await HiveService.clearOrder();

    if (mounted) {
      state = const ActiveOrderState();
      debugPrint('🧹 [ActiveOrder] État réinitialisé');
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
// ════════════════════════════════════════════════════════════════

final activeOrderProvider =
StateNotifierProvider<ActiveOrderNotifier, ActiveOrderState>(
      (ref) => ActiveOrderNotifier(OrderService()),
);