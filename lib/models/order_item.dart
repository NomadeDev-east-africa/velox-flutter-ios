import 'extra_option.dart';
import 'sauce_option.dart';

/// Item de commande food
/// PHASE 1 : ajout toJson() / fromJson() pour Hive
class OrderItem {
  final String menuId;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final int basePrice;
  int quantity;
  List<ExtraOption> extras;
  List<SauceOption> sauces;

  OrderItem({
    required this.menuId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.basePrice,
    this.quantity = 1,
    List<ExtraOption>? extras,
    List<SauceOption>? sauces,
  })  : extras = extras ?? [],
        sauces = sauces ?? [];

  // ─── Calculs ─────────────────────────────────────────────────

  int get extrasTotal =>
      extras.where((e) => e.isSelected).fold(0, (sum, e) => sum + e.price);

  int get saucesTotal =>
      sauces.where((s) => s.isSelected).fold(0, (sum, s) => sum + s.price);

  int get unitPrice => basePrice + extrasTotal + saucesTotal;
  int get totalPrice => unitPrice * quantity;

  List<ExtraOption> get selectedExtras =>
      extras.where((e) => e.isSelected).toList();

  List<SauceOption> get selectedSauces =>
      sauces.where((s) => s.isSelected).toList();

  // ─── Firestore ───────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'menuId': menuId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'basePrice': basePrice,
      'quantity': quantity,
      'extras': extras.map((e) => e.toMap()).toList(),
      'sauces': sauces.map((s) => s.toMap()).toList(),
      'extrasTotal': extrasTotal,
      'saucesTotal': saucesTotal,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuId: map['menuId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      basePrice: (map['basePrice'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      extras: map['extras'] != null
          ? (map['extras'] as List)
              .map((e) => ExtraOption.fromMap(
                    Map<String, dynamic>.from(e as Map)))
              .toList()
          : [],
      sauces: map['sauces'] != null
          ? (map['sauces'] as List)
              .map((s) => SauceOption.fromMap(
                    Map<String, dynamic>.from(s as Map)))
              .toList()
          : [],
    );
  }

  // ─── Hive (JSON local) ───────────────────────────────────────
  // toJson() == toMap() ici car tous les types sont déjà primitifs

  /// Sérialiser pour Hive — identique à toMap() car pas de Timestamp
  Map<String, dynamic> toJson() => toMap();

  /// Désérialiser depuis Hive — identique à fromMap()
  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      OrderItem.fromMap(json);

  // ─── CopyWith ────────────────────────────────────────────────

  OrderItem copyWith({
    String? menuId,
    String? name,
    String? description,
    String? imageUrl,
    String? category,
    int? basePrice,
    int? quantity,
    List<ExtraOption>? extras,
    List<SauceOption>? sauces,
  }) {
    return OrderItem(
      menuId: menuId ?? this.menuId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      basePrice: basePrice ?? this.basePrice,
      quantity: quantity ?? this.quantity,
      extras: extras ?? this.extras,
      sauces: sauces ?? this.sauces,
    );
  }

  @override
  String toString() =>
      'OrderItem(name: $name, qty: $quantity, total: $totalPrice FDJ)';
}
