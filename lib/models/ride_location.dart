/// Position géographique pour une course (pickup ou destination)
/// PHASE 0+1 :
///   place_name → placeName (camelCase)
///   Ajout toJson()/fromJson() pour Hive
class RideLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String? placeName;

  const RideLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
  });

  // ─── Firestore ───────────────────────────────────────────────

  /// Créer depuis Map Firestore — camelCase
  factory RideLocation.fromMap(Map<String, dynamic> map) {
    return RideLocation(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      // ✅ camelCase : placeName (était place_name)
      placeName: map['placeName'],
    );
  }

  /// Convertir vers Firestore — camelCase
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      // ✅ camelCase : placeName
      'placeName': placeName,
    };
  }

  // ─── Hive (JSON local) ───────────────────────────────────────

  /// Sérialiser pour Hive — types primitifs uniquement
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
    };
  }

  /// Désérialiser depuis Hive
  factory RideLocation.fromJson(Map<String, dynamic> json) {
    return RideLocation(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'] ?? '',
      placeName: json['placeName'],
    );
  }

  // ─── Utilitaires ─────────────────────────────────────────────

  RideLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
  }) {
    return RideLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
    );
  }

  @override
  String toString() =>
      'RideLocation($latitude, $longitude — $address)';
}
