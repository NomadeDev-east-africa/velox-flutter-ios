import 'package:cloud_firestore/cloud_firestore.dart';

import 'option_group.dart';

class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final int preparationTime; // en minutes
  final int discountPercentage; // 0 = aucune promo, 1-100 = % de réduction
  final List<OptionGroup> optionGroups; // options data-driven (vide = fallback)
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasDiscount => discountPercentage > 0 && discountPercentage <= 100;
  double get discountedPrice =>
      hasDiscount ? price * (1 - discountPercentage / 100) : price;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.preparationTime = 20,
    this.discountPercentage = 0,
    this.optionGroups = const [],
    required this.createdAt,
    this.updatedAt,
  });

  // Créer depuis Firestore
  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
      category: data['category'] ?? 'Autre',
      isAvailable: data['isAvailable'] ?? true,
      preparationTime: data['preparationTime'] ?? 20,
      discountPercentage: (data['discountPercentage'] ?? 0).toInt(),
      optionGroups: OptionGroup.listFromRaw(data['optionGroups']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
      'preparationTime': preparationTime,
      'discountPercentage': discountPercentage,
      'optionGroups': optionGroups.map((g) => g.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // CopyWith
  MenuItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    int? preparationTime,
    int? discountPercentage,
    List<OptionGroup>? optionGroups,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTime: preparationTime ?? this.preparationTime,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      optionGroups: optionGroups ?? this.optionGroups,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
