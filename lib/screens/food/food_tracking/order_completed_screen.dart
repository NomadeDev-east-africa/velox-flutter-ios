import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import 'package:nomade_client/constants.dart';
import 'package:nomade_client/models/order.dart';
class OrderCompletedScreen extends StatefulWidget {
  final Order order;

  const OrderCompletedScreen({super.key, required this.order});

  @override
  State<OrderCompletedScreen> createState() => _OrderCompletedScreenState();
}

class _OrderCompletedScreenState extends State<OrderCompletedScreen> with SingleTickerProviderStateMixin {
  int _restaurantRating = 0;
  int _driverRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitRatings() async {
    if (_restaurantRating == 0 || _driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez noter le restaurant et le livreur'),
          backgroundColor: accentColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final comment   = _commentController.text.trim();
      final db        = FirebaseFirestore.instance;
      final now       = FieldValue.serverTimestamp();

      // ── 1. Mettre à jour la commande ──────────────────────────
      // ratedAt déclenche la CF onOrderRated qui recalcule
      // les moyennes de restaurants et livreurs (Admin SDK)
      await db.collection('orders').doc(widget.order.id).update({
        'restaurantRating': _restaurantRating,
        'driverRating':     _driverRating,
        if (comment.isNotEmpty) 'restaurantComment': comment,
        'ratedAt':   now,
        'updatedAt': now,
      });

      // ── 2. Ajouter l'avis dans la sous-collection du restaurant ──
      await db
          .collection('restaurants')
          .doc(widget.order.restaurantId)
          .collection('avis')
          .add({
        'orderId':     widget.order.id,
        'userId':      widget.order.userId,
        'clientNom':   widget.order.customerName,
        'note':        _restaurantRating,
        'commentaire': comment,
        'createdAt':   now,
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Merci pour votre avis !'),
            backgroundColor: primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: accentColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _skipRating() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // 🎉 Icône de succès
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 24),

                // Message de remerciement
                Text(
                  'Commande livrée !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  'Merci d\'avoir utilisé le service\nde livraison Velox 🇩🇯',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Numéro de commande
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: inputColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Commande #${widget.order.id.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Section notation restaurant
                _buildRatingSection(
                  title: 'Notez le restaurant',
                  subtitle: widget.order.restaurantName,
                  icon: Icons.restaurant,
                  iconColor: primaryColor,
                  rating: _restaurantRating,
                  onRatingChanged: (rating) {
                    setState(() => _restaurantRating = rating);
                  },
                  commentController: _commentController,
                ),

                const SizedBox(height: 32),

                // Section notation livreur
                _buildRatingSection(
                  title: 'Notez le livreur',
                  subtitle: widget.order.deliveryDriverName ?? 'Livreur',
                  icon: Icons.delivery_dining,
                  iconColor: secondaryColor,
                  rating: _driverRating,
                  onRatingChanged: (rating) {
                    setState(() => _driverRating = rating);
                  },
                ),

                const SizedBox(height: 40),

                // Bouton soumettre
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRatings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Envoyer les notes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton retour (passer)
                TextButton(
                  onPressed: _skipRating,
                  child: Text(
                    'Retour à l\'accueil',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required int rating,
    required ValueChanged<int> onRatingChanged,
    TextEditingController? commentController,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icône + Texte
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Étoiles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starValue <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 42,
                    color: starValue <= rating
                        ? Colors.amber
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),

          if (rating > 0) ...[
            const SizedBox(height: 12),
            Text(
              _getRatingText(rating),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          if (commentController != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              maxLength: 300,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Laissez un commentaire (optionnel)...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
                counterStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Très mauvais 😞';
      case 2:
        return 'Mauvais 😕';
      case 3:
        return 'Moyen 😐';
      case 4:
        return 'Bien 😊';
      case 5:
        return 'Excellent ! 🤩';
      default:
        return '';
    }
  }
}
