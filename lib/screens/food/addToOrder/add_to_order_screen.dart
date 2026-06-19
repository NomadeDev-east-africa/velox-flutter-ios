import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/menu_item.dart';
import '../../../models/option_group.dart';
import '../../../models/option_selection.dart';
import '../../../models/restaurant.dart';
import '../../../models/extra_option.dart';
import '../../../models/sauce_option.dart';
import '../../../models/order_item.dart';
import '../../../providers/all_providers.dart';
import '../../../theme/app_colors.dart';

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
  late AppColors _c;

  int                     _quantity = 1;
  final List<ExtraOption> _extras   = [];
  final List<SauceOption> _sauces   = [];

  /// Sélections par groupe (aligné sur `menuItem.optionGroups`).
  /// Pour un groupe `single`, le Set contient 0 ou 1 index ; pour `multiple`, 0..N.
  final List<Set<int>> _groupSelections = [];

  List<OptionGroup> get _optionGroups => widget.menuItem.optionGroups;
  bool get _isDataDriven => _optionGroups.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isDataDriven) {
      _initializeOptionGroups();
    } else {
      _initializeExtrasAndSauces();
    }
  }

  /// Initialise les sélections data-driven. Présélectionne le 1er choix d'un
  /// groupe `single + required` pour qu'un choix soit toujours valide.
  void _initializeOptionGroups() {
    for (final group in _optionGroups) {
      final selected = <int>{};
      if (group.isSingle && group.required && group.choices.isNotEmpty) {
        selected.add(0);
      }
      _groupSelections.add(selected);
    }
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

  int get _optionsSurcharge => _isDataDriven
      ? OptionSelection.surcharge(_optionGroups, _groupSelections)
      : (_extrasTotal + _saucesTotal);

  int get _totalPrice =>
      ((widget.menuItem.price + _optionsSurcharge) * _quantity).toInt();

  // ── SÉLECTION DATA-DRIVEN ───────────────────────────────────────────────────

  void _toggleChoice(int groupIndex, int choiceIndex) {
    final group = _optionGroups[groupIndex];
    final selected = _groupSelections[groupIndex];
    setState(() {
      if (group.isSingle) {
        // Radio : un seul choix. Si requis, on ne peut pas désélectionner.
        if (selected.contains(choiceIndex) && !group.required) {
          selected.clear();
        } else {
          selected
            ..clear()
            ..add(choiceIndex);
        }
      } else {
        // Checkbox : 0..N choix.
        if (selected.contains(choiceIndex)) {
          selected.remove(choiceIndex);
        } else {
          selected.add(choiceIndex);
        }
      }
    });
  }

  /// Premier groupe requis sans sélection, ou `null` si tout est valide.
  OptionGroup? _firstUnsatisfiedRequiredGroup() {
    for (var gi = 0; gi < _optionGroups.length; gi++) {
      final group = _optionGroups[gi];
      if (group.required && _groupSelections[gi].isEmpty) return group;
    }
    return null;
  }

  // ── LOGIQUE PANIER ────────────────────────────────────────────────────────

  void _proceedAddToCart() {
    if (_isDataDriven) {
      final missing = _firstUnsatisfiedRequiredGroup();
      if (missing != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Veuillez choisir : ${missing.name}'),
            backgroundColor: _c.surfaceHigh,
            behavior: SnackBarBehavior.floating,
          ));
        return;
      }
    }
    final cart = ref.read(cartProvider);
    if (cart.isDifferentRestaurant(widget.restaurant.id)) {
      _showDifferentRestaurantDialog(cart.selectedRestaurant?.name);
    } else {
      _addItemToCart();
      Navigator.pop(context);
    }
  }

  void _showDifferentRestaurantDialog(String? currentRestaurantName) {
    final c = _c;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('Restaurant différent',
            style: TextStyle(color: c.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Vous avez déjà des articles de '
          '"${currentRestaurantName ?? "un autre restaurant"}". '
          'Voulez-vous vider votre panier et ajouter cet article '
          'de "${widget.restaurant.name}" ?',
          style: TextStyle(color: c.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Annuler', style: TextStyle(color: c.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _clearCartAndAddNewItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
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
    ref.read(cartProvider.notifier).clearCart();
    ref.read(cartProvider.notifier).setRestaurant(widget.restaurant);
    _addItemToCart();
    Navigator.pop(context);
  }

  void _addItemToCart() {
    final cart = ref.read(cartProvider);
    if (cart.selectedRestaurant == null) {
      ref.read(cartProvider.notifier).setRestaurant(widget.restaurant);
    }

    // Reverser les choix dans extras/sauces pour rester lisible par l'app resto.
    final List<ExtraOption> extras;
    final List<SauceOption> sauces;
    if (_isDataDriven) {
      final mapping = OptionSelection.toCart(_optionGroups, _groupSelections);
      extras = mapping.extras;
      sauces = mapping.sauces;
    } else {
      extras = _extras.where((e) => e.isSelected).toList();
      sauces = _sauces.where((s) => s.isSelected).toList();
    }

    final orderItem = OrderItem(
      menuId:      widget.menuItem.id,
      name:        widget.menuItem.name,
      description: widget.menuItem.description,
      imageUrl:    widget.menuItem.imageUrl ?? '',
      category:    widget.menuItem.category,
      basePrice:   widget.menuItem.price.toInt(),
      quantity:    _quantity,
      extras:      extras,
      sauces:      sauces,
    );
    ref.read(cartProvider.notifier).addItem(orderItem);
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
          hasImage
              ? CachedNetworkImage(
                  imageUrl: widget.menuItem.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: _c.surfaceHigh,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _c.primary, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _c.surfaceHigh,
                    child: Icon(Icons.fastfood, color: _c.onSurfaceVariant, size: 60),
                  ),
                )
              : Container(
                  color: _c.surfaceHigh,
                  child: Icon(Icons.fastfood, color: _c.onSurfaceVariant, size: 60),
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
                    _c.bg.withValues(alpha: 0.5),
                    _c.bg,
                  ],
                  stops: const [0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),
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
                    color: _c.primary.withValues(alpha: 0.15),
                    border: Border.all(color: _c.primary.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'AVAILABLE_UNIT_01',
                    style: TextStyle(
                      color: _c.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.menuItem.name.toUpperCase(),
                  style: TextStyle(
                    color: _c.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (widget.menuItem.description.isNotEmpty)
                  Text(
                    widget.menuItem.description,
                    style: TextStyle(color: _c.onSurfaceVariant, fontSize: 13),
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
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _c.primary, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BASE COST',
                  style: TextStyle(
                    color: _c.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.menuItem.price.toStringAsFixed(1)} FDJ',
                  style: TextStyle(
                    color: _c.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: _c.surfaceHigh,
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
                    style: TextStyle(
                      color: _c.onSurface,
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
        color: onTap != null ? _c.surface : _c.surfaceLow,
        child: Icon(icon,
            color: onTap != null ? _c.onSurface : _c.outlineVariant, size: 18),
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
                style: TextStyle(
                  color: _c.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              if (required)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _c.primary.withValues(alpha: 0.12),
                    border: Border.all(color: _c.primary.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: _c.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: _c.outlineVariant.withValues(alpha: 0.3), height: 1),
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
            bottom: BorderSide(color: _c.outlineVariant.withValues(alpha: 0.2)),
          ),
          color: extra.isSelected
              ? _c.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: extra.isSelected ? _c.primary : Colors.transparent,
                border: Border.all(
                  color: extra.isSelected ? _c.primary : _c.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: extra.isSelected
                  ? Icon(Icons.check, color: _c.onPrimary, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                extra.name.toUpperCase(),
                style: TextStyle(
                  color: extra.isSelected ? _c.onSurface : _c.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              '+ ${extra.price} FDJ',
              style: TextStyle(
                color: extra.isSelected ? _c.primary : _c.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RENDU DATA-DRIVEN ───────────────────────────────────────────────────────

  Widget _buildGroupSection(int groupIndex) {
    final group = _optionGroups[groupIndex];
    final title = group.name.trim().isEmpty
        ? 'OPTIONS'
        : group.name.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, required: group.required),
        ...List.generate(
          group.choices.length,
          (ci) => _buildChoiceRow(groupIndex, ci),
        ),
      ],
    );
  }

  Widget _buildChoiceRow(int groupIndex, int choiceIndex) {
    final group    = _optionGroups[groupIndex];
    final choice   = group.choices[choiceIndex];
    final selected = _groupSelections[groupIndex].contains(choiceIndex);
    final isSingle = group.isSingle;

    return GestureDetector(
      onTap: () => _toggleChoice(groupIndex, choiceIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _c.outlineVariant.withValues(alpha: 0.2)),
          ),
          color: selected ? _c.primary.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            // Radio (cercle) pour single, checkbox (carré) pour multiple.
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: isSingle ? BoxShape.circle : BoxShape.rectangle,
                color: selected ? _c.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? _c.primary : _c.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: _c.onPrimary, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                choice.name.toUpperCase(),
                style: TextStyle(
                  color: selected ? _c.onSurface : _c.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              choice.price > 0 ? '+ ${choice.price} FDJ' : 'INCLUS',
              style: TextStyle(
                color: choice.price > 0
                    ? (selected ? _c.primary : _c.onSurfaceVariant)
                    : _c.onSurfaceVariant,
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
                color: _c.surfaceHigh,
                border: Border.all(
                  color: sauce.isSelected
                      ? _c.primary
                      : _c.outlineVariant.withValues(alpha: 0.3),
                  width: sauce.isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: sauce.isSelected ? _c.primary : Colors.transparent,
                      border: Border.all(
                        color: sauce.isSelected ? _c.primary : _c.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: sauce.isSelected
                        ? Icon(Icons.check, color: _c.onPrimary, size: 11)
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
                          style: TextStyle(
                            color: _c.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${sauce.price} FDJ',
                          style: TextStyle(
                            color: _c.onSurfaceVariant,
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
      color: _c.bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        onTap: _proceedAddToCart,
        child: Container(
          height: 56,
          color: _c.primary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'AJOUTER AU PANIER ($_totalPrice FDJ)',
                style: TextStyle(
                  color: _c.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.bolt_rounded, color: _c.onPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    _c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: AppBar(
        backgroundColor: _c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _c.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.restaurant.name.toUpperCase(),
          style: TextStyle(
            color: _c.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined, color: _c.onSurfaceVariant),
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
                  if (_isDataDriven)
                    ...List.generate(
                        _optionGroups.length, _buildGroupSection)
                  else ...[
                    _buildSectionHeader('CHOIX DES EXTRAS', required: true),
                    ..._extras.map(_buildExtraItem),
                    _buildSectionHeader('CHOIX DES SAUCES'),
                    _buildSauceGrid(),
                  ],
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
