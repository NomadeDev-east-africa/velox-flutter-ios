import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Écran de suivi de la position du livreur en temps réel.
/// Affiché depuis OrderTrackingScreen quand le statut est "delivering".
class TrackDeliveryScreen extends StatefulWidget {
  final String    orderId;
  final String    livreurId;
  final String?   livreurName;
  final GeoPoint? deliveryLocation; // Destination client

  const TrackDeliveryScreen({
    super.key,
    required this.orderId,
    required this.livreurId,
    this.livreurName,
    this.deliveryLocation,
  });

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final MapController _mapController = MapController();

  static const Color _neon      = Color(0xFFA6FF00);
  static const Color _onNeon    = Color(0xFF112000);
  static const Color _bgDark    = Color(0xFF131313);
  static const Color _cardDark  = Color(0xFF1C1B1B);
  static const Color _textLight = Color(0xFFE5E2E1);
  static const Color _textDim   = Color(0xFFC0CAAD);

  LivreurLocation? _dernierePosition;

  @override
  Widget build(BuildContext context) {
    final hasDestination = widget.deliveryLocation != null;
    final destination = hasDestination
        ? LatLng(widget.deliveryLocation!.latitude,
                 widget.deliveryLocation!.longitude)
        : null;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        foregroundColor: _neon,
        elevation: 0,
        title: const Text(
          'Position du livreur',
          style: TextStyle(
            color: _neon,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _neon),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<LivreurLocation?>(
        stream: _watchLivreurPosition(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _dernierePosition == null) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _neon),
                  SizedBox(height: 16),
                  Text(
                    'Localisation du livreur...',
                    style: TextStyle(color: _textDim, fontSize: 14),
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
                      color: _textDim.withValues(alpha: 0.5), size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Position du livreur non disponible',
                    style: TextStyle(color: _textDim, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le livreur n\'a pas encore activé son suivi GPS',
                    style: TextStyle(color: _textDim, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final livreurLatLng = LatLng(position.latitude, position.longitude);

          // Centrer automatiquement sur le livreur à chaque mise à jour
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(livreurLatLng, _mapController.camera.zoom);
              } catch (_) {}
            }
          });

          final markers = <Marker>[
            // Position du livreur
            Marker(
              point: livreurLatLng,
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: _neon,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: _onNeon,
                  size: 26,
                ),
              ),
            ),
          ];

          // Destination client (si disponible)
          if (destination != null) {
            markers.add(
              Marker(
                point: destination,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 44,
                ),
              ),
            );
          }

          return Column(
            children: [
              // ── Carte ──────────────────────────────────────────
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: livreurLatLng,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),

              // ── Infos livreur ──────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: _cardDark,
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _neon.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delivery_dining,
                                color: _neon, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.livreurName ?? 'Livreur',
                                  style: const TextStyle(
                                    color: _textLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: _neon,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'En route vers vous',
                                      style: TextStyle(
                                          color: _neon,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Heure dernière mise à jour
                          Text(
                            _formateurHeure(position.miseAJour),
                            style: const TextStyle(
                                color: _textDim, fontSize: 11),
                          ),
                        ],
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

  // ─────────────────────────────────────────────────────────────────
  // STREAM POSITION LIVREUR
  // ─────────────────────────────────────────────────────────────────

  /// Écoute la position du livreur en temps réel depuis `livreurs/{livreurId}`.
  /// Le champ Firestore `currentLocation` est un GeoPoint direct.
  Stream<LivreurLocation?> _watchLivreurPosition() {
    return FirebaseFirestore.instance
        .collection('livreurs')
        .doc(widget.livreurId)
        .snapshots()
        .map<LivreurLocation?>((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          final raw = data['currentLocation'];

          // ── GeoPoint direct (structure actuelle de l'app livreur) ──
          if (raw is GeoPoint) {
            final ts = data['updatedAt'];
            return LivreurLocation(
              latitude:  raw.latitude,
              longitude: raw.longitude,
              miseAJour: ts is Timestamp ? ts.toDate() : DateTime.now(),
            );
          }

          // ── Map {latitude, longitude, updatedAt} (fallback) ────────
          return _extrairePositionDepuisMap(raw);
        });
  }

  /// Extrait une [LivreurLocation] depuis un champ Map Firestore.
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

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLE — Position livreur
// ─────────────────────────────────────────────────────────────────────────────

class LivreurLocation {
  final double   latitude;
  final double   longitude;
  final double?  cap;       // bearing optionnel
  final DateTime miseAJour;

  const LivreurLocation({
    required this.latitude,
    required this.longitude,
    this.cap,
    required this.miseAJour,
  });
}
