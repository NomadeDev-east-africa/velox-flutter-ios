import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour un chauffeur favori — camelCase unifié
/// PHASE 0 :
///   driver_name     → driverName
///   driver_photo_url→ driverPhotoUrl
///   driver_phone    → driverPhone
///   driver_rating   → driverRating
///   vehicle_type    → vehicleType
///   added_at        → addedAt
///   rides_count     → ridesCount
///   last_ride_id    → lastRideId
///   driver_id       → supprimé (inutile, c'est le doc.id)
class FavoriteDriver {
  final String driverId;
  final String driverName;
  final String? driverPhotoUrl;
  final String? driverPhone;
  final double? driverRating;
  final String? vehicleType;
  final DateTime addedAt;
  final int ridesCount;
  final String lastRideId;

  const FavoriteDriver({
    required this.driverId,
    required this.driverName,
    this.driverPhotoUrl,
    this.driverPhone,
    this.driverRating,
    this.vehicleType,
    required this.addedAt,
    this.ridesCount = 1,
    required this.lastRideId,
  });

  factory FavoriteDriver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FavoriteDriver(
      driverId: doc.id,
      // ✅ camelCase
      driverName: data['driverName'] ?? '',
      driverPhotoUrl: data['driverPhotoUrl'],
      driverPhone: data['driverPhone'],
      driverRating: data['driverRating'] != null
          ? (data['driverRating'] as num).toDouble()
          : null,
      vehicleType: data['vehicleType'],
      // ✅ camelCase : addedAt
      addedAt: data['addedAt'] != null
          ? (data['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
      // ✅ camelCase : ridesCount
      ridesCount: data['ridesCount'] ?? 1,
      // ✅ camelCase : lastRideId
      lastRideId: data['lastRideId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // ✅ camelCase — toutes les clés
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'driverPhone': driverPhone,
      'driverRating': driverRating,
      'vehicleType': vehicleType,
      'addedAt': Timestamp.fromDate(addedAt),
      'ridesCount': ridesCount,
      'lastRideId': lastRideId,
    };
  }

  FavoriteDriver copyWith({
    String? driverName,
    String? driverPhotoUrl,
    String? driverPhone,
    double? driverRating,
    String? vehicleType,
    int? ridesCount,
    String? lastRideId,
  }) {
    return FavoriteDriver(
      driverId: driverId,
      driverName: driverName ?? this.driverName,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      driverPhone: driverPhone ?? this.driverPhone,
      driverRating: driverRating ?? this.driverRating,
      vehicleType: vehicleType ?? this.vehicleType,
      addedAt: addedAt,
      ridesCount: ridesCount ?? this.ridesCount,
      lastRideId: lastRideId ?? this.lastRideId,
    );
  }
}
