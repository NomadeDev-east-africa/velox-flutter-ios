import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service de notifications pour le module FOOD/RESTAURANT
/// Délègue le FCM à sendRestaurantNotification (CF) — fallback silencieux si indisponible
class FoodNotificationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // ⬅️ MÉTHODE PRINCIPALE: Envoyer notification au restaurant
  Future<void> notifyRestaurantNewOrder({
    required String restaurantId,
    required String restaurantName,
    required String orderId,
    required String customerName,
    required int total,
  }) async {
    debugPrint('📲 [FoodNotification] Envoi notification restaurant...');
    debugPrint('  - Restaurant: $restaurantName ($restaurantId)');
    debugPrint('  - Commande: $orderId');
    debugPrint('  - Client: $customerName');
    debugPrint('  - Total: $total FDJ');

    try {
      // ⬅️ OPTION 1: Via Cloud Function (RECOMMANDÉ)
      try {
        final callable = _functions.httpsCallable('sendRestaurantNotification');
        final result = await callable.call({
          'restaurantId': restaurantId,
          'restaurantName': restaurantName,
          'orderId': orderId,
          'customerName': customerName,
          'total': total,
        });

        debugPrint('✅ [FoodNotification] Notification envoyée via Cloud Function');
        debugPrint('  - Résultat: ${result.data}');
        return;
      } catch (e) {
        // CF indisponible — onOrderCreated gère le FCM en fallback
        debugPrint('⚠️ [FoodNotification] CF non disponible: $e');
      }
    } catch (e) {
      debugPrint('❌ [FoodNotification] Erreur: $e');
      // Ne pas rethrow pour ne pas bloquer la création de commande
    }
  }

}
