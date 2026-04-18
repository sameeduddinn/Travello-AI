import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/cards/flight_wide_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class RoundTripReview extends StatelessWidget {
  const RoundTripReview({super.key, this.onEditDepart, this.onEditReturn});

  final Function()? onEditDepart;
  final Function()? onEditReturn;

  @override
  Widget build(BuildContext context) {
    final Trip item = tripList[1];
    final Trip item2 = tripList[2];
    bool wideScreen = ThemeBreakpoints.smUp(context);

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Departure', style: TravelloTheme.title2),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: wideScreen ? FlightWideCard(
          from: item.from,
          to: item.to,
          plane: item.plane,
          price: item.price,
          depart: item.depart,
          arrival: item.arrival,
          transit: item.transit,
          discount: item.discount,
          label: item.label,
          withEdit: true,
          onEdit: onEditDepart,
        ) : FlightCard(
          from: item.from,
          to: item.to,
          plane: item.plane,
          price: item.price,
          depart: item.depart,
          arrival: item.arrival,
          transit: item.transit,
          discount: item.discount,
          label: item.label,
          withEdit: true,
          onEdit: onEditDepart,
        ),
      ),
      const VSpaceShort(),
      const Text('Return', style: TravelloTheme.title2),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FlightCard(
          from: item2.from,
          to: item2.to,
          plane: item2.plane,
          price: item2.price,
          depart: item2.depart,
          arrival: item2.arrival,
          transit: item2.transit,
          discount: item2.discount,
          label: item2.label,
          withEdit: true,
          onEdit: onEditReturn,
        ),
      ),
      const VSpaceShort(),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            Get.toNamed(AppLink.addPassengger);
          },
          style: ThemeButton.btnBig.merge(ThemeButton.outlinedPrimary(context)),
          child: Text('Add Passengers Data'.toUpperCase(), style: TravelloTheme.headline,),
        ),
      ),
      const VSpaceBig()
    ]);
  }
}