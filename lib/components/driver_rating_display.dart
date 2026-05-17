import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget pour afficher la note d'un chauffeur avec étoiles
/// Format: ⭐⭐⭐⭐⭐ 4.5 (127 avis)
class DriverRatingDisplay extends StatelessWidget {
  final String? driverId;
  final double? rating; // Note moyenne (si déjà connue)
  final int? totalRatings; // Nombre d'avis (si déjà connu)
  final bool isCompact; // Mode compact (pour cards) ou large (pour détails)
  final double fontSize; // Taille de police personnalisable
  final Color? starColor; // Couleur des étoiles

  const DriverRatingDisplay({
    super.key,
    this.driverId,
    this.rating,
    this.totalRatings,
    this.isCompact = true,
    this.fontSize = 14,
    this.starColor,
  });

  @override
  Widget build(BuildContext context) {
    // Si rating et totalRatings sont fournis, afficher directement
    if (rating != null && totalRatings != null) {
      return _buildRatingDisplay(rating!, totalRatings!);
    }

    // Sinon, charger depuis Firestore
    if (driverId != null) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchDriverRating(driverId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildNoRating();
          }

          final data = snapshot.data!;
          return _buildRatingDisplay(
            data['rating'] ?? 0.0,
            data['total_ratings'] ?? 0,
          );
        },
      );
    }

    // Aucune donnée disponible
    return _buildNoRating();
  }

  /// Récupérer la note du chauffeur depuis Firestore
  Future<Map<String, dynamic>> _fetchDriverRating(String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      final data = driverDoc.data();
      if (data == null) {
        return {'rating': 0.0, 'total_ratings': 0};
      }

      return {
        'rating': (data['rating'] ?? 0.0).toDouble(),
        'total_ratings': data['total_ratings'] ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Erreur chargement note chauffeur: $e');
      return {'rating': 0.0, 'total_ratings': 0};
    }
  }

  /// Afficher la note avec étoiles
  Widget _buildRatingDisplay(double rating, int totalRatings) {
    final effectiveStarColor = starColor ?? Colors.amber;
    
    if (totalRatings == 0) {
      return _buildNoRating();
    }

    if (isCompact) {
      // Mode compact: ⭐ 4.5 • 127 avis
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: effectiveStarColor,
            size: fontSize + 2,
          ),
          SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          if (totalRatings > 0) ...[
            Text(
              ' • ',
              style: TextStyle(
                fontSize: fontSize - 2,
                color: Colors.grey.shade400,
              ),
            ),
            Text(
              '$totalRatings ${totalRatings == 1 ? 'avis' : 'avis'}',
              style: TextStyle(
                fontSize: fontSize - 2,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      );
    } else {
      // Mode large: ⭐⭐⭐⭐⭐ 4.5 (127 avis)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Afficher les étoiles pleines/vides
          ...List.generate(5, (index) {
            if (index < rating.floor()) {
              // Étoile pleine
              return Icon(
                Icons.star,
                color: effectiveStarColor,
                size: fontSize + 4,
              );
            } else if (index < rating) {
              // Étoile demi-pleine
              return Icon(
                Icons.star_half,
                color: effectiveStarColor,
                size: fontSize + 4,
              );
            } else {
              // Étoile vide
              return Icon(
                Icons.star_border,
                color: effectiveStarColor,
                size: fontSize + 4,
              );
            }
          }),
          SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: fontSize + 2,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          if (totalRatings > 0) ...[
            SizedBox(width: 4),
            Text(
              '($totalRatings ${totalRatings == 1 ? 'avis' : 'avis'})',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      );
    }
  }

  /// Afficher quand il n'y a pas de note
  Widget _buildNoRating() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_border,
          color: Colors.grey.shade400,
          size: fontSize + 2,
        ),
        SizedBox(width: 4),
        Text(
          'Nouveau',
          style: TextStyle(
            fontSize: fontSize - 2,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
