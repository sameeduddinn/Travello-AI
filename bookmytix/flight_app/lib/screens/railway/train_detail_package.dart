import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/models/train_package.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flight_app/widgets/decorations/oval_shape.dart';
import 'package:flight_app/widgets/flight/flight_routes.dart';
import 'package:flight_app/widgets/flight/flight_routes_horizontal.dart';
import 'package:flight_app/widgets/railway/train_summary.dart';
import 'package:flight_app/widgets/railway/train_summary_wide.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

/// Train package detail screen - matches flight package UI exactly
class TrainDetailPackage extends StatefulWidget {
  const TrainDetailPackage({super.key});

  @override
  State<TrainDetailPackage> createState() => _TrainDetailPackageState();
}

class _TrainDetailPackageState extends State<TrainDetailPackage> {
  late TrainPackage? _pkg;
  late double _basePrice;
  late double _discount;
  late double _finalPrice;
  late DateTime _departDate;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _pkg = args['package'] as TrainPackage?;
      _departDate = (args['departDate'] as DateTime?) ??
          DateTime.now().add(const Duration(days: 7));
    } else {
      _pkg = args as TrainPackage?;
      _departDate = DateTime.now().add(const Duration(days: 7));
    }
    _basePrice = _pkg?.price ?? 1000;
    // Calculate discount based on package type
    _discount = _getDiscountPercent(_pkg?.packageType ?? 'express');
    _finalPrice = _basePrice - _basePrice * _discount / 100;
  }

  /// Find railway station by name
  RailwayStation _stationByName(String name) {
    try {
      return PakistanRailwayStations.getAllStations().firstWhere(
        (s) => s.name.toLowerCase().contains(name.toLowerCase()),
      );
    } catch (_) {
      return RailwayStation(
        code: name.substring(0, 3).toUpperCase(),
        name: name,
        city: name,
      );
    }
  }

  void _onBookNow() async {
    // Auth gate at booking intent — browsing train details was free
    final nav = Navigator.of(context);
    final isGuest = await AuthService.isGuestMode();
    if (isGuest && mounted) {
      AuthGateSheet.show(nav.context, action: 'to book this train');
      return;
    }
    final pkg = _pkg;
    final fromStation = _stationByName(pkg?.fromStation ?? 'Karachi');
    final toStation = _stationByName(pkg?.toStation ?? 'Lahore');
    final bool isRoundTrip = pkg?.roundTrip ?? false;
    final double legPrice = isRoundTrip ? _finalPrice / 2 : _finalPrice;

    final String depTime = pkg?.departureTime ?? '09:00 AM';
    final String dur = pkg?.duration ?? '8h';
    final String arrTime = _computeArrivalTime(depTime, dur);

    final TrainResult outbound = TrainResult(
      id: pkg?.id ?? '0',
      trainName: pkg?.name ?? 'Express Train',
      trainNumber: pkg?.trainNumber ?? '001',
      departureTime: depTime,
      arrivalTime: arrTime,
      duration: dur,
      arrivesNextDay: false,
      classSeats: {
        pkg?.trainClass ?? 'Economy': 50,
      },
      classPrices: {
        pkg?.trainClass ?? 'Economy': legPrice,
      },
      availableClasses: [pkg?.trainClass ?? 'Economy'],
    );

    final TrainResult? returnTrain = isRoundTrip
        ? TrainResult(
            id: '${pkg?.id ?? '0'}_ret',
            trainName: pkg?.name ?? 'Express Train',
            trainNumber: pkg?.trainNumber ?? '001',
            departureTime: depTime,
            arrivalTime: arrTime,
            duration: dur,
            arrivesNextDay: false,
            classSeats: {
              pkg?.trainClass ?? 'Economy': 50,
            },
            classPrices: {
              pkg?.trainClass ?? 'Economy': legPrice,
            },
            availableClasses: [pkg?.trainClass ?? 'Economy'],
          )
        : null;

    final DateTime departDate = DateTime.now().add(const Duration(days: 7));
    final DateTime returnDate = departDate.add(const Duration(days: 7));

    Get.toNamed(
      '/train-passengers',
      arguments: {
        'train': outbound,
        'selectedClass': pkg?.trainClass ?? 'Economy',
        'searchParams': {
          'fromStation': fromStation,
          'toStation': toStation,
          'departureDate': departDate,
          'returnDate': isRoundTrip ? returnDate : null,
          'adults': 1,
          'children': 0,
          'infants': 0,
        },
        'isRoundTrip': isRoundTrip,
        'outboundTrain': isRoundTrip ? outbound : null,
        'returnTrain': returnTrain,
        'outboundClass': pkg?.trainClass ?? 'Economy',
        'returnClass': pkg?.trainClass ?? 'Economy',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _pkg;
    final String label = _getDiscountLabel(pkg?.packageType ?? 'express');
    final bool wideScreen = ThemeBreakpoints.smUp(context);

    final String headerImageUrl = (pkg?.imageUrl ?? '').trim();
    final Widget headerImage = headerImageUrl.isNotEmpty
        ? Image.network(
            headerImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              ImgApi.railwayBanner,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            ImgApi.railwayBanner,
            fit: BoxFit.cover,
          );

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
              style: ThemeButton.iconBtn(context),
              icon: Icon(
                Icons.help_outline_rounded,
                color: colorScheme(context).onSurface,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            /// DECORATION BG
            SizedBox(
              width: double.infinity,
              height: 150,
              child: headerImage,
            ),

            /// DECORATION ROUNDED
            Positioned(
              top: 120,
              left: -10,
              child: CustomPaint(
                painter: OvalShape(
                  color: TravelloTheme.paperLightContainerLowest,
                  width: MediaQuery.of(context).size.width + 20,
                ),
              ),
            ),

            /// CONTENTS
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),

                /// TRAIN SUMMARY – mirrors FlightSummary / FlightSummaryWide
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wideScreen ? 96 : 0,
                  ),
                  child: wideScreen
                      ? TrainSummaryWide(
                          trainName: pkg?.name ?? 'Express',
                          trainNumber: pkg?.trainNumber ?? '001',
                          trainClass: pkg?.trainClass ?? 'Economy',
                          fromCode: _stationByName(pkg?.fromStation ?? '').code,
                          fromCity: _stationByName(pkg?.fromStation ?? '').city,
                          toCode: _stationByName(pkg?.toStation ?? '').code,
                          toCity: _stationByName(pkg?.toStation ?? '').city,
                          label: label,
                          discount: _discount,
                          price: _basePrice,
                          roundTrip: pkg?.roundTrip ?? false,
                        )
                      : TrainSummary(
                          trainName: pkg?.name ?? 'Express',
                          trainNumber: pkg?.trainNumber ?? '001',
                          trainClass: pkg?.trainClass ?? 'Economy',
                          fromCode: _stationByName(pkg?.fromStation ?? '').code,
                          fromCity: _stationByName(pkg?.fromStation ?? '').city,
                          toCode: _stationByName(pkg?.toStation ?? '').code,
                          toCity: _stationByName(pkg?.toStation ?? '').city,
                          label: label,
                          discount: _discount,
                          price: _basePrice,
                          roundTrip: pkg?.roundTrip ?? false,
                        ),
                ),

                /// DEPARTURE ROUTES – reuses FlightRoutes / FlightRoutesHorizontal
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wideScreen ? 96 : 0,
                  ),
                  child: wideScreen
                      ? FlightRoutesHorizontal(
                          title: 'Departure',
                          routes: _buildRouteList(
                            _stationByName(pkg?.fromStation ?? 'Karachi Cantt'),
                            _stationByName(pkg?.toStation ?? 'Lahore Junction'),
                            pkg?.departureTime ?? '09:00 AM',
                            pkg?.duration ?? '8h',
                          ),
                          dateLabel:
                              DateFormat('EEE, d MMM yyyy').format(_departDate),
                        )
                      : FlightRoutes(
                          title: 'Departure',
                          routes: _buildRouteList(
                            _stationByName(pkg?.fromStation ?? 'Karachi Cantt'),
                            _stationByName(pkg?.toStation ?? 'Lahore Junction'),
                            pkg?.departureTime ?? '09:00 AM',
                            pkg?.duration ?? '8h',
                          ),
                          dateLabel:
                              DateFormat('EEE, d MMM yyyy').format(_departDate),
                        ),
                ),

                /// RETURN ROUTES (round-trip only)
                if (pkg?.roundTrip ?? false)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wideScreen ? 96 : 0,
                    ),
                    child: wideScreen
                        ? FlightRoutesHorizontal(
                            title: 'Return',
                            routes: _buildRouteList(
                              _stationByName(
                                  pkg?.toStation ?? 'Lahore Junction'),
                              _stationByName(
                                  pkg?.fromStation ?? 'Karachi Cantt'),
                              pkg?.departureTime ?? '09:00 AM',
                              pkg?.duration ?? '8h',
                            ),
                            dateLabel: DateFormat('EEE, d MMM yyyy').format(
                                _departDate.add(const Duration(days: 7))),
                          )
                        : FlightRoutes(
                            title: 'Return',
                            routes: _buildRouteList(
                              _stationByName(
                                  pkg?.toStation ?? 'Lahore Junction'),
                              _stationByName(
                                  pkg?.fromStation ?? 'Karachi Cantt'),
                              pkg?.departureTime ?? '09:00 AM',
                              pkg?.duration ?? '8h',
                            ),
                            dateLabel: DateFormat('EEE, d MMM yyyy').format(
                                _departDate.add(const Duration(days: 7))),
                          ),
                  ),
                const VSpaceBig(),
              ],
            )
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: R.rh(context, 80),
        color: TravelloTheme.paperLight,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
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
                Text(
                  'PKR ${_basePrice.toStringAsFixed(0)}',
                  textAlign: TextAlign.end,
                  style: TravelloTheme.headline.copyWith(
                    color: colorScheme(context).onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                    height: 1,
                  ),
                ),
                Text(
                  'PKR ${_finalPrice.toStringAsFixed(0)}',
                  textAlign: TextAlign.end,
                  style: TravelloTheme.title.copyWith(
                    color: TravelloTheme.primaryMain,
                    height: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _onBookNow,
                  style: ThemeButton.btnBig.merge(ThemeButton.primary),
                  child: const Text('BOOK NOW', style: TravelloTheme.subtitle2),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Build a 2-stop [depart, arrival] FlightRoute list for a train leg.
  List<FlightRoute> _buildRouteList(
    RailwayStation from,
    RailwayStation to,
    String depTime,
    String duration,
  ) {
    final Airport fromAirport =
        Airport(id: 'f', code: from.code, name: from.name, location: from.city);
    final Airport toAirport =
        Airport(id: 't', code: to.code, name: to.name, location: to.city);
    return [
      FlightRoute(
          id: '1',
          airport: fromAirport,
          time: _parseDT(depTime),
          type: RouteType.depart),
      FlightRoute(
          id: '2',
          airport: toAirport,
          time: _parseArrivalDT(depTime, duration),
          type: RouteType.arrival),
    ];
  }

  /// Parse a time string like "11:00 PM" into a DateTime on _departDate.
  DateTime _parseDT(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final timePart = cleaned.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = timePart.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      return DateTime(
          _departDate.year, _departDate.month, _departDate.day, hour, minute);
    } catch (_) {
      return _departDate;
    }
  }

  /// Compute arrival DateTime from departure time string + duration string.
  DateTime _parseArrivalDT(String dep, String dur) {
    final base = _parseDT(dep);
    int addHours = 0, addMinutes = 0;
    final hMatch = RegExp(r'(\d+)\s*h').firstMatch(dur);
    final mMatch = RegExp(r'(\d+)\s*m').firstMatch(dur);
    if (hMatch != null) addHours = int.parse(hMatch.group(1)!);
    if (mMatch != null) addMinutes = int.parse(mMatch.group(1)!);
    return base.add(Duration(hours: addHours, minutes: addMinutes));
  }

  /// Computes arrival time string given a departure string and duration string.
  /// departure: "11:00 PM" or "06:00 AM"
  /// duration:  "13h 30m" or "8h" or "15h"
  String _computeArrivalTime(String departure, String duration) {
    try {
      // Parse departure
      final cleaned = departure.trim().toUpperCase();
      final hasPeriod = cleaned.contains('AM') || cleaned.contains('PM');
      final period = hasPeriod ? (cleaned.contains('PM') ? 'PM' : 'AM') : '';
      final timePart = cleaned.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timePart.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (hasPeriod) {
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
      }
      // Parse duration
      int addHours = 0, addMinutes = 0;
      final hMatch = RegExp(r'(\d+)\s*h').firstMatch(duration);
      final mMatch = RegExp(r'(\d+)\s*m').firstMatch(duration);
      if (hMatch != null) addHours = int.parse(hMatch.group(1)!);
      if (mMatch != null) addMinutes = int.parse(mMatch.group(1)!);
      // Compute arrival (modulo 24-hour clock)
      int totalMinutes = hour * 60 + minute + addHours * 60 + addMinutes;
      totalMinutes = totalMinutes % (24 * 60);
      int arrHour = totalMinutes ~/ 60;
      int arrMin = totalMinutes % 60;
      // Format as "HH:MM AM/PM"
      final arrPeriod = arrHour >= 12 ? 'PM' : 'AM';
      int display = arrHour > 12 ? arrHour - 12 : (arrHour == 0 ? 12 : arrHour);
      return '${display.toString().padLeft(2, '0')}:${arrMin.toString().padLeft(2, '0')} $arrPeriod';
    } catch (_) {
      return '—';
    }
  }

  double _getDiscountPercent(String packageType) {
    switch (packageType) {
      case 'business':
        return 30;
      case 'sleeper':
        return 20;
      case 'express':
        return 15;
      default:
        return 10;
    }
  }

  String _getDiscountLabel(String packageType) {
    switch (packageType) {
      case 'business':
        return '30% OFF';
      case 'sleeper':
        return '20% OFF';
      case 'express':
        return '15% OFF';
      default:
        return '10% OFF';
    }
  }
}
