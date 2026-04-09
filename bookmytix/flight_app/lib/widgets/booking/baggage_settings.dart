import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/app_input/app_input_number.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class BaggageSettings extends StatelessWidget {
  const BaggageSettings({
    super.key,
    required this.baggageGroup, required this.setBaggage,
    required this.setDeepState, required this.index
  });

  final List<double> baggageGroup;
  final Function(String, int, double) setBaggage;
  final StateSetter setDeepState;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(children: [
        Column(children: [
          const GrabberIcon(),
          const VSpaceShort(),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.home_repair_service, size: 22),
            SizedBox(width: 8,),
            Text('Adjust Baggage', style: TravelloTheme.subtitle2)
          ],),
          const VSpaceShort(),
          AppInputBox(content: Row(children: [
            const Expanded(child: ListTile(
              contentPadding: EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: Text('Baggages', style: TravelloTheme.paragraph),
              subtitle: Text('\$100/10Kg (Maximum 80Kg)', style: TravelloTheme.caption,),
            )),
            const SizedBox(width: 8),
            AppInputNumber(
              onAdd: () {
                if (baggageGroup[index] >= 80) {
                  return;
                }
                setDeepState(() {
                  setBaggage('add', index, 10);
                });
              },
              onRemove: () {
                if (baggageGroup[index] <= 20) {
                  return;
                }
                setDeepState(() {
                  setBaggage('remove', index, 10);
                });
              },
              value: baggageGroup[index],
              unit: 'Kg',
            ),
          ])),
          const VSpaceShort(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Get.back();
                },
                style: ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
                child: Text('Done'.toUpperCase(), style: TravelloTheme.subtitle)
              ),
            )
          ),
          const VSpace()
        ])
      ]),
    );
  }
}