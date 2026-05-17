import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/models/place.dart';
import 'package:nomade_client/models/trip_details.dart';
import 'package:nomade_client/models/ride_choice.dart';
import 'tracking_screen.dart';

// ✅ PHASE 3 : import ride_provider.dart SUPPRIMÉ
// ✅ PHASE 3 : import provider.dart SUPPRIMÉ (plus besoin de context.read<RideProvider>)

const djBlue     = Color(0xFF6AB2E7);
const djGreen    = Color(0xFF12AD2B);
const djRed      = Color(0xFFCE1126);
const djWhite    = Color(0xFFFFFFFF);
const djDarkText = Color(0xFF263238);
const djGrey     = Color(0xFF757575);
const djLightGrey= Color(0xFFEEEEEE);

class RideConfirmationScreen extends ConsumerStatefulWidget {
  final Place      pickup;
  final Place      destination;
  final TripDetails tripDetails;

  const RideConfirmationScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.tripDetails,
  });

  @override
  ConsumerState<RideConfirmationScreen> createState() =>
      _RideConfirmationScreenState();
}

class _RideConfirmationScreenState
    extends ConsumerState<RideConfirmationScreen> {

  String _selectedPaymentMethod = 'mobile_wallet';

  // ════════════════════════════════════════════════════════════
  // CONFIRMER LA COURSE
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmRide() async {
    // ✅ Riverpod — plus de context.read<UserProvider>()
    final userState = ref.read(userNotifierProvider);
    if (!userState.isAuthenticated) return;

    try {
      final price = widget.tripDetails.selectedRide
          .calculatePrice(widget.tripDetails.distance);

      // ✅ Riverpod — plus de context.read<RideProvider>().createRide()
      await ref.read(activeRideProvider.notifier).createRide(
        userId:               userState.userId!,
        userName:             userState.displayName,
        userPhone:            userState.displayPhone ?? '',
        userPhotoUrl:         userState.displayPhotoUrl,
        pickupLatitude:       widget.pickup.location.latitude,
        pickupLongitude:      widget.pickup.location.longitude,
        pickupAddress:        widget.pickup.address ?? widget.pickup.name,
        pickupPlaceName:      widget.pickup.name,
        destinationLatitude:  widget.destination.location.latitude,
        destinationLongitude: widget.destination.location.longitude,
        destinationAddress:   widget.destination.address ?? widget.destination.name,
        destinationPlaceName: widget.destination.name,
        distance:             widget.tripDetails.distance,
        estimatedDuration:    widget.tripDetails.duration,
        estimatedFare:        price,
        paymentMethod:        _selectedPaymentMethod,
        vehicleType:          widget.tripDetails.selectedRide.id,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrackingScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS CARTE
  // ════════════════════════════════════════════════════════════

  LatLng _getMiddlePoint(LatLng start, LatLng end) {
    return LatLng(
      (start.latitude  + end.latitude)  / 2,
      (start.longitude + end.longitude) / 2,
    );
  }

  Widget _buildCarMarker() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: djBlue.withValues(alpha:0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Transform.scale(
          scale: 0.6,
          child: _getVehicleImage(widget.tripDetails.selectedRide),
        ),
      ),
    );
  }

  Widget _getVehicleIcon(RideChoice rideChoice) {
    final name = rideChoice.name.toLowerCase();
    if (name.contains('comfort') || name.contains('confort')) {
      return const Column(children: [
        Icon(Icons.airline_seat_individual_suite, color: djGreen, size: 32),
        SizedBox(height: 4),
        Text('Confort', style: TextStyle(fontSize: 10)),
      ]);
    } else if (name.contains('van') || name.contains('minibus')) {
      return const Column(children: [
        Icon(Icons.airport_shuttle, color: djRed, size: 32),
        SizedBox(height: 4),
        Text('Van', style: TextStyle(fontSize: 10)),
      ]);
    } else {
      return const Column(children: [
        Icon(Icons.directions_car, color: djBlue, size: 32),
        SizedBox(height: 4),
        Text('Standard', style: TextStyle(fontSize: 10)),
      ]);
    }
  }

  Widget _getVehicleImage(RideChoice rideChoice) {
    final name = rideChoice.name.toLowerCase();
    final id   = rideChoice.id.toLowerCase();

    String imagePath;
    if (id.contains('comfort') || name.contains('comfort')) {
      imagePath = 'assets/vehicule/taxi-A.png';
    } else if (id.contains('van') || name.contains('van') || name.contains('minibus')) {
      imagePath = 'assets/vehicule/taxiprobox.png';
    } else {
      imagePath = 'assets/vehicule/taxi-B.png';
    }

    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      width: 50,
      height: 50,
      errorBuilder: (_, _, _) => _getVehicleIcon(rideChoice),
    );
  }

  String _getCarModel(RideChoice rideChoice) {
    final name = rideChoice.name.toLowerCase();
    if (name.contains('comfort') || name.contains('confort')) return 'Toyota Prius';
    if (name.contains('van')     || name.contains('minibus'))  return 'Toyota Hiace';
    return 'Toyota Corolla';
  }

  Color _getVehicleColor(RideChoice rideChoice) {
    final name = rideChoice.name.toLowerCase();
    if (name.contains('comfort') || name.contains('confort')) return djGreen.withValues(alpha:0.1);
    if (name.contains('van')     || name.contains('minibus'))  return djRed.withValues(alpha:0.1);
    return djBlue.withValues(alpha:0.1);
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final price = widget.tripDetails.selectedRide
        .calculatePrice(widget.tripDetails.distance);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(color: djLightGrey.withValues(alpha:0.3)),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMapPreview(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Détails de la course',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: djDarkText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildCheckboxList(),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 20),
                          child: Divider(color: djLightGrey, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildUserCard(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildPriceSection(price),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildPaymentSection(),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // WIDGETS UI (identiques à l'original)
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: djDarkText),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Confirmer votre course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: djDarkText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.pickup.location,
                initialZoom: 12.0,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [widget.pickup.location, widget.destination.location],
                      strokeWidth: 4,
                      color: djBlue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.pickup.location,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: djGreen.withValues(alpha:0.5), blurRadius: 4)],
                        ),
                        child: Icon(Icons.circle, color: djGreen, size: 12),
                      ),
                    ),
                    Marker(
                      point: widget.destination.location,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: djRed.withValues(alpha:0.5), blurRadius: 4)],
                        ),
                        child: Icon(Icons.circle, color: djRed, size: 12),
                      ),
                    ),
                    Marker(
                      point: _getMiddlePoint(
                          widget.pickup.location, widget.destination.location),
                      width: 50,
                      height: 50,
                      child: _buildCarMarker(),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: djBlue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.tripDetails.duration} min',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxList() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.radio_button_checked,
          color: djGreen,
          text: widget.pickup.address ?? widget.pickup.name,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.location_on,
          color: djBlue,
          text: widget.destination.address ?? widget.destination.name,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.timer_outlined,
          color: djRed,
          text: 'Durée estimée : ${widget.tripDetails.duration} min',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.straighten,
          color: djGreen,
          text: 'Distance : ${widget.tripDetails.distance.toStringAsFixed(1)} km',
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: djDarkText, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard() {
    // ✅ Riverpod — ref.watch pour la réactivité
    final userState = ref.watch(userNotifierProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: djLightGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: djBlue.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: userState.displayPhotoUrl != null &&
                    userState.displayPhotoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      userState.displayPhotoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.person, color: djBlue, size: 30),
                    ),
                  )
                : Icon(Icons.person, color: djBlue, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userState.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  userState.displayPhone ?? 'Téléphone non renseigné',
                  style: TextStyle(fontSize: 14, color: djGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCarModel(widget.tripDetails.selectedRide),
                  style: TextStyle(
                    fontSize: 13,
                    color: djGrey.withValues(alpha:0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getVehicleColor(widget.tripDetails.selectedRide),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _getVehicleImage(widget.tripDetails.selectedRide),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(double price) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: djLightGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Prix total',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            '${price.toStringAsFixed(0)} FDJ',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: djGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: djLightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paiement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showPaymentMethods,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: djLightGrey.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: djLightGrey),
              ),
              child: Row(
                children: [
                  Icon(Icons.wallet, color: djBlue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Portefeuille Mobile',
                          style: TextStyle(fontSize: 16))),
                  Icon(Icons.arrow_forward_ios, color: djGrey, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    // ✅ Afficher un indicateur si création en cours
    final isCreating = ref.watch(
        activeRideProvider.select((s) => s.isCreating));

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isCreating ? null : _confirmRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: djGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: isCreating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Confirmer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  void _showPaymentMethods() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir un moyen de paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPaymentOption(
                'mobile_wallet', 'Portefeuille Mobile', Icons.wallet),
            _buildPaymentOption('cash', 'Espèces', Icons.money),
            _buildPaymentOption('card', 'Carte bancaire', Icons.credit_card),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData icon) {
    return RadioGroup<String>(
      groupValue: _selectedPaymentMethod,
      onChanged: (String? v) {
        setState(() => _selectedPaymentMethod = v!);
        Navigator.pop(context);
      },
      child: ListTile(
        leading: Icon(icon, color: djBlue),
        title: Text(title),
        trailing: Radio<String>(
          value: value,
          activeColor: djGreen,
        ),
        onTap: () {
          setState(() => _selectedPaymentMethod = value);
          Navigator.pop(context);
        },
      ),
    );
  }
}
