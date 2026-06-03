import 'package:cloud_firestore/cloud_firestore.dart';
import 'ride_location.dart';

/// Modèle complet d'une course taxi — camelCase + toJson/fromJson Hive
/// PHASE 1 : ajout toJson() / fromJson() pour persistance Hive
class Ride {
  final String rideId;

  // Participants
  final String userId;
  final String userName;
  final String? userPhone;
  final String? userPhotoUrl;

  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final String? vehicleId;

  // Locations
  final RideLocation pickup;
  final RideLocation destination;

  // Trip info
  final double distance;
  final int estimatedDuration;
  final double estimatedFare;
  final double? finalFare;

  // Type de véhicule
  final String vehicleType;

  // Status
  final RideStatus status;

  // Timing
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // Payment
  final String paymentMethod;
  final PaymentStatus paymentStatus;

  // Rating
  final int? userRating;
  final String? userReview;
  final int? driverRating;
  final String? driverReview;

  // Cancellation
  final String? cancellationReason;
  final String? cancelledBy;

  const Ride({
    required this.rideId,
    required this.userId,
    required this.userName,
    this.userPhone,
    this.userPhotoUrl,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPhotoUrl,
    this.vehicleId,
    required this.pickup,
    required this.destination,
    required this.distance,
    required this.estimatedDuration,
    required this.estimatedFare,
    this.finalFare,
    required this.vehicleType,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.userRating,
    this.userReview,
    this.driverRating,
    this.driverReview,
    this.cancellationReason,
    this.cancelledBy,
  });

  // ════════════════════════════════════════════════════════════
  // FIRESTORE
  // ════════════════════════════════════════════════════════════

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw FormatException('Document Firestore vide: ${doc.id}');
    }

    if (!data.containsKey('userId') ||
        data['userId'] == null ||
        (data['userId'] as String).isEmpty) {
      throw FormatException('userId manquant dans la course ${doc.id}');
    }

    if (!data.containsKey('pickup') || data['pickup'] == null) {
      throw FormatException('pickup manquant dans la course ${doc.id}');
    }

    if (!data.containsKey('destination') || data['destination'] == null) {
      throw FormatException('destination manquante dans la course ${doc.id}');
    }

    if (!data.containsKey('requestedAt') || data['requestedAt'] == null) {
      throw FormatException('requestedAt manquant dans la course ${doc.id}');
    }

    return Ride(
      rideId: doc.id,
      userId: data['userId'],
      userName: data['userName'] ?? 'Utilisateur',
      userPhone: data['userPhone'],
      userPhotoUrl: data['userPhotoUrl'],
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      driverPhotoUrl: data['driverPhotoUrl'],
      vehicleId: data['vehicleId'],
      pickup: RideLocation.fromMap(data['pickup']),
      destination: RideLocation.fromMap(data['destination']),
      distance: (data['distance'] ?? 0.0).toDouble(),
      estimatedDuration: data['estimatedDuration'] ?? 0,
      estimatedFare: (data['estimatedFare'] ?? 0.0).toDouble(),
      finalFare: data['finalFare'] != null
          ? (data['finalFare'] as num).toDouble()
          : null,
      vehicleType: data['vehicleType'] ?? 'standard',
      status: _parseRideStatus(data['status']),
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      arrivedAt: data['arrivedAt'] != null
          ? (data['arrivedAt'] as Timestamp).toDate()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: _parsePaymentStatus(data['paymentStatus']),
      userRating: data['userRating'],
      userReview: data['userReview'],
      driverRating: data['driverRating'],
      driverReview: data['driverReview'],
      cancellationReason: data['cancellationReason'],
      cancelledBy: data['cancelledBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userPhotoUrl': userPhotoUrl,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverPhotoUrl': driverPhotoUrl,
      'vehicleId': vehicleId,
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'distance': distance,
      'estimatedDuration': estimatedDuration,
      'estimatedFare': estimatedFare,
      'finalFare': finalFare,
      'vehicleType': vehicleType,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'acceptedAt':
          acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'arrivedAt':
          arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,
      'startedAt':
          startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus.name,
      'userRating': userRating,
      'userReview': userReview,
      'driverRating': driverRating,
      'driverReview': driverReview,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
    };
  }

  // ════════════════════════════════════════════════════════════
  // HIVE — JSON local (types primitifs UNIQUEMENT)
  // Timestamp → int (ms since epoch)
  // Enum → String (name)
  // RideLocation → Map<String, dynamic>
  // ════════════════════════════════════════════════════════════

  /// Sérialiser pour Hive (stockage local)
  Map<String, dynamic> toJson() {
    return {
      'rideId': rideId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userPhotoUrl': userPhotoUrl,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverPhotoUrl': driverPhotoUrl,
      'vehicleId': vehicleId,
      'pickup': pickup.toJson(),
      'destination': destination.toJson(),
      'distance': distance,
      'estimatedDuration': estimatedDuration,
      'estimatedFare': estimatedFare,
      'finalFare': finalFare,
      'vehicleType': vehicleType,
      // Enum → String
      'status': status.name,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus.name,
      // DateTime → int (ms since epoch)
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'acceptedAt': acceptedAt?.millisecondsSinceEpoch,
      'arrivedAt': arrivedAt?.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
      // Rating
      'userRating': userRating,
      'userReview': userReview,
      'driverRating': driverRating,
      'driverReview': driverReview,
      // Annulation
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
    };
  }

  /// Désérialiser depuis Hive
  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      rideId: json['rideId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Utilisateur',
      userPhone: json['userPhone'],
      userPhotoUrl: json['userPhotoUrl'],
      driverId: json['driverId'],
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      driverPhotoUrl: json['driverPhotoUrl'],
      vehicleId: json['vehicleId'],
      pickup: RideLocation.fromJson(
          Map<String, dynamic>.from(json['pickup'])),
      destination: RideLocation.fromJson(
          Map<String, dynamic>.from(json['destination'])),
      distance: (json['distance'] ?? 0.0).toDouble(),
      estimatedDuration: json['estimatedDuration'] ?? 0,
      estimatedFare: (json['estimatedFare'] ?? 0.0).toDouble(),
      finalFare: json['finalFare'] != null
          ? (json['finalFare'] as num).toDouble()
          : null,
      vehicleType: json['vehicleType'] ?? 'standard',
      // String → Enum
      status: _parseRideStatus(json['status']),
      paymentMethod: json['paymentMethod'] ?? 'cash',
      paymentStatus: _parsePaymentStatus(json['paymentStatus']),
      // int (ms) → DateTime
      requestedAt: DateTime.fromMillisecondsSinceEpoch(
          json['requestedAt'] ?? 0),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['acceptedAt'])
          : null,
      arrivedAt: json['arrivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['arrivedAt'])
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'])
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['cancelledAt'])
          : null,
      userRating: json['userRating'],
      userReview: json['userReview'],
      driverRating: json['driverRating'],
      driverReview: json['driverReview'],
      cancellationReason: json['cancellationReason'],
      cancelledBy: json['cancelledBy'],
    );
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  static RideStatus _parseRideStatus(String? status) {
    if (status == null || status.isEmpty) {
      throw FormatException('Status de course null ou vide');
    }
    switch (status) {
      case 'requested':
      // Variantes de compatibilité Cloud Functions (PENDING_STATUSES)
      case 'pending':
      case 'waiting':
      case 'new':
      case 'created':
        return RideStatus.requested;
      case 'accepted':
        return RideStatus.accepted;
      case 'arriving':
        return RideStatus.arriving;
      case 'arrived':
        return RideStatus.arrived;
      case 'started':
        return RideStatus.started;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      case 'no_driver_available':
      case 'noDriverAvailable':
        return RideStatus.noDriverAvailable;
      default:
        throw FormatException(
          'Statut inconnu: "$status". '
          'Valides: requested, accepted, arriving, arrived, '
          'started, completed, cancelled, noDriverAvailable',
        );
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }

  // ─── Getters utiles ──────────────────────────────────────────

  /// Course active = ni terminée, ni annulée, ni sans chauffeur
  bool get isActive =>
      status != RideStatus.completed &&
      status != RideStatus.cancelled &&
      status != RideStatus.noDriverAvailable;

  bool get isArrivingSoon => status == RideStatus.arriving;

  bool get isCompleted => status == RideStatus.completed;
  bool get isCancelled => status == RideStatus.cancelled;
  bool get isWaitingForDriver => status == RideStatus.requested;
  bool get hasDriver => driverId != null;

  // ─── copyWith ────────────────────────────────────────────────

  Ride copyWith({
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPhotoUrl,
    String? vehicleId,
    double? finalFare,
    RideStatus? status,
    DateTime? acceptedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    PaymentStatus? paymentStatus,
    int? userRating,
    String? userReview,
    int? driverRating,
    String? driverReview,
    String? cancellationReason,
    String? cancelledBy,
  }) {
    return Ride(
      rideId: rideId,
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      userPhotoUrl: userPhotoUrl,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      vehicleId: vehicleId ?? this.vehicleId,
      pickup: pickup,
      destination: destination,
      distance: distance,
      estimatedDuration: estimatedDuration,
      estimatedFare: estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      vehicleType: vehicleType,
      status: status ?? this.status,
      requestedAt: requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      userRating: userRating ?? this.userRating,
      userReview: userReview ?? this.userReview,
      driverRating: driverRating ?? this.driverRating,
      driverReview: driverReview ?? this.driverReview,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════

enum RideStatus {
  requested,          // Demandée — recherche driver en cours
  accepted,           // Acceptée par driver (en route)
  arriving,           // Driver en approche du pickup
  arrived,            // Driver arrivé au pickup
  started,            // Course commencée
  completed,          // Course terminée
  cancelled,          // Course annulée
  noDriverAvailable,  // Aucun driver trouvé (Cloud Functions)
}

enum PaymentStatus {
  pending,
  completed,
  failed,
}
