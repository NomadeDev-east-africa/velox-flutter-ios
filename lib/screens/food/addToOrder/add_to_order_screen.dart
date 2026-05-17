import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/menu_item.dart';
import '../../../models/restaurant.dart';
import '../../../models/extra_option.dart';
import '../../../models/sauce_option.dart';
import '../../../models/order_item.dart';
import '../../../providers/all_providers.dart';

// Kinetic Monolith palette
const _bg          = Color(0xFF0E0E0E);
const _surfaceLow  = Color(0xFF131313);
const _surface     = Color(0xFF1A1919);
const _surfaceHigh = Color(0xFF20201F);
const _primary     = Color(0xFF9FFF88);
const _onPrimary   = Color(0xFF026400);
const _onSurface   = Color(0xFFFFFFFF);
const _onVariant   = Color(0xFFADAAAA);
const _outline     = Color(0xFF484847);

class AddToOrderScreen extends ConsumerStatefulWidget {
  final MenuItem   menuItem;
  final Restaurant restaurant;

  const AddToOrderScreen({
    super.key,
    required this.menuItem,
    required this.restaurant,
  });

  @override
  ConsumerState<AddToOrderScreen> createState() => _AddToOrderScreenState();
}

class _AddToOrderScreenState extends ConsumerState<AddToOrderScreen> {
  int                   _quantity = 1;
  final List<ExtraOption> _extras = [];
  final List<SauceOption> _sauces = [];

  @override
  void initState() {
    super.initState();
    _initializeExtrasAndSauces();
  }

  void _initializeExtrasAndSauces() {
    _extras.addAll([
      ExtraOption(name: 'Frites',     price: 500),
      ExtraOption(name: 'Tomates',    price: 500),
      ExtraOption(name: 'Oignons',    price: 500),
      ExtraOption(name: 'Salade',     price: 500),
      ExtraOption(name: 'Taille L',   price: 500),
      ExtraOption(name: 'Taille XL',  price: 500),
      ExtraOption(name: 'Taille XXL', price: 500),
    ]);
    _sauces.addAll([
      SauceOption(name: 'Samouraï',   price: 50),
      SauceOption(name: 'Mayonnaise', price: 50),
      SauceOption(name: 'Ketchup',    price: 50),
      SauceOption(name: 'Barbecue',   price: 50),
      SauceOption(name: 'Harissa',    price: 50),
      SauceOption(name: 'Moutarde',   price: 50),
    ]);
  }

  int get _extrasTotal =>
      _extras.where((e) => e.isSelected).fold(0, (s, e) => s + e.price);
  int get _saucesTotal =>
      _sauces.where((s) => s.isSelected).fold(0, (s, e) => s + e.price);
  int get _totalPrice =>
      ((widget.menuItem.price + _extrasTotal + _saucesTotal) * _quantity).toInt();

  // ── LOGIQUE PANIER ────────────────────────────────────────────────────────

  void _proceedAddToCart() {
    final cart = ref.read(cartProvider);
    debugPrint('🔍 [AddToOrder] Vérification avant ajout...');
    debugPrint('  - Restaurant panier: ${cart.selectedRestaurant?.name ?? "null"}');
    debugPrint('  - Restaurant nouveau: ${widget.restaurant.name}');
    debugPrint('  - isDifferent: ${cart.isDifferentRestaurant(widget.restaurant.id)}');

    if (cart.isDifferentRestaurant(widget.restaurant.id)) {
      debugPrint('⚠️ [AddToOrder] Restaurant différent → Dialog');
      _showDifferentRestaurantDialog(cart.selectedRestaurant?.name);
    } else {
      debugPrint('✅ [AddToOrder] OK → Ajouter item');
      _addItemToCart();
      Navigator.pop(context);
    }
  }

  void _showDifferentRestaurantDialog(String? currentRestaurantName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Restaurant différent',
            style: TextStyle(color: _onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Vous avez déjà des articles de '
          '"${currentRestaurantName ?? "un autre restaurant"}". '
          'Voulez-vous vider votre panier et ajouter cet article '
          'de "${widget.restaurant.name}" ?',
          style: const TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('❌ [AddToOrder] Annulé');
              Navigator.pop(dialogContext);
            },
            child: const Text('Annuler', style: TextStyle(color: _onVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('✅ [AddToOrder] Vider panier accepté');
              Navigator.pop(dialogContext);
              _clearCartAndAddNewItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Vider le panier',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearCartAndAddNewItem() {
    debugPrint('🗑️ [AddToOrder] Vider et ajouter nouveau');
    ref.read(cartProvider.notifier).clearCart();
    ref.read(cartProvider.notifier).setRestaurant(widget.restaurant);
    _addItemToCart();
    Navigator.pop(context);
  }

  void _addItemToCart() {
    final cart = ref.read(cartProvider);
    debugPrint('➕ [AddToOrder] _addItemToCart()');
    debugPrint('  - Restaurant avant: ${cart.selectedRestaurant?.name ?? "null"}');

    if (cart.selectedRestaurant == null) {
      debugPrint('  - Définir restaurant: ${widget.restaurant.name}');
      ref.read(cartProvider.notifier).setRestaurant(widget.restaurant);
    }

    final orderItem = OrderItem(
      menuId:      widget.menuItem.id,
      name:        widget.menuItem.name,
      description: widget.menuItem.description,
      imageUrl:    widget.menuItem.imageUrl ?? '',
      category:    widget.menuItem.category,
      basePrice:   widget.menuItem.price.toInt(),
      quantity:    _quantity,
      extras:      _extras.where((e) => e.isSelected).toList(),
      sauces:      _sauces.where((s) => s.isSelected).toList(),
    );

    ref.read(cartProvider.notifier).addItem(orderItem);
    debugPrint('✅ [AddToOrder] Item ajouté: ${widget.menuItem.name}');
    debugPrint('  - Restaurant après: ${ref.read(cartProvider).selectedRestaurant?.name}');
  }

  // ── UI COMPONENTS ─────────────────────────────────────────────────────────

  Widget _buildHeroImage() {
    final hasImage = widget.menuItem.imageUrl != null &&
        widget.menuItem.imageUrl!.isNotEmpty;

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          hasImage
              ? CachedNetworkImage(
                  imageUrl: widget.menuItem.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: _surfaceHigh,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: _primary, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _surfaceHigh,
                    child: const Icon(Icons.fastfood, color: _onVariant, size: 60),
                  ),
                )
              : Container(
                  color: _surfaceHigh,
                  child: const Icon(Icons.fastfood, color: _onVariant, size: 60),
                ),
          // Gradient overlay bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _bg.withValues(alpha: 0.5),
                    _bg,
                  ],
                  stops: const [0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // "AVAILABLE" chip + name overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.15),
                    border: Border.all(color: _primary.withValues(alpha: 0.6)),
                  ),
                  child: const Text(
                    'AVAILABLE_UNIT_01',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.menuItem.name.toUpperCase(),
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (widget.menuItem.description.isNotEmpty)
                  Text(
                    widget.menuItem.description,
                    style: const TextStyle(color: _onVariant, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndQuantity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          // Price with left green border
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: _primary, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BASE COST',
                  style: TextStyle(
                    color: _onVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.menuItem.price.toStringAsFixed(1)} FDJ',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Quantity controller
          Container(
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _buildQtyButton(
                  icon: Icons.remove,
                  onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Container(
                  width: 48,
                  alignment: Alignment.center,
                  child: Text(
                    _quantity.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _buildQtyButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _quantity++),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        color: onTap != null ? _surface : _surfaceLow,
        child: Icon(icon,
            color: onTap != null ? _onSurface : _outline, size: 18),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _onVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              if (required)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    border: Border.all(color: _primary.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: _outline.withValues(alpha: 0.3), height: 1),
        ],
      ),
    );
  }

  Widget _buildExtraItem(ExtraOption extra) {
    return GestureDetector(
      onTap: () => setState(() => extra.isSelected = !extra.isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _outline.withValues(alpha: 0.2)),
          ),
          color: extra.isSelected
              ? _primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Checkbox carré
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: extra.isSelected ? _primary : Colors.transparent,
                border: Border.all(
                  color: extra.isSelected ? _primary : _outline,
                  width: 1.5,
                ),
              ),
              child: extra.isSelected
                  ? const Icon(Icons.check, color: _onPrimary, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                extra.name.toUpperCase(),
                style: TextStyle(
                  color: extra.isSelected ? _onSurface : _onVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              '+ ${extra.price} FDJ',
              style: TextStyle(
                color: extra.isSelected ? _primary : _onVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSauceGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _sauces.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.8,
        ),
        itemBuilder: (context, index) {
          final sauce = _sauces[index];
          return GestureDetector(
            onTap: () => setState(() => sauce.isSelected = !sauce.isSelected),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                border: Border.all(
                  color: sauce.isSelected ? _primary : _outline.withValues(alpha: 0.3),
                  width: sauce.isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: sauce.isSelected ? _primary : Colors.transparent,
                      border: Border.all(
                        color: sauce.isSelected ? _primary : _outline,
                        width: 1.5,
                      ),
                    ),
                    child: sauce.isSelected
                        ? const Icon(Icons.check, color: _onPrimary, size: 11)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sauce.name.toUpperCase(),
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${sauce.price} FDJ',
                          style: const TextStyle(
                            color: _onVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddToCartButton() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        onTap: _proceedAddToCart,
        child: Container(
          height: 56,
          color: _primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'AJOUTER AU PANIER ($_totalPrice FDJ)',
                style: const TextStyle(
                  color: _onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.bolt_rounded, color: _onPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.restaurant.name.toUpperCase(),
          style: const TextStyle(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: _onVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(),
                  _buildPriceAndQuantity(),
                  _buildSectionHeader('CHOIX DES EXTRAS', required: true),
                  ..._extras.map(_buildExtraItem),
                  _buildSectionHeader('CHOIX DES SAUCES'),
                  _buildSauceGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildAddToCartButton(),
        ],
      ),
    );
  }
}
