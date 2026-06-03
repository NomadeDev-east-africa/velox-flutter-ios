import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/models/restaurant.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/theme/app_colors.dart';
import 'package:nomade_client/screens/food/details/details_screen.dart';

class FavoriteRestaurantsScreen extends ConsumerWidget {
  const FavoriteRestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;

    final favoriteIds  = ref.watch(favoritesNotifierProvider);
    final allRestaurants = ref.watch(allRestaurantsProvider);
    final favorites = allRestaurants
        .where((r) => favoriteIds.contains(r.id))
        .toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.onSurface,
        elevation: 0,
        title: Text(
          'Restaurants favoris',
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
      body: favorites.isEmpty
          ? _buildEmpty(c)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: favorites.length,
              itemBuilder: (context, i) => _buildCard(context, ref, favorites[i], c),
            ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────

  Widget _buildEmpty(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, size: 60, color: Colors.redAccent),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun favori',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur ♥ sur un restaurant\npour l\'ajouter à vos favoris',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Carte restaurant ──────────────────────────────────────────

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    Restaurant restaurant,
    AppColors c,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsScreen(restaurant: restaurant)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              child: CachedNetworkImage(
                imageUrl: restaurant.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  width: 90,
                  height: 90,
                  color: c.surfaceHigh,
                  child: Icon(Icons.restaurant, color: c.primary, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: c.primary, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        restaurant.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: restaurant.isOpen
                              ? c.primary.withValues(alpha: 0.1)
                              : c.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          restaurant.isOpen ? 'Ouvert' : 'Fermé',
                          style: TextStyle(
                            fontSize: 11,
                            color: restaurant.isOpen ? c.primary : c.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.address,
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
              onPressed: () => ref
                  .read(favoritesNotifierProvider.notifier)
                  .toggleFavorite(restaurant.id),
            ),
          ],
        ),
      ),
    );
  }
}
