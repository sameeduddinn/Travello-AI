import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightSummary extends StatelessWidget {
  const FlightSummary(
      {super.key,
      required this.from,
      required this.to,
      this.label,
      this.discount = 0,
      required this.price,
      this.roundTrip = false,
      this.bordered = false,
      this.depart,
      this.arrival,
      this.plane});

  final City from;
  final City to;
  final String? label;
  final double discount;
  final double price;
  final bool roundTrip;
  final bool bordered;
  final DateTime? depart;
  final DateTime? arrival;
  final Plane? plane;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          borderRadius: ThemeRadius.medium,
          boxShadow: !bordered ? [ThemeShade.shadeSoft(context)] : null,
          border: bordered
              ? Border.all(
                  width: 1, color: TravelloTheme.primaryMainContainer)
              : null),
      child: Column(
        children: [
          /// AIRPLANE INFO
          plane != null
              ? Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    top: 8,
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: ThemeRadius.xsmall,
                      child: Image.network(
                        plane!.logo,
                        width: 20,
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      plane!.name,
                      style: TravelloTheme.paragraph,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          borderRadius: ThemeRadius.xsmall,
                          color: colorScheme(context).outline),
                      child: Text(plane!.classType, style: TravelloTheme.caption),
                    )
                  ]),
                )
              : Container(),

          Stack(
            alignment: Alignment.center,
            children: [
              /// DECORATION
              SizedBox(
                  width: 150,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: TravelloTheme.primaryMain,
                                  width: 1),
                              shape: BoxShape.circle),
                        ),
                        const Expanded(
                          child: DashedBorder(),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: TravelloTheme.primaryMain,
                                  width: 1),
                              shape: BoxShape.circle),
                        ),
                      ])),

              /// DESTINATION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(from.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TravelloTheme.caption.copyWith(
                                      color: colorScheme(context)
                                          .onSurfaceVariant)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                                  from.code,
                                  style: TravelloTheme.title2
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              depart != null
                                  ? Text(DateFormat.MMMEd().format(depart!),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant))
                                  : Container(),
                            ]),
                      ),
                      Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 2),
                                child: Icon(
                                    roundTrip
                                        ? CupertinoIcons.arrow_right_arrow_left
                                        : CupertinoIcons.airplane,
                                    size: 24,
                                    color: colorScheme(context).outlineVariant),
                              ),
                            ]),
                      ),
                      SizedBox(
                        width: 90,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(to.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TravelloTheme.caption.copyWith(
                                      color: colorScheme(context)
                                          .onSurfaceVariant)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                                  to.code,
                                  style: TravelloTheme.title2
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              arrival != null
                                  ? Text(DateFormat.MMMEd().format(arrival!),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant))
                                  : Container(),
                            ]),
                      )
                    ]),
              ),
            ],
          ),

          /// PRICE AND LABEL
          Divider(color: TravelloTheme.primaryMainContainer),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    borderRadius: ThemeRadius.xsmall,
                    color: TravelloTheme.secondaryMainContainer),
                child: label != null
                    ? Text(label!,
                        style: TravelloTheme.paragraph.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme(context).onSurface))
                    : Container(),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    borderRadius: ThemeRadius.xsmall,
                    color: colorScheme(context).tertiaryContainer),
                child: Icon(CupertinoIcons.arrow_uturn_left,
                    color: colorScheme(context).tertiary, size: 16),
              ),
              const Spacer(),
              discount > 0
                  ? Text('PKR ${price.toStringAsFixed(0)}',
                      textAlign: TextAlign.end,
                      style: TravelloTheme.headline.copyWith(
                          color: colorScheme(context).onSurfaceVariant,
                          height: 1,
                          decoration: TextDecoration.lineThrough))
                  : Container(),
              const SizedBox(
                width: 8,
              ),
              Text('PKR ${(price - price * discount / 100).toStringAsFixed(0)}',
                  textAlign: TextAlign.end,
                  style: TravelloTheme.title.copyWith(
                      color: TravelloTheme.primaryMain,
                      height: 1,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }
}
