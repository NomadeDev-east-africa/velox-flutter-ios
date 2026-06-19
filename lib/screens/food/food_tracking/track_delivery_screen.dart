import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nomade_client/providers/theme_notifier.dart';
import 'package:nomade_client/theme/app_colors.dart';
import 'package:nomade_client/services/location_service.dart';

/// Écran de suivi de la position du livreur en temps réel.
/// Affiché depuis OrderTrackingScreen quand le statut est "delivering".
class TrackDeliveryScreen extends ConsumerStatefulWidget {
  final String    orderId;
  final String    livreurId;
  final String?   livreurName;
  final GeoPoint? deliveryLocation;

  const TrackDeliveryScreen({
    super.key,
    required this.orderId,
    required this.livreurId,
    this.livreurName,
    this.deliveryLocation,
  });

  @override
  ConsumerState<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends ConsumerState<TrackDeliveryScreen> {
  final MapController _mapController = MapController();
  LivreurLocation? _dernierePosition;

  // ── Route livreur → client ────────────────────────────────────
  final LocationService _locationService = LocationService();
  List<LatLng> _routePoints = [];
  LatLng? _routeAnchor;       // position du livreur au dernier calcul
  bool _fetchingRoute = false;

  /// Recalcule la route routière entre le livreur et l'adresse de livraison.
  /// Throttlé : seulement si aucune route encore, ou si le livreur a bougé > 40 m.
  Future<void> _maybeUpdateRoute(LatLng driver, LatLng? destination) async {
    if (destination == null || _fetchingRoute) return;
    if (_routePoints.isNotEmpty && _routeAnchor != null) {
      final moved = _locationService.calculateDistance(
        _routeAnchor!.latitude, _routeAnchor!.longitude,
        driver.latitude, driver.longitude,
      );
      if (moved < 0.04) return; // < 40 m → on garde la route actuelle
    }
    _fetchingRoute = true;
    try {
      final route = await _locationService.getRoute(
        startLat: driver.latitude,
        startLon: driver.longitude,
        endLat: destination.latitude,
        endLon: destination.longitude,
      );
      if (!mounted) return;
      setState(() {
        _routePoints =
            route.coordinates.map((c) => LatLng(c.latitude, c.longitude)).toList();
        _routeAnchor = driver;
      });
    } catch (_) {
      // En cas d'échec on conserve la route précédente
    } finally {
      _fetchingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;

    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    final hasDestination = widget.deliveryLocation != null;
    final destination = hasDestination
        ? LatLng(widget.deliveryLocation!.latitude,
                 widget.deliveryLocation!.longitude)
        : null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.primary,
        elevation: 0,
        title: Text(
          'Position du livreur',
          style: TextStyle(
            color: c.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<LivreurLocation?>(
        stream: _watchLivreurPosition(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _dernierePosition == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: c.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Localisation du livreur...',
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final position = snapshot.data ?? _dernierePosition;
          if (snapshot.data != null) _dernierePosition = snapshot.data;

          if (position == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off,
                      color: c.onSurfaceVariant.withValues(alpha: 0.5), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Position du livreur non disponible',
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le livreur n\'a pas encore activé son suivi GPS',
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final livreurLatLng = LatLng(position.latitude, position.longitude);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(livreurLatLng, _mapController.camera.zoom);
              } catch (_) {}
              _maybeUpdateRoute(livreurLatLng, destination);
            }
          });

          final markers = <Marker>[
            Marker(
              point: livreurLatLng,
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.delivery_dining, color: c.onPrimary, size: 26),
              ),
            ),
          ];

          if (destination != null) {
            markers.add(
              const Marker(
                point: LatLng(0, 0), // remplacé ci-dessous
                width: 44,
                height: 44,
                child: Icon(Icons.location_on, color: Colors.redAccent, size: 44),
              ),
            );
            // Remplacer le marker destination avec la vraie position
            markers.last = Marker(
              point: destination,
              width: 44,
              height: 44,
              child: const Icon(Icons.location_on, color: Colors.redAccent, size: 44),
            );
          }

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: livreurLatLng,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: c.primary,
                            strokeWidth: 4,
                            borderColor: Colors.white.withValues(alpha: 0.7),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: c.surfaceLow,
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.delivery_dining, color: c.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.livreurName ?? 'Livreur',
                              style: TextStyle(
                                color: c.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(
                                    color: c.primary, shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'En route vers vous',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formateurHeure(position.miseAJour),
                        style: TextStyle(color: c.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Stream<LivreurLocation?> _watchLivreurPosition() {
    return FirebaseFirestore.instance
        .collection('livreurs')
        .doc(widget.livreurId)
        .snapshots()
        .map<LivreurLocation?>((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          final raw = data['currentLocation'];

          if (raw is GeoPoint) {
            final ts = data['updatedAt'];
            return LivreurLocation(
              latitude:  raw.latitude,
              longitude: raw.longitude,
              miseAJour: ts is Timestamp ? ts.toDate() : DateTime.now(),
            );
          }
          return _extrairePositionDepuisMap(raw);
        });
  }

  LivreurLocation? _extrairePositionDepuisMap(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    if (lat == null || lon == null) return null;
    final ts = raw['updatedAt'] ?? raw['miseAJour'];
    return LivreurLocation(
      latitude:  (lat as num).toDouble(),
      longitude: (lon as num).toDouble(),
      miseAJour: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  String _formateurHeure(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 10) return 'À l\'instant';
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class LivreurLocation {
  final double   latitude;
  final double   longitude;
  final double?  cap;
  final DateTime miseAJour;

  const LivreurLocation({
    required this.latitude,
    required this.longitude,
    this.cap,
    required this.miseAJour,
  });
}
