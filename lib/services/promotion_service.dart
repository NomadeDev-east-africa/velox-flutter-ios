import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/promotion.dart';

class PromotionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Promotion>> getActivePromotionsForRestaurant(
      String restaurantId) async {
    try {
      final snapshot = await _db
          .collection('promotions')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .where((p) => p.isCurrentlyActive)
          .toList();
    } catch (e) {
      debugPrint('⚠️ [PromotionService] $e');
      return [];
    }
  }
}
