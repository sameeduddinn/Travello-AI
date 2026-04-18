import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/models/user.dart';
import 'package:flight_app/widgets/decorations/cut_deco.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ETicketCard extends StatelessWidget {
  const ETicketCard({
    super.key,
    required this.date,
  });

  final String date;

  final double _radius = 30;
  final double _maxWidth = 400;
  final double _height = 640;

  @override
  Widget build(BuildContext context) {
    final Plane plane = planeList[0];
    final City from = cityList[0];
    final City to = cityList[1];

    DateTime arrival = DateTime.parse('2025-07-20 20:18:00');
    DateTime depart = DateTime.parse('2025-07-21 20:18:00');
    final Duration tripDuration = arrival.difference(depart);

    final User passengger = passengerList[2];

    final TextStyle textBold = TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: Colors.black);
    final TextStyle caption = TravelloTheme.caption.copyWith(color: Colors.black);
    final TextStyle paragraph = TravelloTheme.caption.copyWith(color: Colors.black);
    final TextStyle captionGrey = TravelloTheme.caption.copyWith(color: Colors.grey.shade700);
    final Color grey = Colors.grey.shade700;

    return SizedBox(
      height: _height,
      child: Stack(alignment: Alignment.center, children: [
        Column(children: [
          /// BARCODE AND PROMO CODE
          Container(
            height: _height * 0.5,
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: _maxWidth
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_radius),
                topRight: Radius.circular(_radius),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Image.network(
                    plane.logo,
                    width: 40,
                  ),
                  const SizedBox(width: 4),
                  Text(plane.name, style: paragraph,),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      borderRadius: ThemeRadius.small,
                      color: TravelloTheme.paperLightDim
                    ),
                    child: Text(plane.classType, style: TravelloTheme.paragraph),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Booking Code:', style: TravelloTheme.subtitle.copyWith(color: Colors.black)),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[50],
                  borderRadius: ThemeRadius.medium,
                ),
                child: Text('A1234J', style: TravelloTheme.title.copyWith(color: Colors.black, fontWeight: FontWeight.bold,))
              ),
              const VSpace(),
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  width: constraints.maxWidth * 0.8,
                  child: Image.asset('assets/images/barcode.gif', fit: BoxFit.contain),
                ),
              ),
            ])
          ),
      
          /// THUMBNAIL AND DESCRIPTIONS
          Container(
            height: _height * 0.5,
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: _maxWidth
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_radius),
                bottomRight: Radius.circular(_radius),
              )
            ),
            child: Column(children: [
              /// TRIP DETAIL
              const VSpaceShort(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Name', style: caption),
                  Text('${passengger.title} ${passengger.name}', style: textBold)
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Passport No.', style: caption),
                  Text(passengger.idCard, style: textBold)
                ]),
              ]),
              const VSpace(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[50],
                  borderRadius: ThemeRadius.medium
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// FLIGHT DECORATION
                    SizedBox(
                      width: 150,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            border: Border.all(color: TravelloTheme.primaryMainContainer, width: 1),
                            shape: BoxShape.circle
                          ),
                        ),
                        const Expanded(child: DashedBorder()),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            border: Border.all(color: TravelloTheme.primaryMainContainer, width: 1),
                            shape: BoxShape.circle
                          ),
                        ),
                      ])
                    ),
                    
                    /// FLIGHT DETAILS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        SizedBox(
                          width: 80,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Text(from.name, overflow: TextOverflow.ellipsis, style: TravelloTheme.headline.copyWith(color: grey)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(from.code, style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold, color: Colors.black),),
                            ),
                            Text(DateFormat.yMMMMd().format(depart), style: captionGrey),
                            Text(DateFormat.jm().format(depart), style: captionGrey),
                          ]),
                        ),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Text(plane.code, overflow: TextOverflow.ellipsis, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: grey),),
                            Padding(
                              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
                              child: Icon(CupertinoIcons.airplane, size: 24, color: grey),
                            ),
                            Text('${tripDuration.inHours * -1}h ${tripDuration.inMinutes.remainder(60) * -1}m', style: caption)
                          ]),
                        ),
                        SizedBox(
                          width: 80,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Text(to.name, style: TravelloTheme.headline.copyWith(color: grey)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(to.code, style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold, color: Colors.black),),
                            ),
                            Text(DateFormat.yMMMMd().format(arrival), style: captionGrey),
                            Text(DateFormat.jm().format(arrival), style: captionGrey),
                          ]),
                        )
                      ]),
                    ),
                  ],
                ),
              ),
              const VSpaceShort(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('Terminal', style: caption),
                  Text('3', style: textBold)
                ]),
                Column(children: [
                  Text('GATE', style: caption),
                  Text('H22', style: textBold.copyWith(color: Colors.red))
                ]),
                Column(children: [
                  Text('SEAT', style: caption),
                  Text('${passengerList[0].seat}', style: textBold)
                ]),
              ]),
              const VSpaceShort(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [
                  Text('DATE FLIGHT', style: caption),
                  Text(DateFormat.MMMEd().format(depart), style: textBold)
                ]),
                Column(children: [
                  Text('BOARDING TIME', style: caption),
                  Text(DateFormat.jm().format(depart), style: textBold.copyWith(color: Colors.red))
                ]),
              ]),
            ]),
          )
        ]),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _maxWidth),
            child: const CutDeco(color: TravelloTheme.primaryDark, radius: 20)
          )
        ),
      ]),
    );
  }
}
