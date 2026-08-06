import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/app_input/app_input_number.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

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
      color: TravelloTheme.paperLight,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const GrabberIcon(),
          const VSpaceShort(),
          const TitleBasic(title: 'Passengers'),
          const SizedBox(height: 8),
          AppInputBox(
              content: Row(children: [
            const Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.user,
                  size: 24, color: TravelloTheme.primaryMain),
              contentPadding: EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: Text('Adults'),
              subtitle: Text('Age 12 and over'),
            )),
            const SizedBox(width: 8),
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
            const Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.child,
                  size: 24, color: TravelloTheme.primaryMain),
              contentPadding: EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: Text('Child'),
              subtitle: Text('Age 2-11'),
            )),
            const SizedBox(width: 8),
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
            const Expanded(
                child: ListTile(
              leading: Icon(FontAwesomeIcons.baby,
                  size: 24, color: TravelloTheme.primaryMain),
              contentPadding: EdgeInsets.all(0),
              minTileHeight: 0,
              minVerticalPadding: 0,
              title: Text('Infant'),
              subtitle: Text('Below Age 2'),
            )),
            const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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
                const SizedBox(width: 8),
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
          const SizedBox(height: 16),
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
                child: Text('Done'.toUpperCase(), style: TravelloTheme.subtitle)),
          ),
          const VSpace()
        ],
      ),
    );
  }
}
