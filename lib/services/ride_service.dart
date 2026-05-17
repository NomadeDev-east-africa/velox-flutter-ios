import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nomade_client/models/ride.dart';

/// Service de gestion des courses — camelCase + collection taxiRides
/// PHASE 0 :
///   taxi_rides → taxiRides (collection Firestore renommée)
///   Tous les champs restent en camelCase (déjà correct)
class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Collection renommée : taxi_rides → taxiRides
  static const String _collection = 'taxiRides';

  // ─────────────────────────────────────────────────────────────
  // CRÉATION
  // ─────────────────────────────────────────────────────────────

  /// Créer une nouvelle course
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
    try {
      final docRef = await _firestore.collection(_collection).add({
        // Participants
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'userPhotoUrl': userPhotoUrl,

        // Pickup
        'pickup': {
          'latitude': pickupLatitude,
          'longitude': pickupLongitude,
          'address': pickupAddress,
          'placeName': pickupPlaceName,
        },

        // Destination
        'destination': {
          'latitude': destinationLatitude,
          'longitude': destinationLongitude,
          'address': destinationAddress,
          'placeName': destinationPlaceName,
        },

        // Détails course
        'distance': distance,
        'estimatedDuration': estimatedDuration,
        'estimatedFare': estimatedFare,
        'finalFare': null,

        // Véhicule
        'vehicleType': vehicleType,
        'vehicleId': null,

        // Chauffeur (null au début — assigné par Cloud Functions)
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'driverPhotoUrl': null,

        // Statuts
        'status': 'requested',
        'paymentMethod': paymentMethod,
        'paymentStatus': 'pending',

        // Timestamps
        'requestedAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'arrivedAt': null,
        'startedAt': null,
        'completedAt': null,
        'cancelledAt': null,
        'updatedAt': FieldValue.serverTimestamp(),

        // Évaluations
        'userRating': null,
        'userReview': null,
        'driverRating': null,
        'driverReview': null,

        // Annulation
        'cancellationReason': null,
        'cancelledBy': null,
      });

      debugPrint('✅ [RideService] Course créée: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ [RideService] createRide: $e');
      throw Exception('Erreur création course: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STREAM TEMPS RÉEL
  // ─────────────────────────────────────────────────────────────

  /// Écouter une course en temps réel
  /// Timeout de 45s : si aucun snapshot reçu, déclenche onError → reconnexion backoff
  Stream<Ride> listenToRide(String rideId) {
    return _firestore
        .collection(_collection)
        .doc(rideId)
        .snapshots()
        .timeout(
          const Duration(seconds: 45),
          onTimeout: (sink) => sink.addError(
            TimeoutException('Firestore stream timeout — rideId: $rideId'),
          ),
        )
        .distinct()
        .map((doc) {
          if (!doc.exists) throw Exception('Course non trouvée: $rideId');
          return Ride.fromFirestore(doc);
        });
  }

  // ─────────────────────────────────────────────────────────────
  // LECTURE ONE-TIME
  // ─────────────────────────────────────────────────────────────

  /// Lire une course une seule fois (pour la reprise après kill)
  Future<Ride?> getRideById(String rideId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(rideId).get();
      if (!doc.exists) return null;
      return Ride.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ [RideService] getRideById: $e');
      return null;
    }
  }

  /// Course active d'un utilisateur (pour la reprise après kill)
  Future<Ride?> getActiveRide(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            'requested',
            'accepted',
            'arrived',
            'started',
          ])
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;
      return Ride.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ [RideService] getActiveRide: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MISES À JOUR
  // ─────────────────────────────────────────────────────────────

  Future<void> cancelRide(
      String rideId, String reason, String cancelledBy) async {
    try {
      await _firestore.collection(_collection).doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': cancelledBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur annulation: $e');
    }
  }

  Future<void> rateDriver(String rideId, int rating, String? review) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('La note doit être entre 1 et 5');
      }
      await _firestore.collection(_collection).doc(rideId).update({
        'userRating': rating,
        'userReview': review,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur notation: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HISTORIQUE
  // ─────────────────────────────────────────────────────────────

  Future<List<Ride>> getUserRideHistory(String userId,
      {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Ride.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Erreur historique: $e');
    }
  }

}
