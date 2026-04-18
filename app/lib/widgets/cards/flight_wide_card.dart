import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightWideCard extends StatelessWidget {
  const FlightWideCard({
    super.key, required this.from, required this.to,
    required this.plane, required this.price, this.label, this.hasRefund = true, 
    required this.depart, required this.arrival, required this.transit, this.discount = 0,
    this.withEdit = false, this.onEdit
  });

  final City from;
  final City to;
  final Plane plane;
  final double price;
  final String? label;
  final bool hasRefund;
  final DateTime depart;
  final DateTime arrival;
  final int transit; 
  final double discount;
  final bool withEdit;
  final Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final Duration tripDuration = arrival.difference(depart);
    final bool isDark = Get.isDarkMode;
    final Color cardColor = isDark ? TravelloTheme.paperLightContainerLowest : TravelloTheme.primaryMainContainer;

    return Container(
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.medium,
        border: Border.all(color: cardColor, width: 1),
        color: TravelloTheme.primaryMainContainer
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            height: 150,
            decoration: const BoxDecoration(
              color: TravelloTheme.paperLight,
              borderRadius: ThemeRadius.medium,
            ),
            child: Row(children: [
              /// AIRPLANE INFO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.network(
                    plane.logo,
                    width: 20,
                  ),
                  const SizedBox(width: 4,),
                  Text(plane.name, style: TravelloTheme.subtitle2,),
                  const VSpace(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: ThemeRadius.small,
                      color: colorScheme(context).outline
                    ),
                    child: Text(plane.classType, style: TravelloTheme.paragraph),
                  )
                ]),
              ),
          
              /// FLIGHT INFO
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    SizedBox(
                      width: 100,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text(from.name, overflow: TextOverflow.ellipsis, style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(from.code, style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold),),
                        ),
                        Text(DateFormat.jm().format(depart), style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                      ]),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          /// FLIGHT DECORATION
                          SizedBox(
                            width: double.infinity,
                            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  border: Border.all(color: TravelloTheme.primaryMain, width: 1),
                                  shape: BoxShape.circle
                                ),
                              ),
                              const Expanded(child: DashedBorder()),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  border: Border.all(color: TravelloTheme.primaryMain, width: 1),
                                  shape: BoxShape.circle
                                ),
                              ),
                            ])
                          ),
                          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Text(plane.code, overflow: TextOverflow.ellipsis, style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold),),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                              child: Icon(CupertinoIcons.airplane, size: 24, color: colorScheme(context).outlineVariant),
                            ),
                            Text('${transit > 0 ? '${transit.toString()}x Transit' : 'Direct'} ${tripDuration.inHours}h ${tripDuration.inMinutes.remainder(60)}m', style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold),)
                          ]),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text(to.name, style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(to.code, style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold),),
                        ),
                        Text(DateFormat.jm().format(arrival), style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                      ]),
                    )
                  ]),
                ),
              ),
          
              /// PRICE AND LABEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        borderRadius: ThemeRadius.xsmall,
                        color: TravelloTheme.secondaryMainContainer
                      ),
                      child: label != null ? Text(
                        label!,
                        style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurface)
                      ) : Container(),
                    ),
                    const SizedBox(width: 8),
                    hasRefund ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: ThemeRadius.xsmall,
                        color: colorScheme(context).tertiaryContainer
                      ),
                      child: Icon(CupertinoIcons.arrow_uturn_left, color: colorScheme(context).tertiary, size: 16),
                    ) : Container(),
                  ]),
                  const VSpace(),
                  discount > 0 ? Text('\$$price', textAlign: TextAlign.end, style: TravelloTheme.subtitle.copyWith(color: colorScheme(context).onSurfaceVariant, decoration: TextDecoration.lineThrough, height: 1.5)) : Container(),
                  const SizedBox(width: 8,),
                  Text('\$${price - price * discount / 100}', textAlign: TextAlign.end, style: TravelloTheme.title2.copyWith(color: TravelloTheme.primaryMain, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          withEdit ? InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.edit, color: colorScheme(context).onPrimaryContainer, size: 14),
                const SizedBox(width: 8),
                Text('EDIT', style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: colorScheme(context).onPrimaryContainer))
              ]),
            ),
          ) : Container()
        ],
      ),
    );
  }
}