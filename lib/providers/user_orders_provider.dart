import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/models/order.dart';
import 'package:nomade_client/services/order_service.dart';
import 'user_notifier.dart';

final userOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final userId = ref.watch(userNotifierProvider).userId;
  if (userId == null) return Stream.value([]);
  return OrderService().streamUserOrders(userId);
});
