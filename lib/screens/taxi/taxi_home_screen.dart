import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:nomade_client/constants.dart';
import 'package:nomade_client/theme/app_colors.dart';
import 'package:nomade_client/translations/app_translations.dart';
import 'package:nomade_client/models/place.dart';
import 'package:nomade_client/models/ride_choice.dart';
import 'package:nomade_client/models/trip_details.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/services/location_service.dart';
import 'package:nomade_client/data/mock_taxi_data.dart';
import 'destination_picker_screen.dart';
import 'ride_confirmation_screen.dart';
import 'components/ride/ride_choice_card.dart';

// ─────────────────────────────────────────────────────────────
// TaxiHomeScreen — 2 états :
//
//  1. IDLE : carte GPS, pickup localisé, bouton "Choisir une destination"
//     → DestinationPickerScreen (retourne Place via pop)
//
//  2. AVEC DESTINATION : RouteMapView intégrée, sélecteur véhicule horizontal
//     avec prix calculés, bouton "Confirmer la course"
//     → RideConfirmationScreen → TrackingScreen
// ─────────────────────────────────────────────────────────────

class TaxiHomeScreen extends ConsumerStatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  ConsumerState<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends ConsumerState<TaxiHomeScreen>
    with TickerProviderStateMixin, RestorationMixin {

  // ── Carte ────────────────────────────────────────────────
  final MapController _mapController = MapController();
  static const LatLng _djiboutiCenter = LatLng(11.5892, 43.1456);

  // ── Animation pulse marker GPS ───────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── ÉTAT PICKUP ───────────────────────────────────────────
  bool _isAdjustingPickup = false;
  LatLng? _pickupLatLng;
  // RestorableStringN : restauré par l'OS si l'app est tuée en background
  final RestorableStringN _restorablePickupAddress = RestorableStringN(null);
  bool _isLoadingPickup = false;

  // ── ÉTAT DESTINATION ──────────────────────────────────────
  Place? _destination; // null = état idle
  // Restaure uniquement le nom de destination (pour affichage UX)
  final RestorableStringN _restorableDestinationName = RestorableStringN(null);

  // ── VÉHICULE SÉLECTIONNÉ ──────────────────────────────────
  late RideChoice _selectedRide;

  // ── DISTANCE / DURÉE ─────────────────────────────────────
  double _distanceKm = 0;
  int _durationMin = 0;

  // ── Services ──────────────────────────────────────────────
  final LocationService _locationService = LocationService();

  // ── Couleurs thème ────────────────────────────────────────
  late AppColors _c;

  // ── Getters raccourcis sur les champs restaurables ────────
  String? get _pickupAddress        => _restorablePickupAddress.value;
  set _pickupAddress(String? v)     => _restorablePickupAddress.value = v;

  // ════════════════════════════════════════════════════════════
  // RESTORATION
  // ════════════════════════════════════════════════════════════

  @override
  String get restorationId => 'taxi_home_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorablePickupAddress,    'pickup_address');
    registerForRestoration(_restorableDestinationName,  'destination_name');
  }

  @override
  void initState() {
    super.initState();

    _selectedRide = MockTaxiData.defaultRideChoice;

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initGps());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    _restorablePickupAddress.dispose();
    _restorableDestinationName.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // GPS INIT
  // ─────────────────────────────────────────────────────────
  Future<void> _initGps() async {
    final locNotifier = ref.read(locationNotifierProvider.notifier);
    setState(() => _isLoadingPickup = true);

    try {
      if (!ref.read(locationNotifierProvider).hasPosition) {
        await locNotifier.getCurrentLocation();
      }

      final pos = ref.read(locationNotifierProvider).position;
      if (pos != null && mounted) {
        _pickupLatLng = pos;
        _mapController.move(pos, 15);

        final address = await _locationService.getAddressFromCoordinates(
          pos.latitude, pos.longitude,
        );
        if (mounted) setState(() { _pickupAddress = address; _isLoadingPickup = false; });
      } else {
        if (mounted) {
          setState(() {
            _pickupLatLng = _djiboutiCenter;
            _pickupAddress = 'Centre-ville, Djibouti';
            _isLoadingPickup = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ GPS: $e');
      if (mounted) {
        setState(() {
          _pickupLatLng = _djiboutiCenter;
          _pickupAddress = 'Centre-ville, Djibouti';
          _isLoadingPickup = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // AJUSTEMENT MANUEL PICKUP
  // ─────────────────────────────────────────────────────────
  void _togglePickupAdjustment() {
    setState(() => _isAdjustingPickup = !_isAdjustingPickup);
    if (_isAdjustingPickup && _pickupLatLng != null) {
      _mapController.move(_pickupLatLng!, 16.0);
    }
  }

  Future<void> _onMapTap(LatLng latLng) async {
    // En mode idle uniquement (carte GPS), pas en mode route
    if (!_isAdjustingPickup || _destination != null) return;

    setState(() {
      _pickupLatLng = latLng;
      _pickupAddress = null;
      _isLoadingPickup = true;
      _isAdjustingPickup = false;
    });
    _mapController.move(latLng, 16);

    try {
      final address = await _locationService.getAddressFromCoordinates(
        latLng.latitude, latLng.longitude,
      );
      if (mounted) setState(() { _pickupAddress = address; _isLoadingPickup = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickupAddress = '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
          _isLoadingPickup = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // NAVIGATION VERS DESTINATION PICKER
  // Retourne un Place? via pop
  // ─────────────────────────────────────────────────────────
  Future<void> _openDestinationPicker() async {
    if (_pickupLatLng == null) return;

    final pickupPlace = Place(
      id: 'pickup_current',
      name: _pickupAddress ?? tr('my_position'),
      location: _pickupLatLng!,
      address: _pickupAddress ?? tr('my_position'),
      type: PlaceType.saved,
      icon: Icons.my_location,
    );

    // DestinationPickerScreen retourne un Place? via Navigator.pop
    final Place? result = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationPickerScreen(currentLocation: pickupPlace),
      ),
    );

    if (result != null && mounted) {
      _setDestination(result);
    }
  }

  // ─────────────────────────────────────────────────────────
  // APPLIQUER LA DESTINATION → calcul distance + centrage carte
  // ─────────────────────────────────────────────────────────
  void _setDestination(Place dest) {
    if (_pickupLatLng == null) return;

    final dist = _locationService.calculateDistance(
      _pickupLatLng!.latitude, _pickupLatLng!.longitude,
      dest.location.latitude, dest.location.longitude,
    );
    final dur = _locationService.calculateETA(dist);

    setState(() {
      _destination = dest;
      _distanceKm  = dist;
      _durationMin = dur;
      _restorableDestinationName.value = dest.name;
    });
  }

  // ─────────────────────────────────────────────────────────
  // RÉINITIALISER → retour état idle
  // ─────────────────────────────────────────────────────────
  void _clearDestination() {
    setState(() {
      _destination   = null;
      _distanceKm    = 0;
      _durationMin   = 0;
      _restorableDestinationName.value = null;
    });
    if (_pickupLatLng != null) {
      _mapController.move(_pickupLatLng!, 15);
    }
  }

  // ─────────────────────────────────────────────────────────
  // CONFIRMER → RideConfirmationScreen
  // ─────────────────────────────────────────────────────────
  void _confirmRide() {
    if (_destination == null || _pickupLatLng == null) return;

    final pickupPlace = Place(
      id: 'pickup_current',
      name: _pickupAddress ?? tr('my_position'),
      location: _pickupLatLng!,
      address: _pickupAddress ?? tr('my_position'),
      type: PlaceType.saved,
    );

    final tripDetails = TripDetails(
      departure: _pickupLatLng!,
      destination: _destination!.location,
      departureAddress: _pickupAddress ?? tr('my_position'),
      destinationAddress: _destination!.address ?? _destination!.name,
      distance: _distanceKm,
      duration: _durationMin,
      selectedRide: _selectedRide,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideConfirmationScreen(
          pickup: pickupPlace,
          destination: _destination!,
          tripDetails: tripDetails,
        ),
      ),
    ).then((_) {
      // Après la course (retour du flow), on remet l'état idle
      if (mounted) _clearDestination();
    });
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    _c = isDark ? AppColors.dark : AppColors.light;
    final bool hasDestination = _destination != null;

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ── Titre ──────────────────────────────────────
              Text(
                hasDestination
                    ? '${tr('ride_ready')} ✓'
                    : '${tr('where_to_today')} 🌍',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: kNeonGreen,
                ),
              ),

              const SizedBox(height: 16),
              _buildDecorativeElements(),

              // ── Champs localisation ─────────────────────────
              _buildLocationFields(),
              const SizedBox(height: 16),

              // ── Carte : GPS idle OU route avec destination ──
              hasDestination
                  ? _buildRouteMap()
                  : _buildGpsMap(),

              const SizedBox(height: 18),

              // ── Titre sélecteur véhicule (toujours visible) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('choose_vehicle'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _c.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── SÉLECTEUR VÉHICULE UNIQUE (horizontal avec RideChoiceCard) ──
              _buildVehicleSelector(),

              const SizedBox(height: 18),

              // ── Bouton principal ────────────────────────────
              hasDestination
                  ? _buildConfirmButton()
                  : _buildChooseDestinationButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _c.surfaceLow,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kNeonGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🇩🇯', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8),
          const Text('Velox', style: TextStyle(color: kNeonGreen, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _c.surface,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none),
              color: _c.onSurfaceVariant,
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeElements() {
    return SizedBox(
      height: 60,
      child: Stack(children: [
        Positioned(left: -20, top: 0, child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [drapeauVert.withValues(alpha:0.1), drapeauVert.withValues(alpha:0)]),
            shape: BoxShape.circle,
          ),
        )),
        Positioned(right: -30, bottom: 0, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [drapeauBleu.withValues(alpha:0.1), drapeauBleu.withValues(alpha:0)]),
            shape: BoxShape.circle,
          ),
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CHAMPS PICKUP + DESTINATION
  // ─────────────────────────────────────────────────────────
  Widget _buildLocationFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _c.surfaceLow,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.08), blurRadius: 16, offset: const Offset(0, 6)),
            if (_isAdjustingPickup)
              BoxShadow(color: drapeauVert.withValues(alpha:0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
          border: _isAdjustingPickup
              ? Border.all(color: drapeauVert.withValues(alpha:0.3), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            // ── PICKUP ──
            _buildPickupRow(),

            // Connecteur
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(
                width: 2, height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [vertPrincipal.withValues(alpha:0.4), _c.outlineVariant],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── DESTINATION ──
            _buildDestinationRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupRow() {
    return GestureDetector(
      onTap: _destination == null ? _togglePickupAdjustment : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dot vert animé
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: kNeonGreen,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: kNeonGreen.withValues(alpha:0.4), blurRadius: 6)],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAdjustingPickup ? '🔄 ${tr('manual_adjust')}' : '📍 ${tr('pickup_point')}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _isAdjustingPickup ? drapeauVert : _c.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                if (_isLoadingPickup)
                  Row(children: [
                    SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(drapeauVert))),
                    const SizedBox(width: 8),
                    Text(tr('locating'), style: TextStyle(fontSize: 13, color: _c.onSurfaceVariant)),
                  ])
                else
                  Text(
                    _pickupAddress ?? tr('choose_pickup'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _pickupAddress != null ? FontWeight.w600 : FontWeight.w400,
                      color: _pickupAddress != null ? _c.onSurface : _c.onSurfaceVariant,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Bouton ajustement manuel (visible uniquement en état idle)
          if (_destination == null)
            GestureDetector(
              onTap: _togglePickupAdjustment,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isAdjustingPickup ? drapeauVert.withValues(alpha:0.12) : _c.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_location_alt,
                    color: _isAdjustingPickup ? drapeauVert : _c.onSurfaceVariant, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDestinationRow() {
    final bool hasDestination = _destination != null;

    return GestureDetector(
      onTap: _openDestinationPicker,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [drapeauBleu, bleuPrincipal],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              hasDestination
                  ? (_destination!.address ?? _destination!.name)
                  : tr('destination_hint'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: hasDestination ? FontWeight.w600 : FontWeight.w500,
                color: hasDestination ? _c.onSurface : _c.onSurfaceVariant,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          // Bouton modifier (si destination choisie) ou chevron
          if (hasDestination)
            GestureDetector(
              onTap: _clearDestination,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, color: _c.onSurfaceVariant, size: 18),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: drapeauBleu, size: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CARTE GPS SIMPLE (état idle)
  // ─────────────────────────────────────────────────────────
  Widget _buildGpsMap() {
    final displayPos = _pickupLatLng ?? _djiboutiCenter;

    return Container(
      height: MediaQuery.of(context).size.height * 0.32,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: displayPos,
                initialZoom: 15,
                maxZoom: 18, minZoom: 10,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, latLng) => _onMapTap(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                  userAgentPackageName: 'com.nomade253.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: displayPos, width: 70, height: 70,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: blanc, width: 3),
                          boxShadow: [BoxShadow(color: secondaryColor.withValues(alpha:0.5), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.person_pin_circle, color: blanc, size: 28),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
            // Bouton recentrer
            Positioned(bottom: 16, right: 16, child: _mapFab(
              icon: Icons.my_location,
              color: drapeauBleu,
              onTap: () { if (_pickupLatLng != null) _mapController.move(_pickupLatLng!, 15); },
            )),
            // Badge ajustement
            if (_isAdjustingPickup)
              Positioned(top: 16, left: 16, child: _adjustBadge()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CARTE ROUTE (état avec destination)
  // ─────────────────────────────────────────────────────────
  Widget _buildRouteMap() {
    if (_pickupLatLng == null || _destination == null) return const SizedBox.shrink();

    final pickup = _pickupLatLng!;
    final dest = _destination!.location;
    final centerLat = (pickup.latitude + dest.latitude) / 2;
    final centerLng = (pickup.longitude + dest.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    // Zoom adaptatif selon la distance
    double zoom = 14;
    if (_distanceKm > 20) { zoom = 11; }
    else if (_distanceKm > 10) { zoom = 12; }
    else if (_distanceKm > 5) { zoom = 13; }
    else if (_distanceKm < 2) { zoom = 15; }

    return Container(
      height: MediaQuery.of(context).size.height * 0.32,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: 18, minZoom: 8,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                  userAgentPackageName: 'com.nomade253.app',
                ),
                // Ligne route pickup → destination
                PolylineLayer(polylines: [
                  Polyline(
                    points: [pickup, dest],
                    color: secondaryColor,
                    strokeWidth: 5,
                    borderColor: Colors.white.withValues(alpha:0.8),
                    borderStrokeWidth: 3,
                  ),
                ]),
                MarkerLayer(markers: [
                  // Marker pickup — dot vert
                  Marker(
                    point: pickup, width: 50, height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: drapeauVert,
                        shape: BoxShape.circle,
                        border: Border.all(color: blanc, width: 3),
                        boxShadow: [BoxShadow(color: drapeauVert.withValues(alpha:0.4), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.circle, color: blanc, size: 14),
                    ),
                  ),
                  // Marker destination — pin bleu
                  Marker(
                    point: dest, width: 56, height: 66,
                    child: Icon(
                      Icons.location_pin,
                      color: drapeauBleu,
                      size: 56,
                      shadows: [Shadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                  ),
                ]),
              ],
            ),

            // Badge infos trajet (distance + durée)
            Positioned(
              bottom: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _c.surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.12), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 13, color: _c.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${_distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _c.onSurface)),
                    const SizedBox(width: 10),
                    Icon(Icons.timer_outlined, size: 13, color: _c.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('$_durationMin min',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _c.onSurface)),
                  ],
                ),
              ),
            ),

            // Bouton modifier destination
            Positioned(
              top: 12, right: 12,
              child: _mapFab(
                icon: Icons.edit_location_alt,
                color: drapeauBleu,
                onTap: _openDestinationPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SÉLECTEUR VÉHICULE UNIQUE (horizontal avec RideChoiceCard)
  // Affiche les prix de base si pas de destination, prix calculés si destination
  // ─────────────────────────────────────────────────────────
  Widget _buildVehicleSelector() {
    final vehicles = MockTaxiData.allRideChoices;
    final bool hasDestination = _destination != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: vehicles.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: RideChoiceCard(
                ride: v,
                distance: hasDestination ? _distanceKm : 0.0,
                isSelected: _selectedRide.id == v.id,
                onTap: () => setState(() => _selectedRide = v),
                c: _c,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BOUTON "Choisir une destination" (état idle)
  // ─────────────────────────────────────────────────────────
  Widget _buildChooseDestinationButton() {
    final bool canTap = _pickupLatLng != null && !_isLoadingPickup;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        decoration: BoxDecoration(
          color: canTap ? kNeonGreen : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(30),
          boxShadow: canTap
              ? [BoxShadow(color: kNeonGreen.withValues(alpha:0.35), blurRadius: 14, offset: const Offset(0, 8))]
              : [],
        ),
        child: ElevatedButton(
          onPressed: canTap ? _openDestinationPicker : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canTap ? Icons.search : Icons.location_searching,
                color: canTap ? kNeonGreenDark : Colors.white70, size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                canTap ? tr('choose_destination') : tr('locating_in_progress'),
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  color: canTap ? kNeonGreenDark : Colors.white70, letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BOUTON "Confirmer la course" (état avec destination)
  // ─────────────────────────────────────────────────────────
  Widget _buildConfirmButton() {
    final price = _selectedRide.calculatePrice(_distanceKm);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: kNeonGreen,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: kNeonGreen.withValues(alpha:0.4), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _confirmRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_taxi, color: kNeonGreenDark, size: 22),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('confirm_ride'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kNeonGreenDark, letterSpacing: 0.3)),
                  Text('${price.toStringAsFixed(0)} FDJ · ${_selectedRide.name}',
                      style: const TextStyle(fontSize: 12, color: kNeonGreenDark)),
                ],
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, color: kNeonGreenDark, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS UI
  // ─────────────────────────────────────────────────────────
  Widget _mapFab({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _c.surfaceLow,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.15), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _adjustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kNeonGreen,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: kNeonGreen.withValues(alpha:0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, color: kNeonGreenDark, size: 14),
          const SizedBox(width: 6),
          Text(tr('tap_to_move'),
              style: const TextStyle(color: kNeonGreenDark, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}