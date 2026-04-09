import 'package:flight_app/ui/themes/theme_button.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/app_input/app_input_number.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class PassenggerClass extends StatelessWidget {
  const PassenggerClass(
      {super.key,
      required this.addPassenggers,
      required this.removePassenggers,
      required this.passengers,
      required this.setClass,
      required this.classType});

  final List<double> passengers;
  final String classType;
  final Function(String) addPassenggers;
  final Function(String) removePassenggers;
  final Function(String) setClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme(context).surface,
      padding: EdgeInsets.all(spacingUnit(2)),
      child: Column(
        children: [
          const GrabberIcon(),
          const VSpaceShort(),
          const TitleBasic(title: 'Passengers'),
          SizedBox(height: spacingUnit(1)),
          AppInputBox(
              content: Row(children: [
            Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.user,
                  size: 24, color: ThemePalette.primaryMain),
              contentPadding: const EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: const Text('Adults'),
              subtitle: const Text('Age 12 and over'),
            )),
            SizedBox(width: spacingUnit(1)),
            AppInputNumber(
              onAdd: () {
                addPassenggers('adults');
              },
              onRemove: () {
                removePassenggers('adults');
              },
              value: passengers[0],
            ),
          ])),
          const VSpaceShort(),
          AppInputBox(
              content: Row(children: [
            Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.child,
                  size: 24, color: ThemePalette.primaryMain),
              contentPadding: const EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: const Text('Child'),
              subtitle: const Text('Age 2-11'),
            )),
            SizedBox(width: spacingUnit(1)),
            AppInputNumber(
              onAdd: () {
                addPassenggers('children');
              },
              onRemove: () {
                removePassenggers('childs');
              },
              value: passengers[1],
            ),
          ])),
          const VSpaceShort(),
          AppInputBox(
              content: Row(children: [
            Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.baby,
                  size: 24, color: ThemePalette.primaryMain),
              contentPadding: const EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: const Text('Infant'),
              subtitle: const Text('Below Age 2'),
            )),
            SizedBox(width: spacingUnit(1)),
            AppInputNumber(
              onAdd: () {
                addPassenggers('infants');
              },
              onRemove: () {
                removePassenggers('infants');
              },
              value: passengers[2],
            ),
          ])),
          const VSpace(),
          const TitleBasic(title: 'Flight Class'),
          SizedBox(height: spacingUnit(1)),
          SizedBox(
            child: Row(
              children: [
                Expanded(
                    child: TagButton(
                        text: 'Economy',
                        size: BtnSize.big,
                        selected: classType == 'Economy',
                        onPressed: () {
                          setClass('Economy');
                        })),
                SizedBox(width: spacingUnit(1)),
                Expanded(
                    child: SizedBox(
                        height: 34,
                        child: TagButton(
                            text: 'Premium Economy',
                            size: BtnSize.medium,
                            selected: classType == 'Premium Economy',
                            onPressed: () {
                              setClass('Premium Economy');
                            }))),
              ],
            ),
          ),
          SizedBox(height: spacingUnit(2)),
          Row(
            children: [
              Expanded(
                  child: TagButton(
                      text: 'Business',
                      size: BtnSize.big,
                      selected: classType == 'Business',
                      onPressed: () {
                        setClass('Business');
                      })),
              SizedBox(width: spacingUnit(1)),
              Expanded(
                  child: TagButton(
                      text: 'First Class',
                      size: BtnSize.big,
                      selected: classType == 'First Class',
                      onPressed: () {
                        setClass('First Class');
                      })),
            ],
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: () {
                  Get.back();
                },
                style:
                    ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
                child: Text('Done'.toUpperCase(), style: ThemeText.subtitle)),
          ),
          const VSpace()
        ],
      ),
    );
  }
}
