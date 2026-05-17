import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local avec SharedPreferences
/// Permet un démarrage instantané en affichant les données en cache
/// avant que Firestore réponde
class LocalCache {
  static SharedPreferences? _prefs;

  /// Initialiser le cache (appeler dans main.dart avant runApp)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ [LocalCache] Initialisé');
  }

  static SharedPreferences get _instance {
    assert(_prefs != null, 'LocalCache.init() doit être appelé dans main.dart');
    return _prefs!;
  }

  // ─── USER ────────────────────────────────────────────────────

  static Future<void> saveUserId(String userId) async {
    await _instance.setString('userId', userId);
  }

  static String? getUserId() => _instance.getString('userId');

  static Future<void> saveUserName(String name) async {
    await _instance.setString('userName', name);
  }

  static String? getUserName() => _instance.getString('userName');

  static Future<void> saveUserPhone(String phone) async {
    await _instance.setString('userPhone', phone);
  }

  static String? getUserPhone() => _instance.getString('userPhone');

  static Future<void> clearUser() async {
    await _instance.remove('userId');
    await _instance.remove('userName');
    await _instance.remove('userPhone');
    debugPrint('🗑️ [LocalCache] User vidé');
  }

  // ─── FCM TOKEN ───────────────────────────────────────────────

  static Future<void> saveFcmToken(String token) async {
    await _instance.setString('fcmToken', token);
  }

  static String? getFcmToken() => _instance.getString('fcmToken');

  // ─── GPS DERNIÈRE POSITION ───────────────────────────────────

  static Future<void> saveLastPosition(double lat, double lng) async {
    await _instance.setDouble('lastLat', lat);
    await _instance.setDouble('lastLng', lng);
    await _instance.setInt(
      'lastPositionTimestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static ({double lat, double lng, DateTime timestamp})? getLastPosition() {
    final lat = _instance.getDouble('lastLat');
    final lng = _instance.getDouble('lastLng');
    final ts = _instance.getInt('lastPositionTimestamp');
    if (lat == null || lng == null || ts == null) return null;
    return (
      lat: lat,
      lng: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  // ─── PARAMÈTRES APP ──────────────────────────────────────────

  static Future<void> saveLanguage(String lang) async {
    await _instance.setString('language', lang);
  }

  static String getLanguage() => _instance.getString('language') ?? 'fr';

  static Future<void> saveDarkMode(bool value) async {
    await _instance.setBool('darkMode', value);
  }

  static bool getDarkMode() => _instance.getBool('darkMode') ?? true;

  // ─── NOTIFICATION PENDING (background handler) ───────────────
  // Persiste la dernière notification reçue en background
  // pour navigation au prochain démarrage de l'app.

  static Future<void> savePendingNotification({
    required String type,
    String? orderId,
    String? rideId,
  }) async {
    await _instance.setString('pendingNotifType', type);
    if (orderId != null) await _instance.setString('pendingNotifOrderId', orderId);
    if (rideId  != null) await _instance.setString('pendingNotifRideId',  rideId);
    await _instance.setInt(
      'pendingNotifTs',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static ({String type, String? orderId, String? rideId, DateTime ts})? getPendingNotification() {
    final type = _instance.getString('pendingNotifType');
    if (type == null) return null;
    final ts = _instance.getInt('pendingNotifTs') ?? 0;
    // Ignorer si la notification a plus de 5 minutes (déjà traitée ou périmée)
    if (DateTime.now().millisecondsSinceEpoch - ts > 300000) {
      clearPendingNotification();
      return null;
    }
    return (
      type:    type,
      orderId: _instance.getString('pendingNotifOrderId'),
      rideId:  _instance.getString('pendingNotifRideId'),
      ts:      DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  static Future<void> clearPendingNotification() async {
    await _instance.remove('pendingNotifType');
    await _instance.remove('pendingNotifOrderId');
    await _instance.remove('pendingNotifRideId');
    await _instance.remove('pendingNotifTs');
  }

  // ─── CLEAR COMPLET ───────────────────────────────────────────

  static Future<void> clearAll() async {
    await _instance.clear();
    debugPrint('🗑️ [LocalCache] Tout vidé');
  }
}
