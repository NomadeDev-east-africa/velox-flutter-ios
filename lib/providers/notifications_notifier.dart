import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool push;
  final bool orders;
  final bool promos;

  const NotificationSettings({
    required this.push,
    required this.orders,
    required this.promos,
  });

  NotificationSettings copyWith({bool? push, bool? orders, bool? promos}) =>
      NotificationSettings(
        push: push ?? this.push,
        orders: orders ?? this.orders,
        promos: promos ?? this.promos,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationSettings> {
  static const _kPush   = 'notif_push';
  static const _kOrders = 'notif_orders';
  static const _kPromos = 'notif_promos';

  NotificationsNotifier()
      : super(const NotificationSettings(push: true, orders: true, promos: false)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = NotificationSettings(
      push:   prefs.getBool(_kPush)   ?? true,
      orders: prefs.getBool(_kOrders) ?? true,
      promos: prefs.getBool(_kPromos) ?? false,
    );
  }

  Future<void> setPush(bool value) async {
    state = state.copyWith(push: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPush, value);
  }

  Future<void> setOrders(bool value) async {
    state = state.copyWith(orders: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOrders, value);
  }

  Future<void> setPromos(bool value) async {
    state = state.copyWith(promos: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromos, value);
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationSettings>(
  (ref) => NotificationsNotifier(),
);
