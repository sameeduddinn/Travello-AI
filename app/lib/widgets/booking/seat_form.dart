import 'package:flight_app/models/booking.dart';
import 'package:flight_app/widgets/app_input/app_input_box.dart';
import 'package:flight_app/widgets/booking/seat_picker.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SeatForm extends StatefulWidget {
  const SeatForm({super.key, required this.totalPassengers});

  final int totalPassengers;

  @override
  State<SeatForm> createState() => _SeatFormState();
}

class _SeatFormState extends State<SeatForm> {
  List<String> _seatGroup = [];
  String _selectedSeat = '';

  void setSeat(String val, int index) {
    setState(() {
      _selectedSeat = val;
      _seatGroup[index] = val;
    });
  }

  @override
  void initState() {
    super.initState();
    List <String>initGroup = List.generate(widget.totalPassengers, (index) => 'B${index+1}');
    Future.delayed(Durations.short1, () {
      setState(() {
        _seatGroup = initGroup;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    /// SEAT PICKER
    void showSeatSheet(int index) async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return SeatPicker(
            index: index,
            setSeat: setSeat,
            selectedSeat: _selectedSeat,
            setDeepState: setState,
          );
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }

    /// PASSENGGER SEAT LIST
    return Column(children: [
      const TitleBasic(title: 'Select Seat', size: 'small'),
      ListView.builder(
        shrinkWrap: true,
        itemCount: _seatGroup.length,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppInputBox(
              content: ListTile(
                minVerticalPadding: 0,
                contentPadding: const EdgeInsets.all(0),
                leading: const Icon(Icons.airline_seat_recline_extra),
                title: Row(children: [
                  Expanded(child: Text(
                    '${passengerList[index].title} ${passengerList[index].name}',
                    style: TravelloTheme.headline.copyWith(color: colorScheme(context).onSurface)
                  )),
                  Text(_seatGroup[index], style: TravelloTheme.subtitle2.copyWith(color: colorScheme(context).onSurface))
                ]),
                trailing: const Icon(Icons.edit, color: TravelloTheme.primaryMain),
                onTap: () {
                  showSeatSheet(index);
                  setState(() {
                    _selectedSeat = _seatGroup[index];
                  });
                }
              )
            ),
          );
        }
      )
    ]);
  }
}