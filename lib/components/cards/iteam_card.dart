import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants.dart';
import '../small_dot.dart';
import '../../models/menu_item.dart';
import '../../models/promotion.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.menuItem,
    required this.press,
    this.promotion,
  });

  final MenuItem menuItem;
  final VoidCallback press;
  final Promotion? promotion;

  bool get _hasPromo => promotion != null;

  double get _discountedPrice => _hasPromo
      ? menuItem.price * (1 - promotion!.discountPercent / 100)
      : menuItem.price;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
          fontWeight: FontWeight.normal,
        );

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      onTap: press,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: SizedBox(
          height: 110,
          child: Row(
            children: [
              // ── Image + badge %-off ──────────────────────────────
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: (menuItem.imageUrl != null &&
                              menuItem.imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: menuItem.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (_, __) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child:
                                    const Icon(Icons.fastfood, size: 40),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.fastfood, size: 40),
                            ),
                    ),
                    // Badge -X% sur l'image
                    if (_hasPromo)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6EFF6E),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            '-${promotion!.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: defaultPadding),

              // ── Infos plat ───────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom
                    Text(
                      menuItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontSize: 18),
                    ),

                    // Chip "En promotion" + description (1 ligne)
                    // OU description seule (2 lignes)
                    if (_hasPromo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B3A1B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_offer_rounded,
                                  color: Color(0xFF6EFF6E),
                                  size: 10,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'En promotion · -${promotion!.discountPercent}%',
                                  style: const TextStyle(
                                    color: Color(0xFF6EFF6E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            menuItem.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    else
                      Text(
                        menuItem.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Ligne catégorie + temps + prix
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            menuItem.category,
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: defaultPadding / 2),
                          child: SmallDot(),
                        ),
                        Text(
                          '${menuItem.preparationTime} min',
                          style: textStyle,
                        ),
                        const Spacer(),
                        // Prix original barré (si promo)
                        if (_hasPromo) ...[
                          Text(
                            '${menuItem.price.toStringAsFixed(0)} FDJ',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Prix final
                        Text(
                          '${_discountedPrice.toStringAsFixed(0)} FDJ',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge!
                              .copyWith(color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
