import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer les notations des chauffeurs
/// PHASE 0 :
///   taxi_rides  → taxiRides
///   user_id     → userId
///   user_name   → userName
///   ride_id     → rideId
///   created_at  → createdAt
///   user_rating → userRating (déjà correct, mais cohérence)
///   user_review → userReview
///   rated_at    → ratedAt
///   total_ratings → totalRatings
class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Collection renommée
  static const String _ridesCollection = 'taxiRides';

  /// Soumettre une note pour un chauffeur
  Future<void> rateDriver({
    required String driverId,
    required String rideId,
    required String userId,
    required int rating,
    String? review,
  }) async {
    try {
      debugPrint('⭐ [RatingService] Notation chauffeur $driverId: $rating/5');

      if (rating < 1 || rating > 5) {
        throw Exception('Note invalide: doit être entre 1 et 5');
      }

      await _updateRideRating(rideId, rating, review);
      await _createRatingEntry(driverId, userId, rideId, rating, review);
      // La CF onTaxiRideRated recalcule automatiquement drivers.rating

      debugPrint('✅ [RatingService] Notation enregistrée avec succès');
    } catch (e) {
      debugPrint('❌ [RatingService] rateDriver: $e');
      rethrow;
    }
  }

  Future<void> _updateRideRating(
      String rideId, int rating, String? review) async {
    try {
      await _firestore.collection(_ridesCollection).doc(rideId).update({
        // ✅ camelCase
        'userRating': rating,
        'userReview': review,
        'ratedAt': FieldValue.serverTimestamp(),
        'rated': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ [RatingService] Note ajoutée à la course $rideId');
    } catch (e) {
      debugPrint('❌ [RatingService] _updateRideRating: $e');
      rethrow;
    }
  }

  Future<void> _createRatingEntry(
    String driverId,
    String userId,
    String rideId,
    int rating,
    String? review,
  ) async {
    try {
      String? userName;
      try {
        final userDoc =
            await _firestore.collection('users').doc(userId).get();
        userName =
            userDoc.data()?['name'] ?? userDoc.data()?['displayName'];
      } catch (_) {
        debugPrint('⚠️ [RatingService] Impossible de récupérer le nom user');
      }

      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('ratings')
          .add({
        // ✅ camelCase
        'userId': userId,
        'userName': userName,
        'rideId': rideId,
        'rating': rating,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '✅ [RatingService] Entrée créée dans drivers/$driverId/ratings');
    } catch (e) {
      debugPrint('❌ [RatingService] _createRatingEntry: $e');
      // Non bloquant
    }
  }

  /// Vérifier si une course a déjà été notée
  Future<bool> isRideRated(String rideId) async {
    try {
      final doc =
          await _firestore.collection(_ridesCollection).doc(rideId).get();
      final data = doc.data();
      if (data == null) return false;
      return data['rated'] == true || data['userRating'] != null;
    } catch (e) {
      debugPrint('❌ [RatingService] isRideRated: $e');
      return false;
    }
  }

  /// Statistiques de notation d'un chauffeur
  Future<Map<String, dynamic>> getDriverRatingStats(String driverId) async {
    try {
      final driverDoc =
          await _firestore.collection('drivers').doc(driverId).get();
      final driverData = driverDoc.data();

      if (driverData == null) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingDistribution': <int, int>{},
        };
      }

      final ratingsSnapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('ratings')
          .get();

      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var doc in ratingsSnapshot.docs) {
        final r = doc.data()['rating'] as int?;
        if (r != null && r >= 1 && r <= 5) {
          distribution[r] = (distribution[r] ?? 0) + 1;
        }
      }

      return {
        'averageRating': driverData['rating'] ?? 0.0,
        // ✅ camelCase : totalRatings
        'totalRatings': driverData['totalRatings'] ?? 0,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      debugPrint('❌ [RatingService] getDriverRatingStats: $e');
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingDistribution': <int, int>{},
      };
    }
  }

  /// Avis récents d'un chauffeur
  Future<List<Map<String, dynamic>>> getDriverRecentReviews(
    String driverId, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('ratings')
          .where('review', isNull: false)
          // ✅ camelCase : createdAt
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          // ✅ camelCase dans la réponse aussi
          'userName': data['userName'] ?? 'Utilisateur',
          'rating': data['rating'],
          'review': data['review'],
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ [RatingService] getDriverRecentReviews: $e');
      return [];
    }
  }
}
