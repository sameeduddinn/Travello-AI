import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/flight_package.dart';
import 'package:flight_app/widgets/cards/package_card.dart';
import 'package:flight_app/widgets/flight/package_options.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PackageList extends StatelessWidget {
  const PackageList({super.key});

  static const Map<String, String> _durationMap = {
    'Karachi-Lahore': '1h 30m',
    'Lahore-Karachi': '1h 30m',
    'Karachi-Islamabad': '2h 00m',
    'Islamabad-Karachi': '2h 00m',
    'Karachi-Rawalpindi': '2h 00m',
    'Rawalpindi-Karachi': '2h 00m',
    'Karachi-Peshawar': '2h 15m',
    'Peshawar-Karachi': '2h 15m',
    'Karachi-Multan': '1h 15m',
    'Multan-Karachi': '1h 15m',
    'Karachi-Quetta': '1h 30m',
    'Quetta-Karachi': '1h 30m',
    'Karachi-Faisalabad': '1h 30m',
    'Faisalabad-Karachi': '1h 30m',
    'Karachi-Sialkot': '1h 30m',
    'Sialkot-Karachi': '1h 30m',
    'Karachi-Gwadar': '1h 10m',
    'Gwadar-Karachi': '1h 10m',
    'Karachi-Gilgit': '2h 30m',
    'Gilgit-Karachi': '2h 30m',
    'Karachi-Skardu': '2h 30m',
    'Skardu-Karachi': '2h 30m',
    'Lahore-Islamabad': '0h 50m',
    'Islamabad-Lahore': '0h 50m',
    'Lahore-Rawalpindi': '0h 50m',
    'Rawalpindi-Lahore': '0h 50m',
    'Lahore-Peshawar': '1h 10m',
    'Peshawar-Lahore': '1h 10m',
    'Lahore-Multan': '1h 00m',
    'Multan-Lahore': '1h 00m',
    'Lahore-Quetta': '2h 00m',
    'Quetta-Lahore': '2h 00m',
    'Lahore-Faisalabad': '1h 00m',
    'Faisalabad-Lahore': '1h 00m',
    'Lahore-Sialkot': '0h 45m',
    'Sialkot-Lahore': '0h 45m',
    'Lahore-Gilgit': '1h 45m',
    'Gilgit-Lahore': '1h 45m',
    'Lahore-Skardu': '2h 00m',
    'Skardu-Lahore': '2h 00m',
    'Lahore-Gwadar': '2h 30m',
    'Gwadar-Lahore': '2h 30m',
    'Islamabad-Peshawar': '0h 45m',
    'Peshawar-Islamabad': '0h 45m',
    'Islamabad-Multan': '1h 15m',
    'Multan-Islamabad': '1h 15m',
    'Islamabad-Quetta': '1h 45m',
    'Quetta-Islamabad': '1h 45m',
    'Islamabad-Gilgit': '1h 30m',
    'Gilgit-Islamabad': '1h 30m',
    'Islamabad-Skardu': '1h 30m',
    'Skardu-Islamabad': '1h 30m',
    'Islamabad-Gwadar': '2h 15m',
    'Gwadar-Islamabad': '2h 15m',
    'Peshawar-Multan': '1h 15m',
    'Multan-Peshawar': '1h 15m',
    'Peshawar-Quetta': '2h 30m',
    'Quetta-Peshawar': '2h 30m',
    'Faisalabad-Islamabad': '1h 00m',
    'Islamabad-Faisalabad': '1h 00m',
    'Sialkot-Islamabad': '1h 00m',
    'Islamabad-Sialkot': '1h 00m',
  };

  String _getFlightDuration(String fromName, String toName) =>
      _durationMap['$fromName-$toName'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Explore the best packages!',
              textAlign: TextAlign.start,
              style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold)),
        ),
        const VSpace(),
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(
              top: 16, left: 16, right: 16),
          itemCount: packageList.length,
          itemBuilder: (BuildContext context, int index) {
            FlightPackage item = flightPackageList[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Get.toNamed(AppLink.flightDetailPackage);
                    },
                    child: PackageCard(
                      image: item.img,
                      label: item.label!,
                      from: item.from.name,
                      to: item.to.name,
                      date: item.date,
                      duration:
                          _getFlightDuration(item.from.name, item.to.name),
                      tags: item.tags != null ? item.tags! : [],
                      price: item.price,
                      plane: item.plane,
                    ),
                  )),
            );
          },
        )
      ],
    );
  }
}
