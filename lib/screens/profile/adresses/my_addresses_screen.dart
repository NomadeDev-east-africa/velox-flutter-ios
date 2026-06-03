import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/theme/app_colors.dart';
import 'add_address_screen.dart';

class MyAddressesScreen extends ConsumerWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;
    final addressState = ref.watch(addressNotifierProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.onSurface,
        elevation: 0,
        title: Text(
          'Mes adresses',
          style: TextStyle(
            color: c.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_new, color: c.onSurface, size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: addressState.isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : addressState.addresses.isEmpty
              ? _buildEmptyState(c)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: addressState.addresses.length,
                  itemBuilder: (context, index) => _buildAddressCard(
                    context,
                    ref,
                    addressState.addresses[index],
                    c,
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddAddress(context, ref),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
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

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_off, size: 72, color: c.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune adresse enregistrée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Appuyez sur "Ajouter" pour enregistrer\nvotre première adresse',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
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
    AppColors c,
  ) {
    final typeColor = _typeColor(address.type, c);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: c.onSurface,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Par défaut',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: c.onSurfaceVariant),
                  color: c.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (_) => [
                    if (!address.isDefault)
                      _popupItem('default', Icons.star_outline, 'Définir par défaut', c: c),
                    _popupItem('edit', Icons.edit_outlined, 'Modifier', c: c),
                    _popupItem('delete', Icons.delete_outline, 'Supprimer',
                        isDestructive: true, c: c),
                  ],
                  onSelected: (value) =>
                      _handleAction(context, ref, value, address, c),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: c.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: c.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.onSurfaceVariant,
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
                  Icon(Icons.info_outline, size: 14, color: c.outlineVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.details,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.outlineVariant,
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
    required AppColors c,
  }) {
    final color = isDestructive ? Colors.redAccent : c.onSurface;
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
    AppColors c,
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
        _showDeleteDialog(context, ref, address, c);
        break;
    }
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, dynamic address, AppColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Supprimer l\'adresse',
          style: TextStyle(color: c.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${address.name}" ?',
          style: TextStyle(color: c.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: c.onSurfaceVariant)),
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

  Color _typeColor(String type, AppColors c) {
    switch (type) {
      case 'home': return const Color(0xFF6AB2E1);
      case 'work': return const Color(0xFFFFA726);
      default:     return c.primary;
    }
  }
}
