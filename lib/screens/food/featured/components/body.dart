import 'package:flutter/material.dart';
import '/../components/scalton/big_card_scalton.dart';
import '/../../constants.dart';
import '/../../services/restaurant_service.dart';
import '/../../services/menu_service.dart';
import '/../../models/menu_item.dart';
import '/../../models/restaurant.dart';
import '../../details/details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  final MenuService _menuService = MenuService();
  final RestaurantService _restaurantService = RestaurantService();
  Map<String, MenuItem> _categoryMenus = {};
  Map<String, Restaurant?> _categoryRestaurants = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoryMenus();
    });
  }

  Future<void> _loadCategoryMenus() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // 1. Charger tous les menus depuis Firestore
      final allMenus = await _menuService.getAllMenus();

      if (!mounted) return;

      if (allMenus.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Regrouper par catégorie
      final Map<String, List<MenuItem>> menusByCategory = {};
      for (var menu in allMenus) {
        menusByCategory.putIfAbsent(menu.category, () => []).add(menu);
      }

      // 3. Prendre un menu aléatoire par catégorie (avec image)
      final random = Random();
      final Map<String, MenuItem> categoryMenus = {};

      for (var entry in menusByCategory.entries) {
        final category = entry.key;
        final menus = entry.value;

        // Filtrer les menus avec image
        final menusWithImage = menus
            .where((m) => m.imageUrl != null && m.imageUrl!.isNotEmpty)
            .toList();

        if (menusWithImage.isNotEmpty) {
          final randomIndex = random.nextInt(menusWithImage.length);
          categoryMenus[category] = menusWithImage[randomIndex];
        }
      }

      // 4. Charger les restaurants (dédupliqués, en parallèle)
      final uniqueIds = categoryMenus.values.map((m) => m.restaurantId).toSet().toList();
      final fetched = await Future.wait(
        uniqueIds.map((id) => _restaurantService.getRestaurantById(id)),
      );
      final restaurantById = {
        for (var i = 0; i < uniqueIds.length; i++) uniqueIds[i]: fetched[i],
      };
      final Map<String, Restaurant?> categoryRestaurants = {
        for (final e in categoryMenus.entries) e.key: restaurantById[e.value.restaurantId],
      };

      if (!mounted) return;

      setState(() {
        _categoryMenus = categoryMenus;
        _categoryRestaurants = categoryRestaurants;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
        child: _isLoading
            ? ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: defaultPadding),
            child: BigCardScalton(),
          ),
        )
            : _categoryMenus.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Aucune catégorie disponible',
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadCategoryMenus,
          child: ListView.builder(
            itemCount: _categoryMenus.length,
            itemBuilder: (context, index) {
              final category = _categoryMenus.keys.elementAt(index);
              final menu = _categoryMenus[category]!;
              final restaurant = _categoryRestaurants[category];

              return Padding(
                padding: const EdgeInsets.only(bottom: defaultPadding),
                child: CategoryCard(
                  category: category,
                  menu: menu,
                  restaurant: restaurant,
                  onTap: () {
                    if (restaurant != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(restaurant: restaurant),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String category;
  final MenuItem menu;
  final Restaurant? restaurant;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.menu,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = menu.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1.81,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image de fond
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => _buildFallbackImage(),
                )
              else
                _buildFallbackImage(),

              // Overlay avec gradient et texte
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha:0.7),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (restaurant != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              restaurant!.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                color: Colors.white.withValues(alpha:0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
      ),
    );
  }
}