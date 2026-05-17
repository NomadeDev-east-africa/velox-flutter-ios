import 'package:flutter/material.dart';
import 'package:nomade_client/models/place.dart';
import 'package:nomade_client/constants.dart';

/// Card pour afficher un lieu
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.place,
    required this.onTap,
    this.showDistance = true,
  });

  final Place place;
  final VoidCallback onTap;
  final bool showDistance;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                place.icon ?? Icons.place,
                color: _getIconColor(),
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (showDistance && place.distance != null) ...[
                        Icon(
                          Icons.directions_walk,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${place.distance!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ] else if (place.address != null) ...[
                        Expanded(
                          child: Text(
                            place.address!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Flèche
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Color _getIconBackgroundColor() {
    switch (place.type) {
      case PlaceType.saved:
        return primaryColor.withValues(alpha: 0.1);
      case PlaceType.recent:
        return Colors.grey.shade100;
      case PlaceType.suggestion:
        return secondaryColor.withValues(alpha: 0.1);
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getIconColor() {
    switch (place.type) {
      case PlaceType.saved:
        return primaryColor;
      case PlaceType.recent:
        return Colors.grey.shade600;
      case PlaceType.suggestion:
        return secondaryColor;
      default:
        return Colors.grey.shade600;
    }
  }
}
