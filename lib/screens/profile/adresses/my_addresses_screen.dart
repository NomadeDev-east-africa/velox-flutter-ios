import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'add_address_screen.dart';

// Kinetic Monolith design system
const _bg              = Color(0xFF0E0E0E);
const _surface         = Color(0xFF1A1919);
const _surfaceHigh     = Color(0xFF20201F);
const _primary         = Color(0xFF9FFF88);
const _onPrimary       = Color(0xFF026400);
const _onSurface       = Color(0xFFFFFFFF);
const _onSurfaceVariant= Color(0xFFADAAAA);
const _outlineVariant  = Color(0xFF484847);

class MyAddressesScreen extends ConsumerWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressState = ref.watch(addressNotifierProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _onSurface,
        elevation: 0,
        title: const Text(
          'Mes adresses',
          style: TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: _onSurface, size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: addressState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : addressState.addresses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: addressState.addresses.length,
                  itemBuilder: (context, index) => _buildAddressCard(
                    context,
                    ref,
                    addressState.addresses[index],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddAddress(context, ref),
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        icon: const Icon(Icons.add_location_alt),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────

  Future<void> _navigateToAddAddress(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? existing,
    String? existingId,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(existingAddress: existing),
      ),
    );

    if (result == null) return;

    if (existingId != null) {
      await ref.read(addressNotifierProvider.notifier).updateAddress(existingId, result);
    } else {
      await ref.read(addressNotifierProvider.notifier).addAddress(result);
    }
  }

  // ── Empty state ───────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off, size: 72, color: _primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune adresse enregistrée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Appuyez sur "Ajouter" pour enregistrer\nvotre première adresse',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Carte adresse ─────────────────────────────────────────────

  Widget _buildAddressCard(
    BuildContext context,
    WidgetRef ref,
    dynamic address,
  ) {
    final typeColor = _typeColor(address.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(address.type), color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        address.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _onSurface,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Par défaut',
                            style: TextStyle(
                              fontSize: 11,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: _onSurfaceVariant),
                  color: _surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (_) => [
                    if (!address.isDefault)
                      _popupItem('default', Icons.star_outline, 'Définir par défaut'),
                    _popupItem('edit', Icons.edit_outlined, 'Modifier'),
                    _popupItem('delete', Icons.delete_outline, 'Supprimer', isDestructive: true),
                  ],
                  onSelected: (value) => _handleAction(context, ref, value, address),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: _outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: _onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (address.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: _outlineVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.details,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : _onSurface;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    dynamic address,
  ) {
    switch (action) {
      case 'default':
        ref.read(addressNotifierProvider.notifier).setDefault(address.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adresse définie par défaut'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        break;

      case 'edit':
        _navigateToAddAddress(
          context,
          ref,
          existing: {
            'name':      address.name,
            'address':   address.address,
            'details':   address.details,
            'type':      address.type,
            'latitude':  address.latitude,
            'longitude': address.longitude,
            'isDefault': address.isDefault,
          },
          existingId: address.id,
        );
        break;

      case 'delete':
        _showDeleteDialog(context, ref, address);
        break;
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic address) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Supprimer l\'adresse',
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${address.name}" ?',
          style: const TextStyle(color: _onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: _onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(addressNotifierProvider.notifier)
                  .deleteAddress(address.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse supprimée'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  IconData _typeIcon(String type) {
    switch (type) {
      case 'home': return Icons.home_outlined;
      case 'work': return Icons.work_outline;
      default:     return Icons.location_on_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'home': return const Color(0xFF6AB2E1);
      case 'work': return const Color(0xFFFFA726);
      default:     return _primary;
    }
  }
}
