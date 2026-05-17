import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _menusCollection = 'menu_items'; // Collection séparée !

  // Stream de tous les menus d'un restaurant
  Stream<List<MenuItem>> streamMenus(String restaurantId) {
    return _firestore
        .collection(_menusCollection)
        .where('restaurantId', isEqualTo: restaurantId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final menus = snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();

      // Tri local par catégorie
      menus.sort((a, b) => a.category.compareTo(b.category));

      return menus;
    });
  }

  // Récupérer tous les menus de tous les restaurants
  Future<List<MenuItem>> getAllMenus() async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('isAvailable', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération de tous les menus: $e');
      return [];
    }
  }

  // Récupérer tous les menus d'un restaurant
  Future<List<MenuItem>> getMenusByRestaurant(String restaurantId) async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isAvailable', isEqualTo: true)
          .get();

      // Tri local au lieu de orderBy pour éviter index
      final menus = snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();

      menus.sort((a, b) => a.category.compareTo(b.category));

      return menus;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des menus: $e');
      return [];
    }
  }

  // Récupérer un menu par ID
  Future<MenuItem?> getMenuById(String menuId) async {
    try {
      final doc =
      await _firestore.collection(_menusCollection).doc(menuId).get();

      if (doc.exists) {
        return MenuItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du menu: $e');
      return null;
    }
  }

  // Récupérer les menus par catégorie
  Future<List<MenuItem>> getMenusByCategory(
      String restaurantId, String category) async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isAvailable', isEqualTo: true)
          .where('category', isEqualTo: category)
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des menus par catégorie: $e');
      return [];
    }
  }

  // Récupérer toutes les catégories uniques d'un restaurant
  Future<List<String>> getCategories(String restaurantId) async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final categories = snapshot.docs
          .map((doc) => (doc.data()['category'] ?? 'Autre') as String)
          .toSet()
          .toList();

      return categories;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des catégories: $e');
      return [];
    }
  }

  // Récupérer les menus featured (les premiers ou les plus populaires)
  Future<List<MenuItem>> getFeaturedMenus(String restaurantId,
      {int limit = 3}) async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des menus featured: $e');
      return [];
    }
  }

  // Rechercher des menus par nom
  Future<List<MenuItem>> searchMenus(String restaurantId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_menusCollection)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final menus = snapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .where((menu) =>
      menu.name.toLowerCase().contains(query.toLowerCase()) ||
          menu.description.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return menus;
    } catch (e) {
      debugPrint('Erreur lors de la recherche de menus: $e');
      return [];
    }
  }

  // Calculer le temps de préparation moyen d'un restaurant
  Future<int> getAveragePreparationTime(String restaurantId) async {
    try {
      final menus = await getMenusByRestaurant(restaurantId);
      if (menus.isEmpty) return 25; // Valeur par défaut

      final totalTime =
      menus.fold(0, (acc, menu) => acc + menu.preparationTime);
      return (totalTime / menus.length).round();
    } catch (e) {
      debugPrint('Erreur lors du calcul du temps moyen: $e');
      return 25;
    }
  }
}