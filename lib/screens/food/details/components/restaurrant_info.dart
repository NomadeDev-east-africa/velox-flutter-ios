import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../components/rating_with_counter.dart';
import '../../../../constants.dart';
import '../../../../translations/app_translations.dart';
import '../../../../models/restaurant.dart';
import '../../../../services/menu_service.dart';

class RestaurantInfo extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantInfo({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantInfo> createState() => _RestaurantInfoState();
}

class _RestaurantInfoState extends State<RestaurantInfo> {
  int _averageTime = 25;

  @override
  void initState() {
    super.initState();
    _loadAverageTime();
  }

  Future<void> _loadAverageTime() async {
    final time = await MenuService().getAveragePreparationTime(widget.restaurant.id);
    if (mounted) {
      setState(() {
        _averageTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.restaurant.name,
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 1,
          ),
          const SizedBox(height: defaultPadding / 2),
          Text(
            widget.restaurant.address,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: defaultPadding / 2),
          RatingWithCounter(
            rating: widget.restaurant.rating,
            numOfRating: widget.restaurant.totalOrders,
          ),
          const SizedBox(height: defaultPadding),
          Row(
            children: [
              DeliveryInfo(
                iconSrc: "assets/icons/delivery.svg",
                text: tr('free'),
                subText: tr('delivery'),
              ),
              const SizedBox(width: defaultPadding),
              DeliveryInfo(
                iconSrc: "assets/icons/clock.svg",
                text: "$_averageTime",
                subText: tr('minutes'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Take away"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeliveryInfo extends StatelessWidget {
  const DeliveryInfo({
    super.key,
    required this.iconSrc,
    required this.text,
    required this.subText,
  });

  final String iconSrc, text, subText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          iconSrc,
          height: 20,
          width: 20,
          colorFilter: const ColorFilter.mode(
            primaryColor,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            text: "$text\n",
            style: Theme.of(context).textTheme.labelLarge,
            children: [
              TextSpan(
                text: subText,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(fontWeight: FontWeight.normal),
              )
            ],
          ),
        ),
      ],
    );
  }
}
