import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// Represents a place (destination, departure, saved place, etc.)
class Place {
  /// Constructeur
  const Place({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.type = PlaceType.search,
    this.icon,
    this.distance,
  });

  /// ID unique du lieu
  final String id;

  /// Nom du lieu
  final String name;

  /// Coordonnées GPS du lieu
  final LatLng location;

  /// Adresse complète (optionnelle)
  final String? address;

  /// Type de lieu (récent, sauvegardé, recherche)
  final PlaceType type;

  /// Icône associée au lieu
  final IconData? icon;

  /// Distance depuis la position actuelle (en km)
  final double? distance;

  /// Copie avec modifications
  Place copyWith({
    String? id,
    String? name,
    LatLng? location,
    String? address,
    PlaceType? type,
    IconData? icon,
    double? distance,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      address: address ?? this.address,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      distance: distance ?? this.distance,
    );
  }
}

/// Types de lieux
enum PlaceType {
  /// Lieu de recherche
  search,

  /// Lieu récent
  recent,

  /// Lieu sauvegardé (Maison, Travail, etc.)
  saved,

  /// Suggestion
  suggestion,
}
