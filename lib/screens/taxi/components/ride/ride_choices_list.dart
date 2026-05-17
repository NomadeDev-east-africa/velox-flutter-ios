import 'package:flutter/material.dart';
import 'package:nomade_client/models/ride_choice.dart';
import 'package:nomade_client/data/mock_taxi_data.dart';
import 'ride_choice_card.dart';

/// Liste des choix de véhicules
class RideChoicesList extends StatefulWidget {
  const RideChoicesList({
    super.key,
    required this.distance,
    required this.onRideSelected,
    this.selectedRideId,
  });

  final double distance;
  final ValueChanged<RideChoice> onRideSelected;
  final String? selectedRideId;

  @override
  State<RideChoicesList> createState() => _RideChoicesListState();
}

class _RideChoicesListState extends State<RideChoicesList> {
  late RideChoice selectedRide;

  @override
  void initState() {
    super.initState();
    // Sélectionner le premier véhicule par défaut
    selectedRide = widget.selectedRideId != null
        ? MockTaxiData.allRideChoices.firstWhere(
          (r) => r.id == widget.selectedRideId,
      orElse: () => MockTaxiData.defaultRideChoice,
    )
        : MockTaxiData.defaultRideChoice;
  }

  @override
  Widget build(BuildContext context) {
    final rideChoices = MockTaxiData.allRideChoices;

    return ListView.separated(
      // CORRECTION: Permet le scroll et enlève shrinkWrap
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rideChoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final ride = rideChoices[index];
        final isSelected = ride.id == selectedRide.id;

        return RideChoiceCard(
          ride: ride,
          distance: widget.distance,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              selectedRide = ride;
            });
            widget.onRideSelected(ride);
          },
        );
      },
    );
  }
}