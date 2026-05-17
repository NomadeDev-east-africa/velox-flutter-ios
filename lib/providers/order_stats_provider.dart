import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_notifier.dart';

class OrderStats {
  final int totalOrders;
  final double totalSpent;

  const OrderStats({this.totalOrders = 0, this.totalSpent = 0.0});

  int get loyaltyPoints => totalOrders * 10;
}

/// Stream temps réel des stats commandes du client connecté.
/// Compte uniquement les commandes avec status == "completed".
final orderStatsProvider = StreamProvider.autoDispose<OrderStats>((ref) {
  final userId = ref.watch(userNotifierProvider).userId;

  if (userId == null) {
    return Stream.value(const OrderStats());
  }

  return FirebaseFirestore.instance
      .collection('orders')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snapshot) {
    final count = snapshot.docs.length;
    final total = snapshot.docs.fold<double>(
      0.0,
      (acc, doc) {
        final data = doc.data();
        return acc + ((data['total'] ?? 0) as num).toDouble();
      },
    );
    return OrderStats(totalOrders: count, totalSpent: total);
  });
});
