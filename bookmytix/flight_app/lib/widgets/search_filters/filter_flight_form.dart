import 'package:flight_app/models/plane.dart';
import 'package:flight_app/ui/themes/theme_button.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class FilterFlightForm extends StatelessWidget {
  const FilterFlightForm({
    super.key,
    required this.onChangePrice, required this.onUpdateAirlines,
    required this.onUpdateTransit, required this.onChangeDuration,
    required this.priceRange, required this.selectedAirlines,
    required this.transits, required this.duration
  });

  // Function
  final Function(RangeValues) onChangePrice;
  final Function(String, Plane) onUpdateAirlines;
  final Function(String, int) onUpdateTransit;
  final Function(double) onChangeDuration;
  // Variables
  final RangeValues priceRange;
  final List<Plane> selectedAirlines;
  final List<int> transits;
  final double duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(spacingUnit(2)),
      child: Column(children: [
        const GrabberIcon(),
        const VSpaceShort(),
        const TitleBasic(title: 'Filters'),
        const VSpaceShort(),

        Expanded(
          child: ListView(shrinkWrap: true, physics: const ClampingScrollPhysics(), children: [
            /// PRICE RANGE
            Row(
              children: [
                const Icon(Icons.price_change_outlined),
                const Text(' Range Price:', style: ThemeText.subtitle2),
                SizedBox(width: spacingUnit(1)),
                Text('\$${priceRange.start.round()} - \$${priceRange.end.round()}', style: ThemeText.subtitle2.copyWith(color: colorScheme(context).onSecondaryContainer))
              ],
            ),
            SizedBox(height: spacingUnit(1)),
            RangeSlider(
              values: priceRange,
              max: 1000,
              divisions: 50,
              labels: RangeLabels(
                priceRange.start.round().toString(),
                priceRange.end.round().toString(),
              ),
              onChanged: (RangeValues values) {
                onChangePrice(values);
              },
            ),
            const VSpace(),

            /// TRANSITS
            const Row(
              children: [
                Icon(Icons.timeline_sharp),
                Text(' Transits', style: ThemeText.subtitle2),
              ],
            ),
            SizedBox(height: spacingUnit(1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: spacingUnit(2)),
                Row(
                  children: [
                    Checkbox(
                      value: transits.contains(0),
                      onChanged: (bool? value) {
                        if (value == true) {
                          onUpdateTransit('add', 0);
                        } else {
                          onUpdateTransit('remove', 0);
                        }
                      },
                    ),
                    const Text('Direct'),
                  ],
                ),
                SizedBox(width: spacingUnit(1)),
                Row(
                  children: [
                    Checkbox(
                      value: transits.contains(1),
                      onChanged: (bool? value) {
                        if (value == true) {
                          onUpdateTransit('add', 1);
                        } else {
                          onUpdateTransit('remove', 1);
                        }
                      },
                    ),
                    const Text('1 Stop'),
                  ],
                ),
                SizedBox(width: spacingUnit(1)),
                Row(
                  children: [
                    Checkbox(
                      value: transits.contains(2),
                      onChanged: (bool? value) {
                        if (value == true) {
                          onUpdateTransit('add', 2);
                        } else {
                          onUpdateTransit('remove', 2);
                        }
                      },
                    ),
                    const Text('2+ Stops'),
                  ],
                ),
              ],
            ),
            const VSpaceBig(),

            /// DURATION
            Row(
              children: [
                const Icon(Icons.access_time),
                const Text(' Maximum Trip Duration:', style: ThemeText.subtitle2),
                SizedBox(width: spacingUnit(1)),
                Text('$duration hours', style: ThemeText.subtitle2.copyWith(color: colorScheme(context).onSecondaryContainer))
              ],
            ),
            SizedBox(height: spacingUnit(1)),
            
            Slider(
              value: duration,
              max: 36,
              divisions: 36,
              label: duration.round().toString(),
              onChanged: (double value) {
                onChangeDuration(value);
              },
            ),
            const VSpace(),

            /// AIRLINES
            const Row(
              children: [
                Icon(Icons.flight),
                Text(' Airlines', style: ThemeText.subtitle2),
              ],
            ),
            SizedBox(height: spacingUnit(1)),
            ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: planeList.length,
              itemBuilder: (context, index) {
                final Plane item = planeList[index];
            
                return CheckboxListTile(
                  secondary: CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(item.logo),
                  ),
                  title: Text(item.name),
                  value: selectedAirlines.contains(item),
                  onChanged: (bool? value) {
                    if (value == true) {
                      onUpdateAirlines('add', item);
                    } else {
                      onUpdateAirlines('remove', item);
                    }
                  },
                );
              },
            ),
            const VSpaceBig(),
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(spacingUnit(1)),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Get.back();
              },
              style: ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
              child: Text('Done'.toUpperCase(), style: ThemeText.subtitle)
            ),
          )
        ),
        const VSpace()
      ])
    );
  }
}