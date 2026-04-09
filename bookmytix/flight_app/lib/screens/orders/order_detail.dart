import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flight_app/widgets/alert_info/alert_info.dart';
import 'package:flight_app/widgets/booking/choose_passengger.dart';
import 'package:flight_app/widgets/booking/review_order.dart';
import 'package:flight_app/widgets/booking/ticket_settings.dart';
import 'package:flight_app/widgets/flight/flight_routes.dart';
import 'package:flight_app/widgets/flight/flight_routes_horizontal.dart';
import 'package:flight_app/widgets/flight/flight_summary.dart';
import 'package:flight_app/widgets/flight/flight_summary_wide.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class OrderDetail extends StatefulWidget {
  const OrderDetail({super.key});

  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {
  
  @override
  Widget build(BuildContext context) {
    const double price = 400;
    const double discount = 10;
    final Booking booking = bookingList[0];
    final wideScreen = ThemeBreakpoints.smUp(context);

    Color colorStatus(BookStatus st) {
      switch(st) {
        case BookStatus.active:
          return Colors.green;
        case BookStatus.waiting:
          return Colors.orange;
        case BookStatus.canceled:
          return Colors.grey;
        default:
          return TravelloTheme.primaryMain;
      }
    }

    void showTicketSettings() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              children: [
                SizedBox(height: 30,),
                GrabberIcon(),
                TicketSettingsBottomSheet(),
              ],
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

    void showPassengerList() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                VSpace(),
                GrabberIcon(),
                ChoosePassengger()
              ],
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

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios_new)
        ),
        centerTitle: true,
        title: const Text('Ticket Detail', style: TravelloTheme.subtitle),
        actions: const [
          TicketSettingsPopup()
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ThemeSize.md
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const VSpaceShort(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check in available in', textAlign: TextAlign.start, style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: ThemeRadius.small,
                          color: colorStatus(BookStatus.active).withValues(alpha: 0.3),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 4),
                          Text('2d 11h', textAlign: TextAlign.center, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: ThemeRadius.small,
                              color: colorStatus(BookStatus.active),
                            ),
                            child: Text(BookStatus.active.name.toUpperCase(), style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ]),
                      )
                    ],
                  ),
            
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction date', textAlign: TextAlign.end, style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant)),
                      Text('12 Jan 2025', textAlign: TextAlign.center, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  )
                ]),
              ),
              const VSpace(),
              
              /// BARCODE
              RichText(text: TextSpan(text: 'Booking Code: ', style: TravelloTheme.title2.copyWith(fontWeight: FontWeight.normal, color: colorScheme(context).onSurface), children: const [
                TextSpan(text: 'A1234Z', style: TextStyle(fontWeight: FontWeight.bold, color: TravelloTheme.primaryMain))
              ])),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.asset('assets/images/barcode.gif', 
                  width: MediaQuery.of(context).size.width * 0.75,
                  fit: BoxFit.contain,
                ),
              ),
              Text('Submit at Registration', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onSurfaceVariant)),
              const VSpaceShort(),
              const Divider(thickness: 10, color: TravelloTheme.paperLightDim),
            
              /// FLIGHT SUMMARY
              wideScreen ? FlightSummaryWide(
                from: cityList[0],
                to: cityList[6],
                price: price,
                discount: discount,
                label: 'Discount $discount%',
                bordered: true,
                depart: DateTime.parse('2025-07-20 20:18:00'),
                arrival: DateTime.parse('2025-07-21 20:18:00'),
                plane: planeList[0],
              ) : FlightSummary(
                from: cityList[0],
                to: cityList[6],
                price: price,
                discount: discount,
                label: 'Discount $discount%',
                bordered: true,
                depart: DateTime.parse('2025-07-20 20:18:00'),
                arrival: DateTime.parse('2025-07-21 20:18:00'),
                plane: planeList[0],
              ),
              const VSpaceShort(),
            
              /// FLIGHT TIMELINE
              wideScreen ?
                FlightRoutesHorizontal(title: 'Depart on ${DateFormat.yMMMMd().format(booking.depart)}', routes: departRoute)
                : FlightRoutes(title: 'Depart on ${DateFormat.yMMMMd().format(booking.depart)}', routes: departRoute),
            
              /// PASSENGGERS & PRICING DETAIL
              const ReviewOrder(withFlightDetail: false),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const AlertInfo(type: AlertType.warning, text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit'),
              ),
            
              /// OTHER OPTIONS
              const LineSpace(),
              const TicketSettingsList(),
              const VSpaceBig()
            ]),
          ),
        ),
      ),

      /// BOTTOM ACTION
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: 80,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ThemeSize.md
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
              SizedBox(
                height: 50,
                width: 50,
                child: OutlinedButton(
                  onPressed: () {
                    showTicketSettings();
                  },
                  style: ThemeButton.btnBig.merge(ThemeButton.outlinedPrimary(context)),
                  child: const Icon(Icons.more_horiz, size: 18)
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      showPassengerList();
                    },
                    style: ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 16, color: colorScheme(context).onPrimaryContainer),
                        const SizedBox(width: 8),
                        const Text('SHOW BOARDING PASS', style: TravelloTheme.subtitle2),
                      ],
                    )
                  ),
                ),
              )
            ]),
          ),
        ),
      ),
    );
  }
}