import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/favorite_driver.dart';

/// Service pour gérer les chauffeurs favoris — camelCase unifié
/// PHASE 0 :
///   driver_name     → driverName
///   driver_photo_url→ driverPhotoUrl
///   driver_rating   → driverRating
///   rides_count     → ridesCount
///   last_ride_id    → lastRideId
///   added_at        → addedAt
class FavoriteDriversService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // AJOUTER / METTRE À JOUR
  // ─────────────────────────────────────────────────────────────

  Future<void> addToFavorites({
    required String userId,
    required String driverId,
    required String driverName,
    String? driverPhotoUrl,
    String? driverPhone,
    double? driverRating,
    String? vehicleType,
    required String rideId,
  }) async {
    try {
      debugPrint(
          '❤️ [FavService] Ajout chauffeur $driverName aux favoris de $userId');

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_drivers')
          .doc(driverId);

      final existingDoc = await docRef.get();

      if (existingDoc.exists) {
        // Déjà en favoris → incrémenter le compteur
        final currentCount = existingDoc.data()?['ridesCount'] ?? 0;

        await docRef.update({
          // ✅ camelCase
          'ridesCount': currentCount + 1,
          'lastRideId': rideId,
          'driverName': driverName,
          'driverPhotoUrl': driverPhotoUrl,
          'driverRating': driverRating,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '✅ [FavService] Compteur mis à jour: ${currentCount + 1}');
      } else {
        // Nouveau favori
        final favoriteDriver = FavoriteDriver(
          driverId: driverId,
          driverName: driverName,
          driverPhotoUrl: driverPhotoUrl,
          driverPhone: driverPhone,
          driverRating: driverRating,
          vehicleType: vehicleType,
          addedAt: DateTime.now(),
          ridesCount: 1,
          lastRideId: rideId,
        );

        await docRef.set(favoriteDriver.toFirestore());
        debugPrint('✅ [FavService] Chauffeur ajouté aux favoris');
      }
    } catch (e) {
      debugPrint('❌ [FavService] addToFavorites: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RETIRER
  // ─────────────────────────────────────────────────────────────

  Future<void> removeFromFavorites({
    required String userId,
    required String driverId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_drivers')
          .doc(driverId)
          .delete();

      debugPrint('✅ [FavService] Chauffeur retiré des favoris');
    } catch (e) {
      debugPrint('❌ [FavService] removeFromFavorites: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LECTURE
  // ─────────────────────────────────────────────────────────────

  Future<bool> isFavorite({
    required String userId,
    required String driverId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_drivers')
          .doc(driverId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ [FavService] isFavorite: $e');
      return false;
    }
  }

  /// Stream des favoris — trié par addedAt
  Stream<List<FavoriteDriver>> getFavoriteDrivers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_drivers')
        // ✅ camelCase : addedAt
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteDriver.fromFirestore(doc))
            .toList());
  }

  Future<List<FavoriteDriver>> getFavoriteDriversList(
      String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_drivers')
          // ✅ camelCase : addedAt
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FavoriteDriver.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ [FavService] getFavoriteDriversList: $e');
      return [];
    }
  }

  Future<FavoriteDriver?> getFavoriteDriver({
    required String userId,
    required String driverId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_drivers')
          .doc(driverId)
          .get();

      if (doc.exists) return FavoriteDriver.fromFirestore(doc);
      return null;
    } catch (e) {
      debugPrint('❌ [FavService] getFavoriteDriver: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MISE À JOUR
  // ─────────────────────────────────────────────────────────────

  Future<void> updateFavoriteDriver({
    required String userId,
    required String driverId,
    String? driverName,
    String? driverPhotoUrl,
    double? driverRating,
  }) async {
    try {
      final updates = <String, dynamic>{};

      // ✅ camelCase
      if (driverName != null) updates['driverName'] = driverName;
      if (driverPhotoUrl != null) updates['driverPhotoUrl'] = driverPhotoUrl;
      if (driverRating != null) updates['driverRating'] = driverRating;
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favorite_drivers')
            .doc(driverId)
            .update(updates);

        debugPrint('✅ [FavService] Infos chauffeur favori mises à jour');
      }
    } catch (e) {
      debugPrint('❌ [FavService] updateFavoriteDriver: $e');
    }
  }
}
