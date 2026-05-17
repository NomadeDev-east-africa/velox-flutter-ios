import 'package:latlong2/latlong.dart';
import 'ride_choice.dart';

/// Représente les détails complets d'un trajet
class TripDetails {
  /// Constructeur
  const TripDetails({
    required this.departure,
    required this.destination,
    required this.departureAddress,
    required this.destinationAddress,
    required this.distance,
    required this.duration,
    required this.selectedRide,
  });

  /// Position de départ (GPS)
  final LatLng departure;

  /// Position d'arrivée (GPS)
  final LatLng destination;

  /// Adresse de départ
  final String departureAddress;

  /// Adresse de destination
  final String destinationAddress;

  /// Distance en kilomètres
  final double distance;

  /// Durée estimée en minutes
  final int duration;

  /// Véhicule sélectionné
  final RideChoice selectedRide;

  /// Prix total calculé
  double get totalPrice => selectedRide.calculatePrice(distance);

  /// Distance formatée (ex: "5.3 km")
  String get formattedDistance {
    return '${distance.toStringAsFixed(1)} km';
  }

  /// Durée formatée (ex: "12 min")
  String get formattedDuration {
    if (duration < 60) {
      return '$duration min';
    } else {
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      return '${hours}h ${minutes}min';
    }
  }

  /// Prix formaté (ex: "500 FDJ")
  String get formattedPrice {
    return '${totalPrice.toStringAsFixed(0)} FDJ';
  }

  /// Copie avec modifications
  TripDetails copyWith({
    LatLng? departure,
    LatLng? destination,
    String? departureAddress,
    String? destinationAddress,
    double? distance,
    int? duration,
    RideChoice? selectedRide,
  }) {
    return TripDetails(
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      departureAddress: departureAddress ?? this.departureAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      selectedRide: selectedRide ?? this.selectedRide,
    );
  }
}
