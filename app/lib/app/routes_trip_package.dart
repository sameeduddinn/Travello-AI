import 'package:get/route_manager.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/trip_package/trip_package_requirements_screen.dart';
import 'package:flight_app/screens/trip_package/trip_package_options_screen.dart';
import 'package:flight_app/screens/trip_package/trip_package_transfer_details_screen.dart';
import 'package:flight_app/screens/trip_package/trip_package_review_screen.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';

const int _tripPackageTransitionDuration = 200;

// Native Trip Package flow — flight/train + hotel (+ hub transfer), one
// atomic package. Distinct from the static promotional "package" screens
// (routes_professional.dart's hotelPackageAll, flightDetailPackage, etc.)
// and from the AI Assistant's own package flow — both untouched.
final List<GetPage> routesTripPackage = [
  GetPage(
    name: AppLink.tripPackageRequirements,
    page: () => const GeneralLayout(content: TripPackageRequirementsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: _tripPackageTransitionDuration),
  ),
  GetPage(
    name: AppLink.tripPackageOptions,
    page: () => const GeneralLayout(content: TripPackageOptionsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: _tripPackageTransitionDuration),
  ),
  GetPage(
    name: AppLink.tripPackageTransferDetails,
    page: () => const GeneralLayout(content: TripPackageTransferDetailsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: _tripPackageTransitionDuration),
  ),
  GetPage(
    name: AppLink.tripPackageReview,
    page: () => const GeneralLayout(content: TripPackageReviewScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: _tripPackageTransitionDuration),
  ),
];
