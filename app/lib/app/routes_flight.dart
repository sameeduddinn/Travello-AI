import 'package:flight_app/screens/flight/flight_not_found.dart';
import 'package:flight_app/screens/flight/package_not_found.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:flight_app/screens/flight/flight_detail.dart';
import 'package:flight_app/screens/flight/flight_detail_package.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/app/app_link.dart';

const int pageTransitionDuration = 200;

// Redirects old routes to new professional screens
final List<GetPage> routesFlight = [
  // Redirect old flight-list to new flight-results
  GetPage(
    name: AppLink.flightList,
    page: () => const GeneralLayout(content: FlightResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.flightListRoundTrip,
    page: () => const GeneralLayout(content: FlightResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.flightDetail,
    page: () => const GeneralLayout(content: FlightDetail()),
  ),
  GetPage(
    name: AppLink.flightDetailPackage,
    page: () => const GeneralLayout(content: FlightDetailPackage()),
  ),
  GetPage(
    name: AppLink.flightNotFound,
    page: () => const GeneralLayout(content: FlightNotFound()),
  ),
  GetPage(
    name: AppLink.packageNotFound,
    page: () => const GeneralLayout(content: PackageNotFound()),
  ),
];
