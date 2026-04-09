import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/cards/flight_wide_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightTripList extends StatelessWidget {
  const FlightTripList(
      {super.key,
      this.withEdit = false,
      this.scrollRef,
      required this.flightData});

  final bool withEdit;
  final ScrollController? scrollRef;
  final List<Trip> flightData;

  @override
  Widget build(BuildContext context) {
    bool wideScreen = ThemeBreakpoints.smUp(context);

    return flightData.isNotEmpty
        ? ListView.builder(
            controller: scrollRef,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            itemCount: flightData.length,
            itemBuilder: (context, index) {
              Trip item = flightData[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    Get.toNamed(AppLink.flightDetail);
                  },
                  child: wideScreen
                      ? FlightWideCard(
                          from: item.from,
                          to: item.to,
                          plane: item.plane,
                          price: item.price,
                          depart: item.depart,
                          arrival: item.arrival,
                          transit: item.transit,
                          discount: item.discount,
                          label: item.label,
                          withEdit: withEdit,
                        )
                      : FlightCard(
                          from: item.from,
                          to: item.to,
                          plane: item.plane,
                          price: item.price,
                          depart: item.depart,
                          arrival: item.arrival,
                          transit: item.transit,
                          discount: item.discount,
                          label: item.label,
                          withEdit: withEdit,
                        ),
                ),
              );
            },
          )
        : _emptyList(context);
  }

  Widget _emptyList(BuildContext context) {
    return NoData(
      image: ImgApi.emptyTrip,
      title: 'Destination Not Found',
      desc:
          'No saved trips yet. Start exploring destinations and plan your next adventure.',
      primaryAction: () {
        Get.toNamed(AppLink.searchFlight);
      },
      primaryTxtBtn: 'SEARCH ANOTHER DESTINATION',
    );
  }
}
