import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/widgets/booking/choose_passengger.dart';
import 'package:flight_app/widgets/cards/ticket_card.dart';
import 'package:flight_app/widgets/cards/ticket_wide_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TicketList extends StatelessWidget {
  const TicketList({super.key, required this.bookingList});

  final List<Booking> bookingList;

  @override
  Widget build(BuildContext context) {
    bool wideScreen = ThemeBreakpoints.smUp(context);

    void showPassengerList() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: const Wrap(
              alignment: WrapAlignment.center,
              children: [VSpace(), GrabberIcon(), ChoosePassengger()],
            ),
          );
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }

    return bookingList.isNotEmpty
        ? ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const ClampingScrollPhysics(),
            itemCount: bookingList.length,
            itemBuilder: ((BuildContext context, int index) {
              Booking item = bookingList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: wideScreen
                    ? TicketWideCard(
                        from: item.from,
                        to: item.to,
                        plane: item.plane,
                        price: item.price,
                        depart: item.depart,
                        arrival: item.arrival,
                        transit: 1,
                        status: item.status,
                        timeLeft: '2d 11h',
                        bookingCode: 'ABCDE${item.id}',
                        showDetail: () {
                          Get.toNamed(AppLink.ticketDetail);
                        },
                        showBoardingPass: () {
                          showPassengerList();
                        },
                      )
                    : TicketCard(
                        from: item.from,
                        to: item.to,
                        plane: item.plane,
                        price: item.price,
                        depart: item.depart,
                        arrival: item.arrival,
                        transit: 1,
                        status: item.status,
                        timeLeft: '2d 11h',
                        bookingCode: 'ABCDE${item.id}',
                        showDetail: () {
                          Get.toNamed(AppLink.ticketDetail);
                        },
                        showBoardingPass: () {
                          showPassengerList();
                        },
                      ),
              );
            }),
          )
        : _emptyList(context);
  }

  Widget _emptyList(BuildContext context) {
    return NoData(
      image: ImgApi.emptyBooking,
      title: 'You don\'t any booking yet',
      desc:
          'No bookings found. Book a flight or hotel and your tickets will appear here.',
      primaryAction: () {
        Get.toNamed(AppLink.searchFlight);
      },
      primaryTxtBtn: 'SEARCH FLIGHT',
    );
  }
}
