import 'package:flutter/foundation.dart';

/// Stub — toutes les notifications FCM sont gérées directement par les CF :
/// - onTaxiRideCreated : offre aux drivers
/// - acceptRideTx      : driver accepté (au client)
/// - onRideUpdated     : arrived, started, completed, cancelled
class DriverNotificationService {
  Future<void> notifyAvailableDrivers({
    required String rideId,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
  }) async {
    debugPrint('ℹ️ [DriverNotif] FCM géré par onTaxiRideCreated (CF)');
  }

  Future<void> notifyRideAccepted({
    required String userId,
    required String driverName,
    required String driverPhone,
  }) async {
    debugPrint('ℹ️ [DriverNotif] FCM géré par acceptRideTx (CF)');
  }

  Future<void> notifyDriverArrived({
    required String userId,
    required String driverName,
  }) async {
    debugPrint('ℹ️ [DriverNotif] FCM géré par onRideUpdated (CF)');
  }

  Future<void> notifyRideStarted({required String userId}) async {
    debugPrint('ℹ️ [DriverNotif] FCM géré par onRideUpdated (CF)');
  }
}
