import 'package:change_case/change_case.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ChoosePassengger extends StatelessWidget {
  const ChoosePassengger({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const VSpaceShort(),
      const Text('Choose Passengger',
          textAlign: TextAlign.center, style: TravelloTheme.subtitle),
      const VSpaceShort(),
      ListView.builder(
          itemCount: 3,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: spacingUnit(5)),
          itemBuilder: ((BuildContext context, int index) {
            User item = passengerList[index];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text('${item.title} ${item.name}'),
              subtitle:
                  item.type != null ? Text(item.type!.toCapitalCase()) : null,
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: TravelloTheme.primaryMain),
              onTap: () {
                Get.toNamed(AppLink.eTicket);
              },
            );
          })),
    ]);
  }
}
