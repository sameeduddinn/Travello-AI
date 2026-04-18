import 'package:flight_app/models/booking.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/booking/baggage_settings.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class BaggageForm extends StatefulWidget {
  const BaggageForm({super.key, required this.totalPassengers});

  final int totalPassengers;

  @override
  State<BaggageForm> createState() => _BaggageFormState();
}

class _BaggageFormState extends State<BaggageForm> {
  List<double> _baggageGroup = [];

  void setBaggage(String type, int index, double val) {
    setState(() {
      if(type == 'add') {
        _baggageGroup[index] += val;
      } else {
        _baggageGroup[index] -= val;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    List <double>initBaggage = List.generate(widget.totalPassengers, (index) => 20);
    Future.delayed(Durations.short1, () {
      setState(() {
        _baggageGroup = initBaggage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    /// BAGAGE POPUP
    void showBaggageSheet(int index) async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return BaggageSettings(
            baggageGroup: _baggageGroup,
            setBaggage: setBaggage,
            setDeepState: setState,
            index: index
          );
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }

    /// BAGGAGE FORMS
    return Column(children: [
      const TitleBasic(title: 'Baggage Detail', size: 'small'),
      ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: _baggageGroup.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppInputBox(
              content: ListTile(
                minVerticalPadding: 0,
                contentPadding: const EdgeInsets.all(0),
                leading: const Icon(Icons.home_repair_service),
                title: Row(children: [
                  Expanded(child: Text(
                    '${passengerList[index].title} ${passengerList[index].name}',
                    style: TravelloTheme.headline.copyWith(color: colorScheme(context).onSurface)
                  )),
                  Text('${_baggageGroup[index]} Kg', style: TravelloTheme.subtitle2.copyWith(color: colorScheme(context).onSurface))
                ]),
                trailing: const Icon(Icons.edit, color: TravelloTheme.primaryMain),
                onTap: () {
                  showBaggageSheet(index);
                },
              )
            ),
          );
        }
      )
    ]);
  }
}