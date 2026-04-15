import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/flight_package.dart';
import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/widgets/decorations/oval_shape.dart';
import 'package:flight_app/widgets/flight/flight_routes.dart';
import 'package:flight_app/widgets/flight/flight_routes_horizontal.dart';
import 'package:flight_app/widgets/flight/flight_summary.dart';
import 'package:flight_app/widgets/flight/flight_summary_wide.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class FlightDetailPackage extends StatefulWidget {
  const FlightDetailPackage({super.key});

  @override
  State<FlightDetailPackage> createState() => _FlightDetailPackageState();
}

class _FlightDetailPackageState extends State<FlightDetailPackage> {
  late FlightPackage? _pkg;
  late double _basePrice;
  late double _discount;
  late double _finalPrice;
  late DateTime _departDate;
  late DateTime _returnDate;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _pkg = args['package'] as FlightPackage?;
      _departDate = (args['departDate'] as DateTime?) ??
          DateTime.now().add(const Duration(days: 30));
      _returnDate = (args['returnDate'] as DateTime?) ??
          _departDate.add(const Duration(days: 2));
    } else {
      _pkg = args as FlightPackage?;
      _departDate = DateTime.now().add(const Duration(days: 30));
      _returnDate = _departDate.add(const Duration(days: 2));
    }
    _basePrice = _pkg?.price ?? 1000;
    _discount = _pkg?.discount ?? 5;
    _finalPrice = _basePrice - _basePrice * _discount / 100;
  }

  /// Find airport by matching city name to airport location; fall back to a stub.
  Airport _airportForCity(City city) {
    try {
      return airportList.firstWhere(
        (a) => a.location.toLowerCase() == city.name.toLowerCase(),
      );
    } catch (_) {
      return Airport(
        id: '0',
        code: city.code.length >= 3
            ? city.code.substring(0, 3).toUpperCase()
            : city.code.toUpperCase(),
        name: '${city.name} Airport',
        location: city.name,
      );
    }
  }

  /// Real Pakistan domestic airline schedules (PIA / AirSial / SereneAir).
  static const Map<String, List<dynamic>> _scheduleMap = {
    'Karachi-Lahore': [9, 0, 10, 30, '1h 30m'],
    'Lahore-Karachi': [9, 0, 10, 30, '1h 30m'],
    'Karachi-Islamabad': [7, 0, 9, 0, '2h 00m'],
    'Islamabad-Karachi': [8, 0, 10, 0, '2h 00m'],
    'Karachi-Rawalpindi': [7, 0, 9, 0, '2h 00m'],
    'Rawalpindi-Karachi': [8, 0, 10, 0, '2h 00m'],
    'Karachi-Peshawar': [8, 0, 10, 15, '2h 15m'],
    'Peshawar-Karachi': [7, 0, 9, 15, '2h 15m'],
    'Karachi-Multan': [10, 0, 11, 15, '1h 15m'],
    'Multan-Karachi': [9, 0, 10, 15, '1h 15m'],
    'Karachi-Quetta': [11, 0, 12, 30, '1h 30m'],
    'Quetta-Karachi': [7, 30, 9, 0, '1h 30m'],
    'Karachi-Faisalabad': [9, 30, 11, 0, '1h 30m'],
    'Faisalabad-Karachi': [9, 30, 11, 0, '1h 30m'],
    'Karachi-Sialkot': [8, 0, 9, 30, '1h 30m'],
    'Sialkot-Karachi': [8, 0, 9, 30, '1h 30m'],
    'Karachi-Gwadar': [9, 0, 10, 10, '1h 10m'],
    'Gwadar-Karachi': [8, 0, 9, 10, '1h 10m'],
    'Karachi-Gilgit': [7, 0, 9, 30, '2h 30m'],
    'Gilgit-Karachi': [7, 0, 9, 30, '2h 30m'],
    'Karachi-Skardu': [7, 0, 9, 30, '2h 30m'],
    'Skardu-Karachi': [7, 0, 9, 30, '2h 30m'],
    'Lahore-Islamabad': [7, 30, 8, 20, '0h 50m'],
    'Islamabad-Lahore': [9, 0, 9, 50, '0h 50m'],
    'Lahore-Rawalpindi': [7, 30, 8, 20, '0h 50m'],
    'Rawalpindi-Lahore': [9, 0, 9, 50, '0h 50m'],
    'Lahore-Peshawar': [10, 0, 11, 10, '1h 10m'],
    'Peshawar-Lahore': [9, 0, 10, 10, '1h 10m'],
    'Lahore-Multan': [8, 0, 9, 0, '1h 00m'],
    'Multan-Lahore': [8, 0, 9, 0, '1h 00m'],
    'Lahore-Quetta': [9, 0, 11, 0, '2h 00m'],
    'Quetta-Lahore': [9, 0, 11, 0, '2h 00m'],
    'Lahore-Faisalabad': [8, 0, 9, 0, '1h 00m'],
    'Faisalabad-Lahore': [8, 30, 9, 30, '1h 00m'],
    'Lahore-Sialkot': [7, 30, 8, 15, '0h 45m'],
    'Sialkot-Lahore': [7, 30, 8, 15, '0h 45m'],
    'Lahore-Gilgit': [7, 0, 8, 45, '1h 45m'],
    'Gilgit-Lahore': [7, 0, 8, 45, '1h 45m'],
    'Lahore-Skardu': [7, 0, 9, 0, '2h 00m'],
    'Skardu-Lahore': [7, 0, 9, 0, '2h 00m'],
    'Islamabad-Peshawar': [8, 0, 8, 45, '0h 45m'],
    'Peshawar-Islamabad': [8, 30, 9, 15, '0h 45m'],
    'Islamabad-Multan': [10, 0, 11, 15, '1h 15m'],
    'Multan-Islamabad': [10, 0, 11, 15, '1h 15m'],
    'Islamabad-Quetta': [9, 0, 10, 45, '1h 45m'],
    'Quetta-Islamabad': [9, 0, 10, 45, '1h 45m'],
    'Islamabad-Gilgit': [7, 30, 9, 0, '1h 30m'],
    'Gilgit-Islamabad': [7, 0, 8, 30, '1h 30m'],
    'Islamabad-Skardu': [7, 0, 8, 30, '1h 30m'],
    'Skardu-Islamabad': [7, 0, 8, 30, '1h 30m'],
    'Peshawar-Multan': [10, 0, 11, 15, '1h 15m'],
    'Multan-Peshawar': [10, 0, 11, 15, '1h 15m'],
    'Peshawar-Quetta': [9, 0, 11, 30, '2h 30m'],
    'Quetta-Peshawar': [9, 0, 11, 30, '2h 30m'],
    'Faisalabad-Islamabad': [10, 0, 11, 0, '1h 00m'],
    'Islamabad-Faisalabad': [10, 0, 11, 0, '1h 00m'],
    'Sialkot-Islamabad': [9, 0, 10, 0, '1h 00m'],
    'Islamabad-Sialkot': [9, 0, 10, 0, '1h 00m'],
    'Gwadar-Islamabad': [10, 0, 12, 15, '2h 15m'],
    'Islamabad-Gwadar': [10, 0, 12, 15, '2h 15m'],
    'Gwadar-Lahore': [9, 0, 11, 30, '2h 30m'],
    'Lahore-Gwadar': [9, 0, 11, 30, '2h 30m'],
    'Rawalpindi-Peshawar': [8, 0, 8, 45, '0h 45m'],
    'Peshawar-Rawalpindi': [8, 30, 9, 15, '0h 45m'],
  };

  ({int dH, int dM, int aH, int aM, String dur}) _scheduledTimes(
      String fromName, String toName) {
    final t = _scheduleMap['$fromName-$toName'];
    if (t != null) {
      return (
        dH: t[0] as int,
        dM: t[1] as int,
        aH: t[2] as int,
        aM: t[3] as int,
        dur: t[4] as String,
      );
    }
    return (dH: 9, dM: 0, aH: 11, aM: 0, dur: '2h 00m');
  }

  List<FlightRoute> _buildRoutes(City from, City to, DateTime base) {
    final s = _scheduledTimes(from.name, to.name);
    return [
      FlightRoute(
        id: '1',
        airport: _airportForCity(from),
        time: DateTime(base.year, base.month, base.day, s.dH, s.dM),
        type: RouteType.depart,
      ),
      FlightRoute(
        id: '2',
        airport: _airportForCity(to),
        time: DateTime(base.year, base.month, base.day, s.aH, s.aM),
        type: RouteType.arrival,
      ),
    ];
  }

  void _onBookNow() async {
    final pkg = _pkg;
    final City fromCity = pkg?.from ?? cityList[0];
    final City toCity = pkg?.to ?? cityList[6];
    final Airport fromAirport = _airportForCity(fromCity);
    final Airport toAirport = _airportForCity(toCity);
    final bool isRoundTrip = pkg?.roundTrip ?? false;
    // Auth gate at BOOK NOW — browsing package detail was free
    final nav = Navigator.of(context);
    final isGuest = await AuthService.isGuestMode();
    if (isGuest && mounted) {
      AuthGateSheet.show(nav.context, action: 'to book this flight package');
      return;
    }
    // For round-trip the package price covers both legs; split evenly so the
    // booking screen sums back to _finalPrice correctly.
    final double legPrice = isRoundTrip ? _finalPrice / 2 : _finalPrice;

    final s = _scheduledTimes(fromCity.name, toCity.name);
    final String depStr =
        '${s.dH.toString().padLeft(2, '0')}:${s.dM.toString().padLeft(2, '0')}';
    final String arrStr =
        '${s.aH.toString().padLeft(2, '0')}:${s.aM.toString().padLeft(2, '0')}';
    final sr = _scheduledTimes(toCity.name, fromCity.name);
    final String retDepStr =
        '${sr.dH.toString().padLeft(2, '0')}:${sr.dM.toString().padLeft(2, '0')}';
    final String retArrStr =
        '${sr.aH.toString().padLeft(2, '0')}:${sr.aM.toString().padLeft(2, '0')}';

    final FlightResult outbound = FlightResult(
      id: pkg?.id ?? '0',
      airlineName: pkg?.plane.name ?? 'Airline',
      airlineCode: pkg?.plane.code ?? 'N/A',
      airlineLogo: pkg?.plane.logo ?? '',
      departureTime: depStr,
      arrivalTime: arrStr,
      duration: s.dur,
      stops: 0,
      stopCities: [],
      price: legPrice,
      isRefundable: pkg?.hasRefund ?? false,
      cabinClass: pkg?.plane.classType ?? 'Economy',
    );

    final FlightResult? returnFlight = isRoundTrip
        ? FlightResult(
            id: '${pkg?.id ?? '0'}_ret',
            airlineName: pkg?.plane.name ?? 'Airline',
            airlineCode: pkg?.plane.code ?? 'N/A',
            airlineLogo: pkg?.plane.logo ?? '',
            departureTime: retDepStr,
            arrivalTime: retArrStr,
            duration: sr.dur,
            stops: 0,
            stopCities: [],
            price: legPrice,
            isRefundable: pkg?.hasRefund ?? false,
            cabinClass: pkg?.plane.classType ?? 'Economy',
          )
        : null;

    final DateTime departDate = _departDate;
    final DateTime returnDate = _returnDate;

    Get.toNamed(
      AppLink.bookingStep1,
      arguments: {
        'isRoundTrip': isRoundTrip,
        'flight': outbound,
        'outboundFlight': isRoundTrip ? outbound : null,
        'returnFlight': returnFlight,
        'searchParams': {
          'fromAirport': fromAirport,
          'toAirport': toAirport,
          'departureDate': departDate,
          'returnDate': isRoundTrip ? returnDate : null,
          'adults': 1,
          'children': 0,
          'infants': 0,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _pkg;
    final City fromCity = pkg?.from ?? cityList[0];
    final City toCity = pkg?.to ?? cityList[6];
    final Plane plane = pkg?.plane ?? planeList[0];
    final String label =
        pkg?.label ?? 'Discount ${_discount.toStringAsFixed(0)}%';

    final bool wideScreen = ThemeBreakpoints.smUp(context);
    final List<FlightRoute> departRoutes =
        _buildRoutes(fromCity, toCity, _departDate);
    final List<FlightRoute> returnRoutes = (pkg?.roundTrip ?? false)
        ? _buildRoutes(toCity, fromCity, _returnDate)
        : departRoute; // fallback static; only shown for round-trip

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        shadowColor: TravelloTheme.paperLight,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
        actions: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
                onPressed: () {
                  Get.toNamed(AppLink.faq);
                },
                style: IconButton.styleFrom(),
                icon: const Icon(Icons.help_outline_rounded,
                    color: TravelloTheme.textSecondary, size: 18)),
          ),
          const SizedBox(
            width: 16,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Stack(alignment: Alignment.topCenter, children: [
          /// DECORATION BG
          Container(
            alignment: Alignment.bottomCenter,
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(pkg?.img ?? ImgApi.photo[53]),
                fit: BoxFit.cover,
              ),
            ),
          ),

          /// DECORATION ROUNDED
          Positioned(
            top: 120,
            left: -10,
            child: CustomPaint(
              painter: OvalShape(
                  color: TravelloTheme.paperLight,
                  width: MediaQuery.of(context).size.width + 20),
            ),
          ),

          /// CONTENTS
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 50),
            wideScreen
                ? FlightSummaryWide(
                    from: fromCity,
                    to: toCity,
                    price: _basePrice,
                    discount: _discount,
                    label: label,
                    plane: plane,
                    roundTrip: pkg?.roundTrip ?? false,
                  )
                : FlightSummary(
                    from: fromCity,
                    to: toCity,
                    price: _basePrice,
                    discount: _discount,
                    label: label,
                    plane: plane,
                    roundTrip: pkg?.roundTrip ?? false,
                  ),
            wideScreen
                ? FlightRoutesHorizontal(
                    title: 'Departure',
                    routes: departRoutes,
                    dateLabel:
                        DateFormat('EEE, d MMM yyyy').format(_departDate),
                  )
                : FlightRoutes(
                    title: 'Departure',
                    routes: departRoutes,
                    dateLabel:
                        DateFormat('EEE, d MMM yyyy').format(_departDate),
                  ),
            if (pkg?.roundTrip ?? false) ...[
              wideScreen
                  ? FlightRoutesHorizontal(
                      title: 'Return',
                      routes: returnRoutes,
                      dateLabel:
                          DateFormat('EEE, d MMM yyyy').format(_returnDate),
                    )
                  : FlightRoutes(
                      title: 'Return',
                      routes: returnRoutes,
                      dateLabel:
                          DateFormat('EEE, d MMM yyyy').format(_returnDate),
                    ),
            ],
            const SizedBox(height: 24),
          ])
        ]),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: R.rh(context, 80),
        color: TravelloTheme.paperLight,
        padding: EdgeInsets.symmetric(horizontal: R.r(context, 16), vertical: 8),
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
                  Text('PKR ${_basePrice.toStringAsFixed(0)}',
                      textAlign: TextAlign.end,
                      style: TravelloTheme.headline.copyWith(
                          color: TravelloTheme.textSecondary,
                          decoration: TextDecoration.lineThrough,
                          height: 1)),
                  Text('PKR ${_finalPrice.toStringAsFixed(0)}',
                      textAlign: TextAlign.end,
                      style: TravelloTheme.title.copyWith(
                          color: TravelloTheme.primaryMain,
                          height: 1,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(width: R.r(context, 24)),
              Expanded(
                child: SizedBox(
                  height: R.rh(context, 50),
                  child: FilledButton(
                      onPressed: _onBookNow,
                      style: FilledButton.styleFrom(
                        backgroundColor: TravelloTheme.primaryMain,
                      ),
                      child: const Text('BOOK NOW')),
                ),
              )
            ]),
      ),
    );
  }
}
