import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/decorations/cut_deco.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TicketCard extends StatelessWidget {
  const TicketCard(
      {super.key,
      required this.from,
      required this.to,
      required this.plane,
      required this.price,
      required this.depart,
      required this.arrival,
      required this.transit,
      required this.status,
      required this.timeLeft,
      required this.bookingCode,
      this.showBoardingPass,
      this.showDetail});

  final City from;
  final City to;
  final Plane plane;
  final double price;
  final DateTime depart;
  final DateTime arrival;
  final int transit;
  final BookStatus status;
  final String timeLeft;
  final String bookingCode;
  final Function()? showBoardingPass;
  final Function()? showDetail;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;
    final Color cardColor = isDark
        ? colorScheme(context).outline
        : TravelloTheme.primaryMainContainer;

    return Column(
      children: [
        /// TOP PROPERTIES
        GestureDetector(
          onTap: showDetail,
          child: Container(
            decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cardColor, width: 1),
                  left: BorderSide(color: cardColor, width: 1),
                  right: BorderSide(color: cardColor, width: 1),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                )),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /// TOP INFO
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(children: [
                  Text('Date Order: ',
                      style: TravelloTheme.caption.copyWith(
                          color: colorScheme(context).onSurfaceVariant)),
                  Text('12 May 2004',
                      style: TravelloTheme.caption
                          .copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  status != BookStatus.waiting
                      ? Text('Booking Code: ',
                          style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant))
                      : Container(),
                  status != BookStatus.waiting
                      ? Text(bookingCode,
                          style: TravelloTheme.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: TravelloTheme.primaryMain))
                      : Container(),
                ]),
              ),
              const SizedBox(height: 8),

              /// TRIP DETAIL
              Stack(
                alignment: Alignment.center,
                children: [
                  /// FLIGHT DECORATION
                  SizedBox(
                      width: 150,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: cardColor, width: 1),
                                  shape: BoxShape.circle),
                            ),
                            const Expanded(child: DashedBorder()),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: cardColor, width: 1),
                                  shape: BoxShape.circle),
                            ),
                          ])),

                  /// FLIGHT DETAILS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 64,
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
                                      style: TravelloTheme.paragraph.copyWith(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(DateFormat.MMMEd().format(depart),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                  Text(DateFormat.jm().format(depart),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                ]),
                          ),
                          Expanded(
                            child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(plane.code,
                                      overflow: TextOverflow.ellipsis,
                                      style: TravelloTheme.caption.copyWith(
                                          fontWeight: FontWeight.bold)),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Icon(CupertinoIcons.airplane,
                                        size: 24,
                                        color: colorScheme(context)
                                            .outlineVariant),
                                  ),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: ThemeRadius.xsmall,
                                          child: Image.network(
                                            plane.logo,
                                            width: 20,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 4,
                                        ),
                                        Text(plane.name,
                                            style: TravelloTheme.caption),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          decoration: BoxDecoration(
                                              borderRadius: ThemeRadius.xsmall,
                                              color: colorScheme(context)
                                                  .surfaceDim),
                                          child: Text(plane.classType,
                                              style: TravelloTheme.caption),
                                        ),
                                      ]),
                                ]),
                          ),
                          SizedBox(
                            width: 64,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(to.name,
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(
                                      to.code,
                                      style: TravelloTheme.paragraph.copyWith(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(DateFormat.MMMEd().format(arrival),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                  Text(DateFormat.jm().format(arrival),
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                ]),
                          )
                        ]),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              )
            ]),
          ),
        ),

        /// CUT DECO
        const CutDeco(),

        /// BOTTOM INFO
        Container(
          decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              color: cardColor),
          child: Column(
            children: [
              /// PRICE AND STATUS
              GestureDetector(
                onTap: showDetail,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: TravelloTheme.paperLightContainerLowest,
                      border: Border(
                        bottom: BorderSide(color: cardColor, width: 1),
                        left: BorderSide(color: cardColor, width: 1),
                        right: BorderSide(color: cardColor, width: 1),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      )),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        /// TIME LEFT AND STATUS
                        _ticketStatus(context, status),

                        /// PRICE
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Price',
                                textAlign: TextAlign.end,
                                style: TravelloTheme.caption.copyWith(
                                    color:
                                        colorScheme(context).onSurfaceVariant)),
                            const SizedBox(width: 8),
                            Text('\$$price',
                                textAlign: TextAlign.end,
                                style: TravelloTheme.subtitle),
                          ],
                        ),
                      ]),
                ),
              ),

              /// SHOW BOARDING PASS BUTTON
              status == BookStatus.active
                  ? GestureDetector(
                      onTap: showBoardingPass,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code, color: cardColor, size: 16),
                              const SizedBox(width: 8),
                              Text('SHOW BOARDING PASS',
                                  style: TravelloTheme.paragraph.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme(context)
                                          .onPrimaryContainer)),
                            ]),
                      ),
                    )
                  : Container()
            ],
          ),
        ),
      ],
    );
  }

  Widget _ticketStatus(BuildContext context, BookStatus status) {
    Color colorStatus(BookStatus st) {
      switch (st) {
        case BookStatus.active:
          return Colors.green;
        case BookStatus.waiting:
          return Colors.orange;
        case BookStatus.canceled:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    switch (status) {
      case BookStatus.active:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check in available in',
                textAlign: TextAlign.start,
                style: TravelloTheme.caption
                    .copyWith(color: colorScheme(context).onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: ThemeRadius.small,
                color: colorStatus(status).withValues(alpha: 0.25),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(timeLeft,
                    textAlign: TextAlign.center, style: TravelloTheme.subtitle),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: ThemeRadius.small,
                    color: colorStatus(status),
                  ),
                  child: Text(status.name.toUpperCase(),
                      style: TravelloTheme.caption.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
            )
          ],
        );
      case BookStatus.waiting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expired in',
                textAlign: TextAlign.start,
                style: TravelloTheme.caption
                    .copyWith(color: colorScheme(context).onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: ThemeRadius.small,
                color: colorStatus(status).withValues(alpha: 0.25),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(timeLeft,
                    textAlign: TextAlign.center, style: TravelloTheme.subtitle),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: ThemeRadius.small,
                    color: colorStatus(status),
                  ),
                  child: Text(status.name.toUpperCase(),
                      style: TravelloTheme.caption.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
            )
          ],
        );
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: ThemeRadius.small,
            color: colorStatus(status).withValues(alpha: 0.25),
          ),
          child: Text(
            status.name.toUpperCase(),
            style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold),
          ),
        );
    }
  }
}
