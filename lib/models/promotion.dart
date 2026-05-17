import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String type; // "item" | "category"
  final String targetId;
  final String targetName;
  final String restaurantId;
  final int discountPercent;
  final String label;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;

  const Promotion({
    required this.id,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.restaurantId,
    required this.discountPercent,
    required this.label,
    required this.isActive,
    required this.startDate,
    this.endDate,
  });

  // Vérifie que la promo est active ET dans sa fenêtre temporelle
  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  // Correspond à un plat par ID Firestore OU par slug du nom
  bool matchesItem(String itemId, String itemName) {
    if (type != 'item' || !isCurrentlyActive) return false;
    final slug = itemName.toLowerCase().trim().replaceAll(' ', '_');
    return targetId == itemId || targetId == slug;
  }

  // Correspond à une catégorie par slug
  bool matchesCategory(String categoryName) {
    if (type != 'category' || !isCurrentlyActive) return false;
    final normalized = categoryName.toLowerCase().trim();
    return targetId == normalized ||
        targetId == normalized.replaceAll(' ', '_');
  }

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Promotion(
      id: doc.id,
      type: data['type'] ?? 'item',
      targetId: data['targetId'] ?? '',
      targetName: data['targetName'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      discountPercent: (data['discountPercent'] ?? 0).toInt(),
      label: data['label'] ?? '',
      isActive: data['isActive'] ?? false,
      startDate: parseDate(data['startDate']),
      endDate: data['endDate'] != null ? parseDate(data['endDate']) : null,
    );
  }
}
