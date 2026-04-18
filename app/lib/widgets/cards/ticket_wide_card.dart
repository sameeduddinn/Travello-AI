import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TicketWideCard extends StatelessWidget {
  const TicketWideCard(
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

    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border.all(width: 1, color: cardColor),
          borderRadius: ThemeRadius.medium),
      child: Column(
        children: [
          GestureDetector(
            onTap: showDetail,
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// TIME LEFT AND PRICE
                    Expanded(
                        flex: 1,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ticketStatus(context, status),
                              const VSpaceShort(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Total Price',
                                      textAlign: TextAlign.end,
                                      style: TravelloTheme.caption.copyWith(
                                          color: colorScheme(context)
                                              .onSurfaceVariant)),
                                  const SizedBox(width: 8),
                                  Text('\$$price',
                                      textAlign: TextAlign.end,
                                      style: TravelloTheme.subtitle),
                                ],
                              ),
                            ])),

                    /// TRIP DETAIL
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(from.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TravelloTheme.caption.copyWith(
                                              color: colorScheme(context)
                                                  .onSurfaceVariant)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 1),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.network(
                                              plane.logo,
                                              width: 32,
                                            ),
                                            const SizedBox(
                                              width: 4,
                                            ),
                                            Text(plane.name,
                                                style: TravelloTheme.paragraph),
                                          ]),
                                      Expanded(
                                        child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                              border: Border.all(
                                                                  color:
                                                                      cardColor,
                                                                  width: 1),
                                                              shape: BoxShape
                                                                  .circle),
                                                        ),
                                                        const Expanded(
                                                            child:
                                                                DashedBorder()),
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                              border: Border.all(
                                                                  color:
                                                                      cardColor,
                                                                  width: 1),
                                                              shape: BoxShape
                                                                  .circle),
                                                        ),
                                                      ]),
                                                  Icon(CupertinoIcons.airplane,
                                                      size: 24,
                                                      color:
                                                          colorScheme(context)
                                                              .outlineVariant),
                                                ])),
                                      ),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: ThemeRadius.xsmall,
                                              child: Image.network(
                                                plane.logo,
                                                width: 32,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 4,
                                            ),
                                            Text(plane.name,
                                                style: TravelloTheme.paragraph),
                                          ]),
                                    ]),
                              ),
                              SizedBox(
                                width: 60,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(to.name,
                                          style: TravelloTheme.caption.copyWith(
                                              color: colorScheme(context)
                                                  .onSurfaceVariant)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 1),
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
                    ),

                    /// BOOKING INFO
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(plane.code,
                                  overflow: TextOverflow.ellipsis,
                                  style: TravelloTheme.paragraph
                                      .copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: const BoxDecoration(
                                    borderRadius: ThemeRadius.xsmall,
                                    color: TravelloTheme.paperLightDim),
                                child: Text(plane.classType,
                                    style: TravelloTheme.paragraph),
                              ),
                              const VSpaceShort(),
                              Text('Date Order: ',
                                  style: TravelloTheme.caption.copyWith(
                                      color: colorScheme(context)
                                          .onSurfaceVariant)),
                              const Text('12 May 2004',
                                  style: TravelloTheme.paragraphBold),
                            ]),
                      ),
                    ),
                  ]),
            ),
          ),
          Container(
              decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                  color: cardColor),
              child: status == BookStatus.active
                  ? GestureDetector(
                      onTap: showBoardingPass,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code,
                                  color:
                                      colorScheme(context).onPrimaryContainer,
                                  size: 16),
                              const SizedBox(width: 8),
                              Text('SHOW BOARDING PASS',
                                  style: TravelloTheme.paragraph.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme(context)
                                          .onPrimaryContainer)),
                            ]),
                      ),
                    )
                  : Container()),
        ],
      ),
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
          return Colors.grey;
        default:
          return Colors.black;
      }
    }

    switch (status) {
      case BookStatus.active:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Check in available in',
                textAlign: TextAlign.center,
                style: TravelloTheme.caption
                    .copyWith(color: colorScheme(context).onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: ThemeRadius.small,
                color: colorStatus(status).withValues(alpha: 0.3),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(timeLeft,
                    textAlign: TextAlign.center, style: TravelloTheme.subtitle),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: ThemeRadius.small,
                    color: colorStatus(status),
                  ),
                  child: Text(
                    status.name.toUpperCase(),
                    style: TravelloTheme.caption.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
          ],
        );
      case BookStatus.waiting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Expired in',
                textAlign: TextAlign.center,
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
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: ThemeRadius.small,
                    color: colorStatus(status).withValues(alpha: 0.25),
                  ),
                  child: Text(
                    status.name.toUpperCase(),
                    style: TravelloTheme.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorStatus(status)),
                  ),
                ),
              ]),
            ),
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
            style: TravelloTheme.caption.copyWith(
                fontWeight: FontWeight.bold, color: colorStatus(status)),
          ),
        );
    }
  }
}
