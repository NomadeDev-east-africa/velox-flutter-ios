import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/components/floating_cart_button.dart';
import 'package:nomade_client/models/menu_item.dart';
import 'package:nomade_client/models/restaurant.dart';
import 'package:nomade_client/screens/food/details/details_screen.dart';
import 'package:nomade_client/screens/food/featured/featurred_screen.dart';
import 'package:nomade_client/screens/food/filter/filter_screen.dart';
import 'package:nomade_client/screens/food/home_food/components/promotion_banner.dart';
import 'package:nomade_client/services/menu_service.dart';
import 'package:nomade_client/services/restaurant_service.dart';
import 'package:nomade_client/translations/app_translations.dart';
import 'package:nomade_client/providers/restaurant_notifier.dart';

// Kinetic Monolith design system
const _bg               = Color(0xFF0E0E0E);
const _surface          = Color(0xFF1A1919);
const _surfaceHigh      = Color(0xFF20201F);
const _primary          = Color(0xFF9FFF88);
const _onSurface        = Color(0xFFFFFFFF);
const _onSurfaceVariant = Color(0xFFADAAAA);
const _outlineVariant   = Color(0xFF484847);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(restaurantNotifierProvider);
      if (state.restaurants.isEmpty && !state.isLoading) {
        ref.read(restaurantNotifierProvider.notifier).loadAll();
      }
    });
  }

  Future<void> _refresh() async {
    await ref.read(restaurantNotifierProvider.notifier).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.location_on, color: _onSurfaceVariant, size: 12),
                SizedBox(width: 3),
                Text(
                  'LIVRER À',
                  style: TextStyle(
                    color: _onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const Text(
              'Ville de Djibouti',
              style: TextStyle(
                color: _onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FilterScreen()),
            ),
            child: const Text(
              'Filtrer',
              style: TextStyle(
                color: _primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          backgroundColor: _surface,
          onRefresh: _refresh,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      context,
                      'Par catégories',
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FeaturedScreen())),
                    ),
                    const SizedBox(height: 12),
                    const _CategoryHorizontalSection(),
                    const SizedBox(height: 24),
                    const PromotionBanner(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context,
                      'Meilleurs choix',
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FeaturedScreen())),
                    ),
                    const SizedBox(height: 12),
                    _PopularSection(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, tr('all_restaurants'), () {}),
                    const SizedBox(height: 12),
                    _AllRestaurantsSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: FloatingCartButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onSeeAll) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: const Text(
            'Voir tout',
            style: TextStyle(
              color: _primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Catégories ─────────────────────────────────────────────────────────────

class _CategoryHorizontalSection extends StatefulWidget {
  const _CategoryHorizontalSection();

  @override
  State<_CategoryHorizontalSection> createState() =>
      _CategoryHorizontalSectionState();
}

class _CategoryHorizontalSectionState
    extends State<_CategoryHorizontalSection> {
  final MenuService _menuService = MenuService();
  final RestaurantService _restaurantService = RestaurantService();
  Map<String, MenuItem> _categoryMenus = {};
  Map<String, Restaurant?> _categoryRestaurants = {};
  List<String> _categoryKeys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final allMenus = await _menuService.getAllMenus();
      if (!mounted) return;
      if (allMenus.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final Map<String, List<MenuItem>> byCategory = {};
      for (final m in allMenus) {
        byCategory.putIfAbsent(m.category, () => []).add(m);
      }
      final rng = Random();
      final Map<String, MenuItem> picked = {};
      for (final entry in byCategory.entries) {
        final withImg = entry.value
            .where((m) => m.imageUrl != null && m.imageUrl!.isNotEmpty)
            .toList();
        if (withImg.isNotEmpty) {
          picked[entry.key] = withImg[rng.nextInt(withImg.length)];
        }
      }
      final entries = picked.entries.toList();
      final uniqueIds = entries.map((e) => e.value.restaurantId).toSet().toList();
      final fetched = await Future.wait(
        uniqueIds.map((id) => _restaurantService.getRestaurantById(id)),
      );
      final restaurantById = {
        for (var i = 0; i < uniqueIds.length; i++) uniqueIds[i]: fetched[i],
      };
      final Map<String, Restaurant?> restaurants = {
        for (final e in entries) e.key: restaurantById[e.value.restaurantId],
      };
      if (!mounted) return;
      setState(() {
        _categoryMenus = picked;
        _categoryRestaurants = restaurants;
        _categoryKeys = picked.keys.toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 5,
          itemBuilder: (_, _) => Container(
            width: 88,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    if (_categoryMenus.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categoryKeys.length,
        itemBuilder: (context, index) {
          final category = _categoryKeys[index];
          final menu = _categoryMenus[category]!;
          final restaurant = _categoryRestaurants[category];
          final imageUrl = menu.imageUrl;
          final hasImage = imageUrl != null && imageUrl.isNotEmpty;

          return GestureDetector(
            onTap: () {
              if (restaurant != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailsScreen(restaurant: restaurant),
                  ),
                );
              }
            },
            child: Container(
              width: 88,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _surface,
                border: Border.all(
                  color: _outlineVariant.withValues(alpha: 0.15),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: (88 * MediaQuery.of(context).devicePixelRatio).toInt(),
                        placeholder: (_, _) =>
                            Container(color: _surfaceHigh),
                        errorWidget: (_, _, _) => Container(
                          color: _surfaceHigh,
                          child: const Icon(Icons.fastfood,
                              size: 28, color: _onSurfaceVariant),
                        ),
                      )
                    else
                      Container(
                        color: _surfaceHigh,
                        child: const Icon(Icons.fastfood,
                            size: 28, color: _onSurfaceVariant),
                      ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 8,
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Meilleurs choix ────────────────────────────────────────────────────────

class _PopularSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularRestaurantsProvider);
    final loading = ref.watch(restaurantsLoadingProvider);

    if (loading && popular.isEmpty) {
      return SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          itemBuilder: (_, _) => Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (popular.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: popular.length,
        itemBuilder: (context, index) {
          final r = popular[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailsScreen(restaurant: r)),
            ),
            child: Container(
              width: 200,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _outlineVariant.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: r.imageUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: (200 * MediaQuery.of(context).devicePixelRatio).toInt(),
                      memCacheHeight: (130 * MediaQuery.of(context).devicePixelRatio).toInt(),
                      placeholder: (_, _) =>
                          Container(height: 130, color: _surfaceHigh),
                      errorWidget: (_, _, _) => Container(
                        height: 130,
                        color: _surfaceHigh,
                        child: const Icon(Icons.restaurant,
                            size: 40, color: _onSurfaceVariant),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: _primary, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              r.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time,
                                color: _onSurfaceVariant, size: 12),
                            const SizedBox(width: 3),
                            const Text(
                              '25 min',
                              style: TextStyle(
                                color: _onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
}

// ─── Tous les restaurants ───────────────────────────────────────────────────

class _AllRestaurantsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(allRestaurantsProvider);
    final loading = ref.watch(restaurantsLoadingProvider);

    if (loading && restaurants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (restaurants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Aucun restaurant disponible',
            style: TextStyle(color: _onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: restaurants.length,
      itemBuilder: (_, i) => _DarkRestaurantCard(restaurant: restaurants[i]),
    );
  }
}

class _DarkRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const _DarkRestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(restaurant: restaurant),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _outlineVariant.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: restaurant.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: MediaQuery.of(context).size.width.toInt(),
                  placeholder: (_, _) =>
                      Container(color: _surfaceHigh),
                  errorWidget: (_, _, _) => Container(
                    color: _surfaceHigh,
                    child: const Icon(Icons.restaurant,
                        size: 60, color: _onSurfaceVariant),
                  ),
                ),
              ),
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: _primary, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    restaurant.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildChip(
                          Icons.access_time_rounded, '25 min'),
                      _buildChip(
                          Icons.delivery_dining_rounded, 'Livraison gratuite'),
                      _buildChip(
                          Icons.receipt_long_rounded,
                          '${restaurant.totalOrders} commandes'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _onSurfaceVariant, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
