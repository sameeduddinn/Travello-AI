import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/decorations/cut_deco.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightPortraitCard extends StatefulWidget {
  const FlightPortraitCard(
      {super.key,
      required this.from,
      required this.to,
      this.label,
      this.roundTrip = false,
      required this.date,
      required this.price,
      this.plane});

  final String from;
  final String to;
  final String? label;
  final bool roundTrip;
  final String date;
  final double price;
  final Plane? plane;

  @override
  State<FlightPortraitCard> createState() => _FlightPortraitCardState();
}

class _FlightPortraitCardState extends State<FlightPortraitCard> {
  String _travelMode = 'airline';

  @override
  void initState() {
    super.initState();
    _loadTravelMode();
  }

  Future<void> _loadTravelMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _travelMode = prefs.getString('travel_mode') ?? 'airline';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// TOP PROPERTIES
        Container(
          decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: TravelloTheme.primaryMainContainer, width: 1),
                left: BorderSide(
                    color: TravelloTheme.primaryMainContainer, width: 1),
                right: BorderSide(
                    color: TravelloTheme.primaryMainContainer, width: 1),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              )),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            /// DESTINATION
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              top: 8),
                          child: RichText(
                              text: TextSpan(children: [
                            TextSpan(
                                text: widget.from,
                                style: TravelloTheme.paragraph.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme(context).onSurface)),
                            TextSpan(
                                text: ' to',
                                style: TravelloTheme.paragraph.copyWith(
                                    color: colorScheme(context).onSurface)),
                          ])),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(widget.to,
                              textAlign: TextAlign.start,
                              style: TravelloTheme.subtitle
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ),
                      ]),
                  widget.label != null
                      ? Container(
                          width: 45,
                          height: 45,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: TravelloTheme.secondaryMain,
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(60),
                                  topRight: Radius.circular(14))),
                          child: Text(widget.label!,
                              textAlign: TextAlign.end,
                              style: TravelloTheme.caption.copyWith(
                                  color: TravelloTheme.primaryMain,
                                  fontWeight: FontWeight.bold)))
                      : Container()
                ]),

            /// DATE AND PRICE
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          widget.roundTrip
                              ? Text(
                                  'Round-trip',
                                  style: TravelloTheme.caption.copyWith(
                                      color: colorScheme(context)
                                          .onSurfaceVariant),
                                )
                              : Text(
                                  'One-way',
                                  style: TravelloTheme.caption.copyWith(
                                      color: colorScheme(context)
                                          .onSurfaceVariant),
                                ),
                          Text(
                            widget.date,
                            style: TravelloTheme.caption.copyWith(
                                color: colorScheme(context).onSurfaceVariant),
                          )
                        ]),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Start from',
                            style: TravelloTheme.caption.copyWith(
                                color: colorScheme(context).onSurfaceVariant)),
                        Text('₨${widget.price.toStringAsFixed(0)}',
                            style: TravelloTheme.subtitle.copyWith(
                                color: TravelloTheme.primaryMain,
                                fontWeight: FontWeight.bold,
                                height: 1.1))
                      ],
                    )
                  ]),
            )
          ]),
        ),

        /// CUT DECO
        const CutDeco(),

        /// BOTTOM PROPERTIES
        widget.plane != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: TravelloTheme.primaryMainContainer,
                          width: 1),
                      left: BorderSide(
                          color: TravelloTheme.primaryMainContainer,
                          width: 1),
                      right: BorderSide(
                          color: TravelloTheme.primaryMainContainer,
                          width: 1),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    )),
                child: Row(children: [
                  _travelMode == 'railway'
                      ? Icon(
                          Icons.train,
                          size: 16,
                          color: Colors.green.shade700,
                        )
                      : ClipRRect(
                          borderRadius: ThemeRadius.xsmall,
                          child: Image.network(
                            widget.plane!.logo,
                            width: 14,
                            height: 14,
                          ),
                        ),
                  const SizedBox(width: 4),
                  Text(
                    _travelMode == 'railway'
                        ? 'Pakistan Railways • Economy'
                        : '${widget.plane!.name} • Economy',
                    style: TravelloTheme.caption,
                  ),
                ]),
              )
            : Container(),
      ],
    );
  }
}
