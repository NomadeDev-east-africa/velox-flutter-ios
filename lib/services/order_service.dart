import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'orders';

  // Créer une nouvelle commande
  Future<String?> createOrder(Order order) async {
    try {
      debugPrint('🛒 [OrderService] Création de la commande...');

      final docRef = await _firestore.collection(_collection).add(order.toMap());

      debugPrint('✅ [OrderService] Commande créée: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur création commande: $e');
      return null;
    }
  }

  // Récupérer une commande par ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(orderId).get();

      if (doc.exists) {
        return Order.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur récupération commande: $e');
      return null;
    }
  }

  // Récupérer les commandes d'un utilisateur
  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();

      // Tri local par date (plus récent en premier)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur récupération commandes utilisateur: $e');
      return [];
    }
  }

  // Stream des commandes d'un utilisateur
  Stream<List<Order>> streamUserOrders(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();

      // Tri local par date
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    });
  }

  // Récupérer les commandes d'un restaurant
  Future<List<Order>> getRestaurantOrders(String restaurantId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      final orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();

      // Tri local par date
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur récupération commandes restaurant: $e');
      return [];
    }
  }

  // Stream des commandes d'un restaurant
  Stream<List<Order>> streamRestaurantOrders(String restaurantId) {
    return _firestore
        .collection(_collection)
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();

      // Tri local par date
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return orders;
    });
  }

  // Mettre à jour le statut d'une commande
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('✅ [OrderService] Statut mis à jour: $status');
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur mise à jour statut: $e');
      return false;
    }
  }

  // Annuler une commande
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'status':      Order.statusCancelled,
        'cancelledBy': 'customer',
        'cancelledAt': Timestamp.now(),
        'updatedAt':   Timestamp.now(),
      });
      debugPrint('✅ [OrderService] Commande annulée: $orderId');
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur annulation: $e');
      return false;
    }
  }

  // Récupérer les commandes en attente
  Future<List<Order>> getPendingOrders() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: Order.statusPending)
          .get();

      return snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur récupération commandes en attente: $e');
      return [];
    }
  }

  // Supprimer une commande (admin seulement)
  Future<bool> deleteOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).delete();
      debugPrint('✅ [OrderService] Commande supprimée: $orderId');
      return true;
    } catch (e) {
      debugPrint('❌ [OrderService] Erreur suppression commande: $e');
      return false;
    }
  }
}