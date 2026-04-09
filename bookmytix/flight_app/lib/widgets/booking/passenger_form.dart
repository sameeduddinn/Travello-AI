import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/user.dart';
import 'package:flight_app/utils/picker.dart';
import 'package:flight_app/widgets/booking/passenger_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PassengerForm extends StatefulWidget {
  const PassengerForm({ super.key, this.totalPassengers = 1 });

  final int totalPassengers;

  @override
  State<PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<PassengerForm> {
  bool _isSame = true;
  List<User> _passenggers = [passengerList[0]];
  String _selectedId = '1';

  void openUserPicker(BuildContext context, int index) {
    openRadioPicker(
      context: context,
      options: passengerOptions,
      title: 'Choose Passenger',
      initialValue: _selectedId,
      onSelected: (value) {
        if (value != null) {
          User result = passengerList.firstWhere((e) => e.id == value);
          setState(() {
            _selectedId = result.id;
            _passenggers[index] = result;

            if(_passenggers[0] != userList[0]) {
              _isSame = false;
            }
          });
        }
      }
    );
  }

  @override
  void initState() {
    super.initState();
    List <User>initPsg = List.generate(widget.totalPassengers - 1, (index) => userInit);
    Future.delayed(Durations.short1, () {
      setState(() {
        _passenggers = [userList[0], ...initPsg];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      /// FIRST PASSENGERS
      const VSpace(),
      TitleAction(
        title: 'Contact Detail',
        size: 'small',
        textAction: 'EDIT',
        onTap: () {
          Get.toNamed(AppLink.editProfile);
        }
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme(context).outline.withValues(alpha: 0.5),
          borderRadius: ThemeRadius.medium
        ),
        child: ListView(shrinkWrap: true, physics: const ClampingScrollPhysics(), children: [
          ListTile(
            title: Text('Name', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurface)),
            trailing: Text(userDummy.name, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
            contentPadding: const EdgeInsets.all(0),
          ),
          ListTile(
            title: Text('Email', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurface)),
            trailing: Text(userDummy.email, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
            contentPadding: const EdgeInsets.all(0),
          ),
          ListTile(
            title: Text('Phone', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurface)),
            trailing: Text(userDummy.phone, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onSurface)),
            contentPadding: const EdgeInsets.all(0),
          ),
        ]),
      ),
      const VSpaceBig(),

      /// FIRST PASSENGERS
      const TitleBasic(title: 'Passengger Info', size: 'small'),
      AppInputBox(
        content: ListView(
          padding: const EdgeInsets.all(0),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          children: [
            ListTile(
              title: const Text('Same as contact details', style: TravelloTheme.paragraphBold),
              contentPadding: const EdgeInsets.all(0),
              minTileHeight: 0,
              trailing: Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: _isSame,
                  onChanged: (bool value) {
                    setState(() {
                      _isSame = value;
                      if (value == true) {
                        _passenggers[0] = userList[0];
                      } else {
                        _passenggers[0] = userInit;
                      }
                    });
                  },
                ),
              ),
            ),
            Divider(color: colorScheme(context).outline),
            ListTile(
              title: Text('Passenger 1', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurfaceVariant)),
              contentPadding: const EdgeInsets.all(0),
              minTileHeight: 0,
              subtitle: _passenggers[0].id != '0' ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_passenggers[0].title} ${_passenggers[0].name}', style: TravelloTheme.headline.copyWith(color: colorScheme(context).onSurface)),
                Text('ID Number: ${_passenggers[0].idCard}', style: TravelloTheme.paragraph),
              ]) : Container(),
              trailing: Icon(_passenggers[0].id != '0' ? Icons.edit : CupertinoIcons.add_circled, color: TravelloTheme.primaryMain),
              onTap: () {
                openUserPicker(context, 0);
              },
            ),
          ]
        )
      ),

      /// OTHER PASSENGERS
      _passenggers.length > 1 ? ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: widget.totalPassengers - 1,
        itemBuilder: ((BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppInputBox(
              content: ListTile(
                minTileHeight: 0,
                title: Text('Passenger ${index + 2}', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurfaceVariant)),
                contentPadding: const EdgeInsets.all(0),
                subtitle: _passenggers[index + 1].id != '0' ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_passenggers[index + 1].title} ${_passenggers[index + 1].name}', style: TravelloTheme.headline.copyWith(color: colorScheme(context).onSurface)),
                  Text('ID Number: ${_passenggers[index + 1].idCard}', style: TravelloTheme.paragraph),
                ]) : Container(),
                trailing: Icon(_passenggers[index + 1].id != '0' ? Icons.edit : CupertinoIcons.add_circled, color: TravelloTheme.primaryMain),
                onTap: () {
                  openUserPicker(context, index + 1);
                },
              ),
            ),
          );
        })
      ) : Container(),
      const VSpaceShort(),
      TextButton(
        onPressed: () {
          Get.toNamed(AppLink.addPassengger);
        },
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline, size: 16),
          SizedBox(width: 4),
          Text('Add New Passengger')
        ])
      ),
      const VSpaceBig(),
    ]);
  }
}