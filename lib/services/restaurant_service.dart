import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nomade_client/models/restaurant.dart';

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'restaurants';

  Stream<List<Restaurant>> streamRestaurants() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final restaurants = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .toList();
      if (kDebugMode) debugPrint('🔍 [RestaurantService] streamRestaurants: ${restaurants.length}');
      return restaurants;
    });
  }

  Future<List<Restaurant>> getRestaurants() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final restaurants = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .toList();

      restaurants.sort((a, b) => b.rating.compareTo(a.rating));

      if (kDebugMode) debugPrint('🔍 [RestaurantService] getRestaurants: ${restaurants.length}');
      return restaurants;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] getRestaurants: $e');
      return [];
    }
  }

  Future<Restaurant?> getRestaurantById(String restaurantId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(restaurantId)
          .get();

      if (doc.exists) {
        if (kDebugMode) debugPrint('🔍 [RestaurantService] getRestaurantById: ${doc.data()?['name']}');
        return Restaurant.fromFirestore(doc);
      }
      if (kDebugMode) debugPrint('❌ [RestaurantService] getRestaurantById non trouvé: $restaurantId');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] getRestaurantById: $e');
      return null;
    }
  }

  Stream<Restaurant?> streamRestaurant(String restaurantId) {
    return _firestore
        .collection(_collection)
        .doc(restaurantId)
        .snapshots()
        .map((doc) => doc.exists ? Restaurant.fromFirestore(doc) : null);
  }

  Future<List<Restaurant>> getOpenRestaurants() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('isOpen', isEqualTo: true)
          .get();

      final restaurants = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .toList();

      restaurants.sort((a, b) => b.rating.compareTo(a.rating));
      return restaurants;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] getOpenRestaurants: $e');
      return [];
    }
  }

  Future<List<Restaurant>> searchRestaurants(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] searchRestaurants: $e');
      return [];
    }
  }

  Future<List<Restaurant>> getPopularRestaurants({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final restaurants = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .toList();

      restaurants.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
      return restaurants.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] getPopularRestaurants: $e');
      return [];
    }
  }

  Future<List<Restaurant>> getTopRatedRestaurants({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final restaurants = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .where((r) => r.rating > 0)
          .toList();

      restaurants.sort((a, b) => b.rating.compareTo(a.rating));
      return restaurants.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [RestaurantService] getTopRatedRestaurants: $e');
      return [];
    }
  }
}
