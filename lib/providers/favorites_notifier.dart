import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_notifier.dart';

// ═══════════════════════════════════════════════════════════════
// FavoritesNotifier — liste des IDs restaurants favoris
// Persisté dans Firestore : users/{uid}.favoriteRestaurants: []
// ═══════════════════════════════════════════════════════════════

class FavoritesNotifier extends StateNotifier<List<String>> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FavoritesNotifier(this._ref) : super([]) {
    _load();
  }

  String? get _uid => _ref.read(userNotifierProvider).userId;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;
      final raw = doc.data()?['favoriteRestaurants'];
      if (raw is List) {
        state = List<String>.from(raw);
      }
      debugPrint('✅ [Favorites] ${state.length} favoris chargés');
    } catch (e) {
      debugPrint('❌ [Favorites] load: $e');
    }
  }

  bool isFavorite(String restaurantId) => state.contains(restaurantId);

  Future<void> toggleFavorite(String restaurantId) async {
    final uid = _uid;
    if (uid == null) return;

    final isCurrentlyFav = isFavorite(restaurantId);
    // Mise à jour optimiste locale
    state = isCurrentlyFav
        ? state.where((id) => id != restaurantId).toList()
        : [...state, restaurantId];

    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'favoriteRestaurants': isCurrentlyFav
              ? FieldValue.arrayRemove([restaurantId])
              : FieldValue.arrayUnion([restaurantId]),
        },
        SetOptions(merge: true),
      );
      debugPrint(
        '✅ [Favorites] ${isCurrentlyFav ? 'Retiré' : 'Ajouté'}: $restaurantId',
      );
    } catch (e) {
      // Rollback si Firestore échoue
      state = isCurrentlyFav
          ? [...state, restaurantId]
          : state.where((id) => id != restaurantId).toList();
      debugPrint('❌ [Favorites] toggleFavorite: $e');
    }
  }
}

final favoritesNotifierProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>(
  (ref) => FavoritesNotifier(ref),
);
