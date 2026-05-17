import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/screens/auth-firebase/auth/sign_in_screen.dart';
import 'package:nomade_client/screens/taxi/taxi_home_screen.dart';
import 'package:nomade_client/screens/food/home_food/home_screen_food.dart';
import 'package:nomade_client/screens/profile/profile_screen.dart';

// Kinetic Monolith design system colors
const _bg         = Color(0xFF0E0E0E);
const _surfaceLow = Color(0xFF131313);
const _surface    = Color(0xFF1A1919);
const _surfaceHigh= Color(0xFF20201F);
const _surfaceTop = Color(0xFF262626);
const _primary    = Color(0xFF9FFF88);
const _onPrimary  = Color(0xFF026400);
const _onSurface  = Color(0xFFFFFFFF);
const _onSurfaceVariant = Color(0xFFADAAAA);
const _outlineVariant   = Color(0xFF484847);

class HomeScreenApp extends ConsumerStatefulWidget {
  const HomeScreenApp({super.key});

  @override
  ConsumerState<HomeScreenApp> createState() => _HomeScreenAppState();
}

class _HomeScreenAppState extends ConsumerState<HomeScreenApp> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTaxi() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TaxiHomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut))
                  .animate(animation),
              child: child,
            ),
      ),
    );
  }

  void _goToRestaurants() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (index == 1) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOut))
                    .animate(animation),
                child: child,
              ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
      if (_pageController.hasClients) {
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }
    }
  }

  // ── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader(String firstName) {
    final userState = ref.watch(userNotifierProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _surfaceHigh,
              border: Border.all(color: _primary.withValues(alpha: 0.4), width: 2),
            ),
            child: ClipOval(
              child: userState.displayPhotoUrl != null
                  ? Image.network(
                      userState.displayPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, color: _primary, size: 26),
                    )
                  : const Icon(Icons.person, color: _primary, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: _onSurfaceVariant, size: 12),
                    const SizedBox(width: 3),
                    const Text(
                      'DJIBOUTI',
                      style: TextStyle(
                        color: _onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Bonjour $firstName',
                  style: GoogleFonts.poppins(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Logo app
          Image.asset(
            'assets/images/logo_velox.webp',
            height: 90,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  // ── TAGLINE ───────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(
        '✦  Clique, Chill, on livre',
        style: GoogleFonts.inter(
          color: _primary,
          fontSize: 15,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.4,
          height: 1.3,
        ),
      ),
    );
  }

  // ── POINTS FIDÉLITÉ ───────────────────────────────────────────────────────
  Widget _buildLoyaltyCard() {
    final statsAsync = ref.watch(orderStatsProvider);
    final points = statsAsync.whenOrNull(data: (s) => s.loyaltyPoints) ?? 0;
    final displayPts = _formatNumber(points.toDouble(), isInt: true);

    // Badge selon les points
    String badge;
    if (points >= 500) {
      badge = 'VIP';
    } else if (points >= 100) {
      badge = 'GOLD';
    } else {
      badge = 'MEMBER';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POINTS FIDÉLITÉ',
                  style: TextStyle(
                    color: _onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      displayPts,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'pts',
                      style: TextStyle(
                        color: _onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1 commande = 10 pts',
                  style: TextStyle(
                    color: _primary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: _onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SERVICE CARD ──────────────────────────────────────────────────────────
  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String imageAsset,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outlineVariant.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(imageAsset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Rating
            Row(
              children: const [
                Icon(Icons.star, color: _primary, size: 14),
                SizedBox(width: 3),
                Text(
                  '4.8',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── STATISTIQUES ──────────────────────────────────────────────────────────
  Widget _buildStats() {
    final statsAsync = ref.watch(orderStatsProvider);

    final totalOrders = statsAsync.whenOrNull(data: (s) => s.totalOrders) ?? 0;
    final totalSpent  = statsAsync.whenOrNull(data: (s) => s.totalSpent)  ?? 0.0;
    final isLoading   = statsAsync is AsyncLoading;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATISTIQUES',
            style: TextStyle(
              color: _onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('12', 'COURSES'),
              _buildVerticalDivider(),
              _buildStatItem(
                isLoading ? '—' : '$totalOrders',
                'COMMANDES',
              ),
              _buildVerticalDivider(),
              _buildStatItem(
                isLoading ? '—' : _formatNumber(totalSpent),
                'DÉPENSES\n(FDJ)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value, {bool isInt = false}) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (isInt) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(0);
    }
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: _outlineVariant.withValues(alpha: 0.3),
    );
  }

  // ── ACTIONS RAPIDES ───────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.history_rounded, 'label': 'Historique'},
      {'icon': Icons.payment_rounded, 'label': 'Paiements'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Portefeuille'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Text(
            'Actions rapides',
            style: TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: actions.map((action) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${action['label']} — À venir'),
                      backgroundColor: _surfaceTop,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: action == actions.last ? 0 : 10,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _outlineVariant.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action['icon'] as IconData,
                            color: _primary, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          action['label'] as String,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          'VELOX — SERVICE NATIONAL DJIBOUTIEN V1.0.0',
          style: TextStyle(
            color: _onSurfaceVariant,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── HOME PAGE ─────────────────────────────────────────────────────────────
  Widget _buildHomePage(String firstName) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(firstName),
          _buildTagline(),
          _buildLoyaltyCard(),
          // Services header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nos Services',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Tout voir',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Service cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildServiceCard(
                  title: 'VTC DJIB',
                  subtitle: 'Déplacez-vous facilement en ville',
                  imageAsset: 'assets/vehicule/taxi-B.png',
                  onTap: _goToTaxi,
                ),
                _buildServiceCard(
                  title: 'Restaurants & Fast food',
                  subtitle: 'Toutes vos envies, livrées chez vous',
                  imageAsset: 'assets/images/fast-food.png',
                  onTap: _goToRestaurants,
                ),
              ],
            ),
          ),
          _buildStats(),
          _buildQuickActions(),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _surfaceLow,
        border: Border(
          top: BorderSide(color: _outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Accueil'),
          _buildNavItem(1, Icons.person_rounded, 'Profil'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: isActive
                  ? BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(
                icon,
                color: isActive ? _onPrimary : _onSurfaceVariant,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userNotifierProvider);

    if (userState.isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
        ),
      );
    }

    if (!userState.isAuthenticated) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: _primary, size: 60),
              const SizedBox(height: 24),
              const Text(
                'Connexion requise',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connectez-vous pour accéder aux services',
                style: TextStyle(color: _onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const SignInScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Se connecter',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final firstName = userState.displayName.split(' ').first;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _selectedIndex = i),
          children: [
            _buildHomePage(firstName),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: _buildBottomNav(),
      ),
    );
  }
}
