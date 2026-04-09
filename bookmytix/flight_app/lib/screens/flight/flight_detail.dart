import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/alert_info/alert_info.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:flight_app/widgets/decorations/oval_shape.dart';
import 'package:flight_app/widgets/flight/facilities_slider.dart';
import 'package:flight_app/widgets/flight/flight_routes.dart';
import 'package:flight_app/widgets/flight/flight_routes_horizontal.dart';
import 'package:flight_app/widgets/flight/flight_summary.dart';
import 'package:flight_app/widgets/flight/flight_summary_wide.dart';
import 'package:flight_app/widgets/flight/package_options.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightDetail extends StatefulWidget {
  const FlightDetail({super.key});

  @override
  State<FlightDetail> createState() => _FlightDetailState();
}

class _FlightDetailState extends State<FlightDetail> {
  static const double price = 400;
  static const double discount = 10;
  double _finalPrice = price - price * discount / 100;

  void updatePrice(String type, double val) {
    setState(() {
      if (type == 'add') {
        _finalPrice += val;
      } else {
        _finalPrice -= val;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool wideScreen = ThemeBreakpoints.smUp(context);

    // Get trip data from navigation arguments, use defaults if not provided
    final Map<String, dynamic> args = Get.arguments ?? {};
    final Trip? trip = args['trip'];

    // Use trip data if available, otherwise use defaults
    final City fromCity = trip?.from ?? cityList[0];
    final City toCity = trip?.to ?? cityList[6];
    final Plane flightPlane = trip?.plane ?? planeList[0];
    final double flightPrice = trip?.price ?? price;
    final double flightDiscount = trip?.discount ?? discount;
    final String discountLabel = trip?.label.isNotEmpty == true
        ? trip!.label
        : 'Discount ${flightDiscount.toStringAsFixed(0)}%';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: TravelloTheme.primaryMainContainer,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
        title: const Text('Flight Detail', style: TravelloTheme.subtitle),
        actions: [
          IconButton(
              onPressed: () {
                Get.toNamed(AppLink.faq);
              },
              icon: Icon(Icons.help_outline_rounded,
                  color: colorScheme(context).onSurface))
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Stack(alignment: Alignment.topCenter, children: [
          /// DECORATION BG
          Container(
            alignment: Alignment.bottomCenter,
            width: double.infinity,
            height: 100,
            color: TravelloTheme.primaryMainContainer,
          ),

          /// DECORATION ROUNDED
          Positioned(
            top: 80,
            left: -10,
            child: CustomPaint(
              painter: OvalShape(
                  color: TravelloTheme.paperLightContainerLowest,
                  width: MediaQuery.of(context).size.width + 20),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            wideScreen
                ? FlightSummaryWide(
                    from: fromCity,
                    to: toCity,
                    price: flightPrice,
                    discount: flightDiscount,
                    label: discountLabel,
                    plane: flightPlane,
                  )
                : FlightSummary(
                    from: fromCity,
                    to: toCity,
                    price: flightPrice,
                    discount: flightDiscount,
                    label: discountLabel,
                    plane: flightPlane,
                  ),
            wideScreen
                ? FlightRoutesHorizontal(
                    title: 'Departure', routes: departRoute)
                : FlightRoutes(
                    title: 'Departure',
                    routes: departRoute,
                  ),
            const VSpace(),
            const FacilitiesSlider(),
            const VSpace(),
            PackageOptions(
              getVal: (type, val) {
                updatePrice(type, val);
              },
            ),
            const VSpace(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AlertInfo(
                  type: AlertType.warning,
                  text:
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis congue euismod elit'),
            ),
            const VSpace(),
          ])
        ]),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: 80,
        color: TravelloTheme.paperLight,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              wideScreen
                  ? SizedBox(width: MediaQuery.of(context).size.width * 0.5)
                  : Container(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('\$$price',
                      textAlign: TextAlign.end,
                      style: TravelloTheme.headline.copyWith(
                          color: colorScheme(context).onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                          height: 1)),
                  Text('\$$_finalPrice',
                      textAlign: TextAlign.end,
                      style: TravelloTheme.title.copyWith(
                          color: TravelloTheme.primaryMain,
                          height: 1,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                      onPressed: () async {
                        // Auth gate at booking intent — search was free
                        final isGuest = await AuthService.isGuestMode();
                        if (isGuest && context.mounted) {
                          AuthGateSheet.show(context,
                              action: 'to book this flight');
                          return;
                        }
                        Get.toNamed(AppLink.bookingStep1);
                      },
                      style: ThemeButton.btnBig.merge(ThemeButton.primary),
                      child:
                          const Text('BOOK NOW', style: TravelloTheme.subtitle2)),
                ),
              )
            ]),
      ),
    );
  }
}
