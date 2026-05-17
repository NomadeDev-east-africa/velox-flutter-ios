import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomade_client/constants.dart';

class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.departure,
    required this.destination,
    this.height,
    this.isDarkMap = false,  // Nouveau paramètre ajouté
  });

  final LatLng departure;
  final LatLng destination;
  final double? height;
  final bool isDarkMap;  // Pour toggle clair/sombre

  @override
  Widget build(BuildContext context) {
    final centerLat = (departure.latitude + destination.latitude) / 2;
    final centerLng = (departure.longitude + destination.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    final distance = const Distance().as(LengthUnit.Kilometer, departure, destination);
    final zoom = _calculateZoom(distance);

    final String tileUrl = isDarkMap
        ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

    return SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 10.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            userAgentPackageName: 'com.nomade253.app',
          ),

          // Ligne trajet premium
          PolylineLayer(
            polylines: [
              Polyline(
                points: [departure, destination],
                color: secondaryColor,
                strokeWidth: 6.0,
                borderColor: Colors.white.withValues(alpha: 0.8),
                borderStrokeWidth: 3.0,
              ),
            ],
          ),

          // Marqueurs Uber-style
          MarkerLayer(
            markers: [
              // Départ
              Marker(
                point: departure,
                width: 50,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.circle, color: Colors.white, size: 16),
                ),
              ),
              // Destination
              Marker(
                point: destination,
                width: 60,
                height: 70,
                child: Icon(
                  Icons.location_pin,
                  color: secondaryColor,
                  size: 60,
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateZoom(double distanceKm) {
    if (distanceKm < 2) return 15.0;
    if (distanceKm < 5) return 14.0;
    if (distanceKm < 10) return 13.0;
    if (distanceKm < 20) return 12.0;
    return 11.0;
  }
}