import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nomade_client/constants.dart';
import 'package:nomade_client/models/ride.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'ride_completion_screen.dart';

/// Écran de suivi en temps réel de la course
/// PHASE 3 : migré de RideProvider (provider) → activeRideProvider (Riverpod)
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() =>
      _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with SingleTickerProviderStateMixin {

  final MapController     _mapController  = MapController();
  late AnimationController _pulseController;

  bool _showCompletionDialog = false;
  bool _noDriverPopupShown   = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 TrackingScreen initState');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // ✅ Plus besoin de startWatchingRide() ici.
    // ActiveRideNotifier s'initialise tout seul depuis Hive + Firestore.
  }

  @override
  void dispose() {
    debugPrint('🛑 TrackingScreen dispose');
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Couleurs / textes selon statut ──────────────────────────

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:         return Colors.orange;
      case RideStatus.accepted:          return Colors.blue;
      case RideStatus.arriving:          return Colors.blue.shade700;
      case RideStatus.arrived:           return Colors.green;
      case RideStatus.started:           return primaryColor;
      case RideStatus.completed:         return Colors.green.shade700;
      case RideStatus.cancelled:         return Colors.red;
      case RideStatus.noDriverAvailable: return Colors.red.shade800;
    }
  }

  Map<String, dynamic> _getStatusInfo(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return {
          'text': 'Recherche d\'un chauffeur...',
          'icon': Icons.search,
          'showTimer': true,
        };
      case RideStatus.accepted:
        return {
          'text': 'Chauffeur en route',
          'icon': Icons.directions_car,
          'showTimer': false,
        };
      case RideStatus.arriving:
        return {
          'text': 'Votre chauffeur approche !',
          'icon': Icons.near_me,
          'showTimer': false,
        };
      case RideStatus.arrived:
        return {
          'text': 'Votre chauffeur est arrivé !',
          'icon': Icons.location_on,
          'showTimer': false,
        };
      case RideStatus.started:
        return {
          'text': 'En route vers votre destination',
          'icon': Icons.navigation,
          'showTimer': true,
        };
      case RideStatus.completed:
        return {
          'text': 'Course terminée !',
          'icon': Icons.check_circle,
          'showTimer': false,
        };
      case RideStatus.cancelled:
      case RideStatus.noDriverAvailable:
        return {
          'text': 'Course annulée',
          'icon': Icons.cancel,
          'showTimer': false,
        };
    }
  }

  // ─── Annulation ──────────────────────────────────────────────

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la course ?'),
        content: const Text('Êtes-vous sûr de vouloir annuler ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(activeRideProvider.notifier)
            .cancelRide('Annulé par le client');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur annulation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── Navigation vers completion ──────────────────────────────

  void _navigateToCompletion(Ride ride) {
    if (_showCompletionDialog) return;
    _showCompletionDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideCompletionScreen(ride: ride),
        ),
      );
    });
  }

  // ─── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ Riverpod : watch activeRideProvider
    final rideState = ref.watch(activeRideProvider);

    // Réagir aux transitions de statut
    ref.listen<ActiveRideState>(activeRideProvider, (prev, next) {
      if (next.ride == null || !mounted) return;
      final ride = next.ride!;

      // Course terminée → navigation
      if (ride.status == RideStatus.completed && !_showCompletionDialog) {
        _navigateToCompletion(ride);
      }

      // Aucun chauffeur → popup avant retour
      if (ride.status == RideStatus.noDriverAvailable &&
          !_noDriverPopupShown &&
          mounted) {
        _noDriverPopupShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Aucun chauffeur disponible'),
              content: const Text(
                'Désolé, aucun chauffeur n\'est disponible dans votre zone pour le moment.\n\nVeuillez réessayer dans quelques minutes.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    ref.read(activeRideProvider.notifier).clearRide();
                  },
                  child: const Text('Retour à l\'accueil'),
                ),
              ],
            ),
          );
        });
      }

      // Course annulée → retour accueil
      if (ride.status == RideStatus.cancelled && mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ref.read(activeRideProvider.notifier).clearRide();
      }
    });

    // ── Chargement ──────────────────────────────────────────────
    if ((rideState.isLoading || rideState.isWatching) && rideState.ride == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Erreur ──────────────────────────────────────────────────
    if (rideState.error != null && rideState.ride == null) {
      return _buildErrorScreen(rideState.error!);
    }

    // ── Pas de course active (après nettoyage) ──────────────────
    if (rideState.ride == null) {
      // Retourner à l'accueil proprement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ride = rideState.ride!;
    final statusInfo  = _getStatusInfo(ride.status);
    final statusColor = _getStatusColor(ride.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de course'),
        backgroundColor: statusColor,
        automaticallyImplyLeading: false,
        actions: [
          if (ride.status == RideStatus.requested ||
              ride.status == RideStatus.accepted ||
              ride.status == RideStatus.arriving ||
              ride.status == RideStatus.arrived)
            TextButton(
              onPressed: _cancelRide,
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Bannière statut ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: statusColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(statusInfo['icon'] as IconData,
                    color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo['text'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      if (statusInfo['showTimer'] == true)
                        _ElapsedTimer(
                          startTime: ride.status == RideStatus.started
                              ? (ride.startedAt ?? ride.requestedAt)
                              : ride.requestedAt,
                        ),
                    ],
                  ),
                ),
                // Indicateur stream actif
                if (rideState.isWatching)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),

          // ── Carte ──────────────────────────────────────────────
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  ride.pickup.latitude,
                  ride.pickup.longitude,
                ),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup
                    Marker(
                      point: LatLng(
                        ride.pickup.latitude,
                        ride.pickup.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                    // Destination
                    Marker(
                      point: LatLng(
                        ride.destination.latitude,
                        ride.destination.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Infos course ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Chauffeur info si assigné
                if (ride.hasDriver) ...[
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.driverName ?? 'Chauffeur',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (ride.driverPhone != null)
                              Text(
                                ride.driverPhone!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (ride.driverPhone != null)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => launchUrl(
                              Uri.parse('tel:${ride.driverPhone}')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                ],

                // Tarif estimé
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tarif estimé',
                        style: TextStyle(color: Colors.grey)),
                    Text(
                      '${ride.finalFare?.toStringAsFixed(0) ?? ride.estimatedFare.toStringAsFixed(0)} FDJ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  const _ElapsedTimer({required this.startTime});
  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(widget.startTime);
    final text = diff.inMinutes < 1
        ? '${diff.inSeconds}s'
        : diff.inHours < 1
            ? '${diff.inMinutes}min'
            : '${diff.inHours}h ${diff.inMinutes.remainder(60)}min';
    return Text('Temps: $text', style: const TextStyle(fontSize: 13));
  }
}
