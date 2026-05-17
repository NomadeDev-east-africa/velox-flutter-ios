import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nomade_client/models/ride.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/services/rating_service.dart';
import 'package:nomade_client/services/favorite_drivers_service.dart';
import 'package:nomade_client/constants.dart';
import 'package:nomade_client/screens/HomeScreen/home_screen_app.dart';
import 'taxi_home_screen.dart';

// ✅ PHASE 3 : ride_provider.dart SUPPRIMÉ
// ✅ PHASE 3 : provider.dart SUPPRIMÉ (plus de context.read<RideProvider>())

class RideCompletionScreen extends ConsumerStatefulWidget {
  final Ride ride;

  const RideCompletionScreen({
    super.key,
    required this.ride,
  });

  @override
  ConsumerState<RideCompletionScreen> createState() =>
      _RideCompletionScreenState();
}

class _RideCompletionScreenState extends ConsumerState<RideCompletionScreen>
    with SingleTickerProviderStateMixin {

  final RatingService          _ratingService   = RatingService();
  final FavoriteDriversService _favoritesService = FavoriteDriversService();

  int    _selectedRating = 0;
  final  TextEditingController _reviewController = TextEditingController();
  bool   _isSubmittingRating = false;
  bool   _ratingSubmitted    = false;

  bool   _isFavorite         = false;
  bool   _isLoadingFavorite  = true;
  bool   _isTogglingFavorite = false;

  late AnimationController _animationController;
  late Animation<double>   _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _checkIfFavorite();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // FAVORI
  // ════════════════════════════════════════════════════════════

  Future<void> _checkIfFavorite() async {
    if (widget.ride.driverId == null) {
      setState(() => _isLoadingFavorite = false);
      return;
    }

    // ✅ Riverpod — ref.read(userNotifierProvider).userId
    final userId = ref.read(userNotifierProvider).userId;
    if (userId == null) {
      setState(() => _isLoadingFavorite = false);
      return;
    }

    try {
      final isFav = await _favoritesService.isFavorite(
        userId: userId,
        driverId: widget.ride.driverId!,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification favori: $e');
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.ride.driverId == null) return;

    // ✅ Riverpod
    final userId = ref.read(userNotifierProvider).userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté')),
      );
      return;
    }

    setState(() => _isTogglingFavorite = true);
    try {
      if (_isFavorite) {
        await _favoritesService.removeFromFavorites(
          userId: userId,
          driverId: widget.ride.driverId!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.heart_broken, color: Colors.white),
              const SizedBox(width: 8),
              Text('${widget.ride.driverName} retiré des favoris'),
            ]),
            backgroundColor: Colors.grey.shade700,
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        await _favoritesService.addToFavorites(
          userId: userId,
          driverId: widget.ride.driverId!,
          driverName: widget.ride.driverName ?? 'Chauffeur',
          driverPhotoUrl: widget.ride.driverPhotoUrl,
          driverPhone: widget.ride.driverPhone,
          driverRating: null,
          vehicleType: widget.ride.vehicleType,
          rideId: widget.ride.rideId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.favorite, color: Colors.white),
              const SizedBox(width: 8),
              Text('${widget.ride.driverName} ajouté aux favoris !'),
            ]),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ));
        }
      }
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
          _isTogglingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur toggle favori: $e');
      if (mounted) {
        setState(() => _isTogglingFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // APPEL CHAUFFEUR
  // ════════════════════════════════════════════════════════════

  Future<void> _callDriver(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'appeler le chauffeur'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'appel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Impossible de passer l\'appel'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // NOTATION
  // ════════════════════════════════════════════════════════════

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une note'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (widget.ride.driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de noter: chauffeur introuvable'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Riverpod
    final userId = ref.read(userNotifierProvider).userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté')),
      );
      return;
    }

    setState(() => _isSubmittingRating = true);
    try {
      final review = _reviewController.text.trim().isEmpty
          ? null
          : _reviewController.text.trim();

      await _ratingService.rateDriver(
        driverId: widget.ride.driverId!,
        rideId:   widget.ride.rideId,
        userId:   userId,
        rating:   _selectedRating,
        review:   review,
      );

      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
          _ratingSubmitted    = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Merci pour votre avis ! 💙'),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur soumission notation: $e');
      if (mounted) {
        setState(() => _isSubmittingRating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getRideDuration() {
    if (widget.ride.startedAt == null || widget.ride.completedAt == null) {
      return '${widget.ride.estimatedDuration} min (estimé)';
    }
    final duration =
        widget.ride.completedAt!.difference(widget.ride.startedAt!);
    return '${duration.inMinutes} min';
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSuccessHeader(),
                  const SizedBox(height: 24),
                  _buildRideSummary(),
                  const SizedBox(height: 20),
                  _buildDriverInfo(),
                  const SizedBox(height: 24),
                  _buildThankYouMessage(),
                  const SizedBox(height: 24),
                  _buildRatingSection(),
                  const SizedBox(height: 20),
                  _buildFavoriteSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS UI
  // ════════════════════════════════════════════════════════════

  Widget _buildSuccessHeader() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, Colors.green.shade600],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.check_circle, color: Colors.white, size: 60),
    );
  }

  Widget _buildRideSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course terminée !',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.radio_button_checked,
            iconColor: primaryColor,
            label: 'Départ',
            address: widget.ride.pickup.address,
          ),
          const SizedBox(height: 8),
          _buildDottedLine(),
          const SizedBox(height: 8),
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.red.shade400,
            label: 'Arrivée',
            address: widget.ride.destination.address,
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.straighten,
                label: 'Distance',
                value: '${widget.ride.distance.toStringAsFixed(1)} km',
              ),
              _buildStatItem(
                icon: Icons.access_time,
                label: 'Durée',
                value: _getRideDuration(),
              ),
              _buildStatItem(
                icon: Icons.payments,
                label: 'Prix',
                value:
                    '${widget.ride.finalFare?.toStringAsFixed(0) ?? widget.ride.estimatedFare.toStringAsFixed(0)} FDJ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(color: iconColor.withValues(alpha:0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(
                address,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDottedLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildDriverInfo() {
    if (widget.ride.driverId == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: primaryColor.withValues(alpha:0.1),
            backgroundImage: widget.ride.driverPhotoUrl != null
                ? NetworkImage(widget.ride.driverPhotoUrl!)
                : null,
            child: widget.ride.driverPhotoUrl == null
                ? Icon(Icons.person, size: 35, color: primaryColor)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ride.driverName ?? 'Chauffeur',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800),
                ),
                const SizedBox(height: 4),
                Text(widget.ride.vehicleType,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (widget.ride.driverPhone != null)
            IconButton(
              onPressed: () => _callDriver(widget.ride.driverPhone!),
              icon: Icon(Icons.phone, color: primaryColor),
              style: IconButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha:0.1)),
            ),
        ],
      ),
    );
  }

  Widget _buildThankYouMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withValues(alpha:0.1), Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Merci d\'avoir roulé avec Velox 💙',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre course s\'est bien déroulée et nous espérons vous revoir bientôt !',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    if (_ratingSubmitted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Merci pour votre évaluation !',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Comment s\'est passée votre course ?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starValue <= _selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    size: 40,
                    color: starValue <= _selectedRating
                        ? Colors.amber
                        : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          ),
          if (_selectedRating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _selectedRating == 5
                  ? 'Excellent !'
                  : _selectedRating == 4
                      ? 'Très bien !'
                      : _selectedRating == 3
                          ? 'Bien'
                          : _selectedRating == 2
                              ? 'Peut mieux faire'
                              : 'Pas terrible',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Commentaire (optionnel)',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmittingRating ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Envoyer l\'évaluation ⭐',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteSection() {
    if (widget.ride.driverId == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFavorite ? Colors.red.shade100 : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _isFavorite
                  ? Colors.red.shade50
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite
                  ? Colors.red.shade400
                  : Colors.grey.shade400,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isFavorite ? 'Ajouté aux favoris !' : 'Ajouter aux favoris',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  _isFavorite
                      ? 'Retrouvez facilement ce chauffeur'
                      : 'Retrouvez rapidement ce chauffeur pour vos prochaines courses',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (_isLoadingFavorite || _isTogglingFavorite)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _isFavorite,
              onChanged: (_) => _toggleFavorite(),
              activeThumbColor: Colors.red.shade400,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // ✅ PHASE 3 : context.read<RideProvider>().clearCurrentRide()
        //             → ref.read(activeRideProvider.notifier).clearRide()
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () async {
              await ref.read(activeRideProvider.notifier).clearRide(); // ✅
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TaxiHomeScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text(
              'Nouvelle course',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await ref.read(activeRideProvider.notifier).clearRide(); // ✅
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreenApp()),
              (route) => false,
            );
          },
          child: Text(
            'Retour à l\'accueil',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
