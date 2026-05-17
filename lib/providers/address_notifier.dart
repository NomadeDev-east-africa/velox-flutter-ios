import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════
// MODÈLE
// ═══════════════════════════════════════════════════════════════

class AddressModel {
  final String id;
  final String name;
  final String address;
  final String details;
  final String type; // 'home' | 'work' | 'other'
  final double latitude;
  final double longitude;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.name,
    required this.address,
    this.details = '',
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });

  factory AddressModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AddressModel(
      id:        id,
      name:      data['name']      as String? ?? '',
      address:   data['address']   as String? ?? '',
      details:   data['details']   as String? ?? '',
      type:      data['type']      as String? ?? 'other',
      latitude:  (data['latitude']  as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      isDefault: data['isDefault'] as bool?   ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'address':   address,
    'details':   details,
    'type':      type,
    'latitude':  latitude,
    'longitude': longitude,
    'isDefault': isDefault,
  };

  AddressModel copyWith({bool? isDefault}) => AddressModel(
    id:        id,
    name:      name,
    address:   address,
    details:   details,
    type:      type,
    latitude:  latitude,
    longitude: longitude,
    isDefault: isDefault ?? this.isDefault,
  );
}

// ═══════════════════════════════════════════════════════════════
// ÉTAT
// ═══════════════════════════════════════════════════════════════

class AddressState {
  final List<AddressModel> addresses;
  final bool isLoading;
  final String? error;

  const AddressState({
    this.addresses = const [],
    this.isLoading = false,
    this.error,
  });

  AddressState copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    String? error,
  }) =>
      AddressState(
        addresses: addresses ?? this.addresses,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ═══════════════════════════════════════════════════════════════
// NOTIFIER
// ═══════════════════════════════════════════════════════════════

class AddressNotifier extends StateNotifier<AddressState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth      _auth      = FirebaseAuth.instance;

  AddressNotifier() : super(const AddressState()) {
    loadAddresses();
  }

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('addresses');
  }

  // ── CHARGER ──────────────────────────────────────────────────

  Future<void> loadAddresses() async {
    final col = _col;
    if (col == null) {
      if (mounted) state = state.copyWith(isLoading: false);
      return;
    }

    if (mounted) state = state.copyWith(isLoading: true);

    try {
      final snapshot = await col.orderBy('createdAt').get();
      final addresses = snapshot.docs
          .map((doc) => AddressModel.fromFirestore(doc.id, doc.data()))
          .toList();

      if (mounted) state = state.copyWith(addresses: addresses, isLoading: false);
      debugPrint('✅ [AddressNotifier] ${addresses.length} adresse(s) chargée(s)');
    } catch (e) {
      debugPrint('❌ [AddressNotifier] loadAddresses: $e');
      if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── AJOUTER ──────────────────────────────────────────────────

  Future<void> addAddress(Map<String, dynamic> data) async {
    final col = _col;
    if (col == null) return;

    try {
      // Première adresse → automatiquement par défaut
      final isFirst   = state.addresses.isEmpty;
      final toWrite   = {
        ...data,
        'isDefault': isFirst,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef    = await col.add(toWrite);
      final newAddr   = AddressModel.fromFirestore(docRef.id, {
        ...data,
        'isDefault': isFirst,
      });

      if (mounted) {
        state = state.copyWith(addresses: [...state.addresses, newAddr]);
      }
      debugPrint('✅ [AddressNotifier] Adresse ajoutée: ${newAddr.name}');
    } catch (e) {
      debugPrint('❌ [AddressNotifier] addAddress: $e');
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // ── MODIFIER ─────────────────────────────────────────────────

  Future<void> updateAddress(String id, Map<String, dynamic> data) async {
    final col = _col;
    if (col == null) return;

    try {
      await col.doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updated = state.addresses.map((a) {
        if (a.id != id) return a;
        return AddressModel.fromFirestore(id, {...a.toMap(), ...data});
      }).toList();

      if (mounted) state = state.copyWith(addresses: updated);
      debugPrint('✅ [AddressNotifier] Adresse modifiée: $id');
    } catch (e) {
      debugPrint('❌ [AddressNotifier] updateAddress: $e');
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // ── SUPPRIMER ────────────────────────────────────────────────

  Future<void> deleteAddress(String id) async {
    final col = _col;
    if (col == null) return;

    try {
      final wasDefault = state.addresses
          .firstWhere((a) => a.id == id, orElse: () => const AddressModel(
            id: '', name: '', address: '', type: 'other',
            latitude: 0, longitude: 0, isDefault: false,
          ))
          .isDefault;

      await col.doc(id).delete();
      final updated = state.addresses.where((a) => a.id != id).toList();

      // Si on supprimait la default → mettre la première restante par défaut
      if (wasDefault && updated.isNotEmpty) {
        if (mounted) state = state.copyWith(addresses: updated);
        await setDefault(updated.first.id);
        return;
      }

      if (mounted) state = state.copyWith(addresses: updated);
      debugPrint('✅ [AddressNotifier] Adresse supprimée: $id');
    } catch (e) {
      debugPrint('❌ [AddressNotifier] deleteAddress: $e');
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // ── DÉFINIR PAR DÉFAUT ───────────────────────────────────────

  Future<void> setDefault(String id) async {
    final col = _col;
    if (col == null) return;

    try {
      final batch = _firestore.batch();
      for (final addr in state.addresses) {
        batch.update(col.doc(addr.id), {'isDefault': addr.id == id});
      }
      await batch.commit();

      final updated = state.addresses
          .map((a) => a.copyWith(isDefault: a.id == id))
          .toList();

      if (mounted) state = state.copyWith(addresses: updated);
      debugPrint('✅ [AddressNotifier] Adresse par défaut: $id');
    } catch (e) {
      debugPrint('❌ [AddressNotifier] setDefault: $e');
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════════════

final addressNotifierProvider =
    StateNotifierProvider<AddressNotifier, AddressState>(
  (ref) => AddressNotifier(),
);
