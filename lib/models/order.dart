import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'order_item.dart';

/// Modèle commande food — camelCase + toJson/fromJson Hive
/// PHASE 1 : ajout toJson() / fromJson() pour persistance Hive
///   GeoPoint → {'lat': ..., 'lng': ...} pour JSON local
///   Timestamp → int (ms since epoch) pour JSON local
class Order {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImageUrl;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final int deliveryFee;
  final String status;
  final String paymentMethod;
  final String deliveryAddress;

  final GeoPoint? deliveryLocation;
  final String? addressDetails;

  final Timestamp createdAt;
  final Timestamp updatedAt;

  final String? deliveryDriverId;
  final String? deliveryDriverName;
  final Timestamp? acceptedAt;
  final Timestamp? readyAt;
  final Timestamp? pickedUpAt;
  final Timestamp? deliveredAt;
  final Timestamp? cancelledAt;
  final String? cancellationReason;
  final int? estimatedPreparationTime;

  // ─── Statuts ─────────────────────────────────────────────────

  static const String statusPending    = 'pending';
  static const String statusConfirmed  = 'confirmed';
  static const String statusAccepted   = 'accepted';
  static const String statusPreparing  = 'preparing';
  static const String statusReady      = 'ready';
  static const String statusDelivering = 'delivering';
  static const String statusCompleted  = 'completed';
  static const String statusCancelled  = 'cancelled';

  Order({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImageUrl,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.deliveryFee,
    required this.status,
    required this.paymentMethod,
    required this.deliveryAddress,
    this.deliveryLocation,
    this.addressDetails,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryDriverId,
    this.deliveryDriverName,
    this.acceptedAt,
    this.readyAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    this.estimatedPreparationTime,
  });

  // ─── Getters calculés ────────────────────────────────────────

  int get itemCount  => items.fold(0, (acc, item) => acc + item.quantity);
  int get subtotal   => items.fold(0, (acc, item) => acc + item.totalPrice);
  int get total      => subtotal + deliveryFee;

  bool get canBeCancelled =>
      status == statusPending ||
      status == statusConfirmed ||
      status == statusAccepted ||
      status == statusPreparing ||
      status == statusReady;

  bool get isCompleted =>
      status == statusCompleted || status == statusCancelled;

  bool get isActive =>
      status != statusCompleted && status != statusCancelled;

  LatLng? get deliveryLocationAsLatLng {
    if (deliveryLocation == null) return null;
    return LatLng(
        deliveryLocation!.latitude, deliveryLocation!.longitude);
  }

  // ════════════════════════════════════════════════════════════
  // FIRESTORE
  // ════════════════════════════════════════════════════════════

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantImageUrl': restaurantImageUrl,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toMap()).toList(),
      'itemCount': itemCount,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': status,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

    if (deliveryLocation != null) {
      map['deliveryLocation'] = deliveryLocation;
    }
    if (addressDetails != null && addressDetails!.isNotEmpty) {
      map['addressDetails'] = addressDetails;
    }
    if (deliveryDriverId != null) map['deliveryDriverId'] = deliveryDriverId;
    if (deliveryDriverName != null) {
      map['deliveryDriverName'] = deliveryDriverName;
    }
    if (acceptedAt != null) map['acceptedAt'] = acceptedAt;
    if (readyAt != null) map['readyAt'] = readyAt;
    if (pickedUpAt != null) map['pickedUpAt'] = pickedUpAt;
    if (deliveredAt != null) map['deliveredAt'] = deliveredAt;
    if (cancelledAt != null) map['cancelledAt'] = cancelledAt;
    if (cancellationReason != null) {
      map['cancellationReason'] = cancellationReason;
    }
    if (estimatedPreparationTime != null) {
      map['estimatedPreparationTime'] = estimatedPreparationTime;
    }

    return map;
  }

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Order(
      id: doc.id,
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      restaurantImageUrl: data['restaurantImageUrl'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      items: data['items'] is List
          ? (data['items'] as List<dynamic>)
              .whereType<Map>()
              .map((item) =>
                  OrderItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : [],
      deliveryFee: data['deliveryFee'] ?? 500,
      status: data['status'] ?? statusPending,
      paymentMethod: data['paymentMethod'] ?? 'cash',
      deliveryAddress: data['deliveryAddress'] ?? '',
      deliveryLocation: data['deliveryLocation'] as GeoPoint?,
      addressDetails: data['addressDetails'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      deliveryDriverId: data['deliveryDriverId'],
      deliveryDriverName: data['deliveryDriverName'],
      acceptedAt: data['acceptedAt'] as Timestamp?,
      readyAt: data['readyAt'] as Timestamp?,
      pickedUpAt: data['pickedUpAt'] as Timestamp?,
      deliveredAt: data['deliveredAt'] as Timestamp?,
      cancelledAt: data['cancelledAt'] as Timestamp?,
      cancellationReason: data['cancellationReason'],
      estimatedPreparationTime: data['estimatedPreparationTime'],
    );
  }

  // ════════════════════════════════════════════════════════════
  // HIVE — JSON local
  // Timestamp → int (ms since epoch)
  // GeoPoint  → {'lat': double, 'lng': double}
  // ════════════════════════════════════════════════════════════

  /// Sérialiser pour Hive
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantImageUrl': restaurantImageUrl,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'deliveryFee': deliveryFee,
      'status': status,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress,
      'addressDetails': addressDetails,
      // GeoPoint → Map simple
      'deliveryLocation': deliveryLocation != null
          ? {
              'lat': deliveryLocation!.latitude,
              'lng': deliveryLocation!.longitude,
            }
          : null,
      // Timestamp → int ms
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deliveryDriverId': deliveryDriverId,
      'deliveryDriverName': deliveryDriverName,
      'acceptedAt': acceptedAt?.millisecondsSinceEpoch,
      'readyAt': readyAt?.millisecondsSinceEpoch,
      'pickedUpAt': pickedUpAt?.millisecondsSinceEpoch,
      'deliveredAt': deliveredAt?.millisecondsSinceEpoch,
      'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
      'cancellationReason': cancellationReason,
      'estimatedPreparationTime': estimatedPreparationTime,
    };
  }

  /// Désérialiser depuis Hive
  factory Order.fromJson(Map<String, dynamic> json) {
    // GeoPoint reconstruction
    GeoPoint? geoPoint;
    if (json['deliveryLocation'] != null) {
      final loc =
          Map<String, dynamic>.from(json['deliveryLocation'] as Map);
      geoPoint = GeoPoint(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    }

    // Helper int → Timestamp
    Timestamp? tsFromMs(dynamic ms) {
      if (ms == null) return null;
      return Timestamp.fromMillisecondsSinceEpoch(ms as int);
    }

    return Order(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      restaurantImageUrl: json['restaurantImageUrl'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(
                    Map<String, dynamic>.from(item as Map)))
              .toList() ??
          [],
      deliveryFee: json['deliveryFee'] ?? 500,
      status: json['status'] ?? statusPending,
      paymentMethod: json['paymentMethod'] ?? 'cash',
      deliveryAddress: json['deliveryAddress'] ?? '',
      addressDetails: json['addressDetails'],
      deliveryLocation: geoPoint,
      createdAt: Timestamp.fromMillisecondsSinceEpoch(
          json['createdAt'] ?? 0),
      updatedAt: Timestamp.fromMillisecondsSinceEpoch(
          json['updatedAt'] ?? 0),
      deliveryDriverId: json['deliveryDriverId'],
      deliveryDriverName: json['deliveryDriverName'],
      acceptedAt: tsFromMs(json['acceptedAt']),
      readyAt: tsFromMs(json['readyAt']),
      pickedUpAt: tsFromMs(json['pickedUpAt']),
      deliveredAt: tsFromMs(json['deliveredAt']),
      cancelledAt: tsFromMs(json['cancelledAt']),
      cancellationReason: json['cancellationReason'],
      estimatedPreparationTime: json['estimatedPreparationTime'],
    );
  }

  // ─── copyWith ────────────────────────────────────────────────

  Order copyWith({
    String? id,
    String? userId,
    String? restaurantId,
    String? restaurantName,
    String? restaurantImageUrl,
    String? customerName,
    String? customerPhone,
    List<OrderItem>? items,
    int? deliveryFee,
    String? status,
    String? paymentMethod,
    String? deliveryAddress,
    GeoPoint? deliveryLocation,
    String? addressDetails,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? deliveryDriverId,
    String? deliveryDriverName,
    Timestamp? acceptedAt,
    Timestamp? readyAt,
    Timestamp? pickedUpAt,
    Timestamp? deliveredAt,
    Timestamp? cancelledAt,
    String? cancellationReason,
    int? estimatedPreparationTime,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantImageUrl: restaurantImageUrl ?? this.restaurantImageUrl,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      addressDetails: addressDetails ?? this.addressDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryDriverId: deliveryDriverId ?? this.deliveryDriverId,
      deliveryDriverName: deliveryDriverName ?? this.deliveryDriverName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      readyAt: readyAt ?? this.readyAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      estimatedPreparationTime:
          estimatedPreparationTime ?? this.estimatedPreparationTime,
    );
  }

  // ─── Statut UI ───────────────────────────────────────────────

  static String getStatusText(String status) {
    switch (status) {
      case statusPending:    return 'En attente';
      case statusConfirmed:
      case statusAccepted:   return 'Confirmée';
      case statusPreparing:  return 'En préparation';
      case statusReady:      return 'Prête';
      case statusDelivering: return 'En livraison';
      case statusCompleted:  return 'Livrée';
      case statusCancelled:  return 'Annulée';
      default:               return 'Inconnu';
    }
  }

  static String getStatusColor(String status) {
    switch (status) {
      case statusPending:    return '#FF9800';
      case statusConfirmed:
      case statusAccepted:
      case statusPreparing:
      case statusReady:      return '#2196F3';
      case statusDelivering: return '#9C27B0';
      case statusCompleted:  return '#4CAF50';
      case statusCancelled:  return '#F44336';
      default:               return '#757575';
    }
  }
}
