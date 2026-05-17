import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// ════════════════════════════════════════════════════════════════
/// HiveService — Persistance locale Nomade253
/// ════════════════════════════════════════════════════════════════
///
/// Stratégie : boxes de type `Box<String>`, données stockées en JSON.
/// Pas de HiveTypeAdapters générés → zéro build_runner.
///
/// Boxes :
///   📦 active_ride   → rideId actif + snapshot JSON de la course
///   📦 active_order  → orderId actif + snapshot JSON de la commande
///   📦 cart          → items du panier + restaurantId en JSON
///
/// Règle d'utilisation :
///   • On écrit en Hive APRÈS chaque mise à jour Firestore confirmée
///   • On lit depuis Hive AU DÉMARRAGE pour affichage immédiat
///   • Firestore reste la source de vérité absolue
/// ════════════════════════════════════════════════════════════════
class HiveService {
  // ─── Noms des boxes ──────────────────────────────────────────
  static const String _rideBox  = 'active_ride';
  static const String _orderBox = 'active_order';
  static const String _cartBox  = 'cart';

  // ─── Clés internes ───────────────────────────────────────────
  static const String _keyRideId    = 'rideId';
  static const String _keyRideData  = 'rideData';
  static const String _keyOrderId   = 'orderId';
  static const String _keyOrderData = 'orderData';
  static const String _keyCartData  = 'cartData';

  // ════════════════════════════════════════════════════════════
  // INITIALISATION — à appeler dans main() AVANT runApp()
  // ════════════════════════════════════════════════════════════

  static Future<void> init() async {
    await Hive.initFlutter();

    // Ouvrir les 3 boxes au démarrage
    await Future.wait([
      Hive.openBox<String>(_rideBox),
      Hive.openBox<String>(_orderBox),
      Hive.openBox<String>(_cartBox),
    ]);

    debugPrint('✅ [HiveService] Initialisé — 3 boxes ouvertes');
  }

  // ════════════════════════════════════════════════════════════
  // COURSE ACTIVE (active_ride)
  // ════════════════════════════════════════════════════════════

  /// Sauvegarder l'ID de la course active
  static Future<void> saveRideId(String rideId) async {
    await _rideBox_.put(_keyRideId, rideId);
    debugPrint('💾 [HiveService] rideId sauvegardé: $rideId');
  }

  /// Lire l'ID de la course active (null si aucune)
  static String? getRideId() {
    return _rideBox_.get(_keyRideId);
  }

  /// Sauvegarder le snapshot JSON complet de la course
  static Future<void> saveRideJson(String json) async {
    await _rideBox_.put(_keyRideData, json);
  }

  /// Lire le snapshot JSON de la course (null si absent)
  static String? getRideJson() {
    return _rideBox_.get(_keyRideData);
  }

  /// Effacer toutes les données de la course active
  static Future<void> clearRide() async {
    await Future.wait([
      _rideBox_.delete(_keyRideId),
      _rideBox_.delete(_keyRideData),
    ]);
    debugPrint('🗑️ [HiveService] Course active effacée');
  }

  /// Vérifier si une course active est en cache
  static bool hasActiveRide() => getRideId() != null;

  // ════════════════════════════════════════════════════════════
  // COMMANDE ACTIVE (active_order)
  // ════════════════════════════════════════════════════════════

  /// Sauvegarder l'ID de la commande active
  static Future<void> saveOrderId(String orderId) async {
    await _orderBox_.put(_keyOrderId, orderId);
    debugPrint('💾 [HiveService] orderId sauvegardé: $orderId');
  }

  /// Lire l'ID de la commande active (null si aucune)
  static String? getOrderId() {
    return _orderBox_.get(_keyOrderId);
  }

  /// Sauvegarder le snapshot JSON complet de la commande
  static Future<void> saveOrderJson(String json) async {
    await _orderBox_.put(_keyOrderData, json);
  }

  /// Lire le snapshot JSON de la commande (null si absent)
  static String? getOrderJson() {
    return _orderBox_.get(_keyOrderData);
  }

  /// Effacer toutes les données de la commande active
  static Future<void> clearOrder() async {
    await Future.wait([
      _orderBox_.delete(_keyOrderId),
      _orderBox_.delete(_keyOrderData),
    ]);
    debugPrint('🗑️ [HiveService] Commande active effacée');
  }

  /// Vérifier si une commande active est en cache
  static bool hasActiveOrder() => getOrderId() != null;

  // ════════════════════════════════════════════════════════════
  // PANIER (cart)
  // ════════════════════════════════════════════════════════════

  /// Sauvegarder le panier complet en JSON
  /// Format attendu : { 'restaurantId': '...', 'restaurantName': '...',
  ///                    'restaurantImageUrl': '...', 'items': [...] }
  static Future<void> saveCartJson(String json) async {
    await _cartBox_.put(_keyCartData, json);
    debugPrint('💾 [HiveService] Panier sauvegardé');
  }

  /// Lire le panier (null si vide)
  static String? getCartJson() {
    return _cartBox_.get(_keyCartData);
  }

  /// Effacer le panier
  static Future<void> clearCart() async {
    await _cartBox_.delete(_keyCartData);
    debugPrint('🗑️ [HiveService] Panier effacé');
  }

  /// Vérifier si un panier en cache existe
  static bool hasCart() => getCartJson() != null;

  // ════════════════════════════════════════════════════════════
  // LOGOUT — effacer toutes les données métier
  // Appeler lors de la déconnexion utilisateur
  // ════════════════════════════════════════════════════════════

  /// Effacer ride + order + cart (garder les préférences UI)
  static Future<void> clearAllSession() async {
    await Future.wait([
      clearRide(),
      clearOrder(),
      clearCart(),
    ]);
    debugPrint('🗑️ [HiveService] Session complète effacée');
  }

  // ════════════════════════════════════════════════════════════
  // FERMETURE — à appeler dans dispose() si nécessaire
  // ════════════════════════════════════════════════════════════

  static Future<void> close() async {
    await Hive.close();
    debugPrint('🔒 [HiveService] Boxes fermées');
  }

  // ─── Accès aux boxes (lazy, toujours ouvertes après init) ───
  static Box<String> get _rideBox_  => Hive.box<String>(_rideBox);
  static Box<String> get _orderBox_ => Hive.box<String>(_orderBox);
  static Box<String> get _cartBox_  => Hive.box<String>(_cartBox);
}
