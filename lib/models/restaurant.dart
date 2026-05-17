import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id;
  final String name;
  final String address;
  final String description;
  final String email;
  final String phone;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalOrders;
  final double totalRevenue;
  final bool isActive;
  final bool isOpen;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.email,
    required this.phone,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.isActive = true,
    this.isOpen = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Créer depuis Firestore
  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      description: data['description'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalOrders: data['totalOrders'] ?? 0,
      totalRevenue: (data['totalRevenue'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
      isOpen: data['isOpen'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'description': description,
      'email': email,
      'phone': phone,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'isActive': isActive,
      'isOpen': isOpen,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // CopyWith
  Restaurant copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    String? email,
    String? phone,
    String? imageUrl,
    double? latitude,
    double? longitude,
    double? rating,
    int? totalOrders,
    double? totalRevenue,
    bool? isActive,
    bool? isOpen,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      isActive: isActive ?? this.isActive,
      isOpen: isOpen ?? this.isOpen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
