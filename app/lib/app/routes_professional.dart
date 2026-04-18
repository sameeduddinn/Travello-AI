import 'package:get/route_manager.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/flight/flight_search_home.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/screens/flight/flight_detail_professional.dart';
import 'package:flight_app/screens/railway/train_search_home.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/screens/railway_booking/train_passenger_form.dart';
import 'package:flight_app/screens/payment/payment_screen_professional.dart';
import 'package:flight_app/screens/hotel/hotel_search_screen.dart';
import 'package:flight_app/screens/hotel/hotel_results_screen.dart';
import 'package:flight_app/screens/hotel/hotel_detail_screen.dart';
import 'package:flight_app/screens/hotel/hotel_guest_form_screen.dart';
import 'package:flight_app/screens/hotel/hotel_checkout.dart';
import 'package:flight_app/screens/hotel/hotel_package_detail.dart';
import 'package:flight_app/screens/transport/transport_screen.dart';
import 'package:flight_app/screens/ai/ai_assistant.dart';
import 'package:flight_app/screens/weather/weather_screen.dart';
import 'package:flight_app/screens/healthcare/healthcare_screen.dart';
import 'package:flight_app/screens/wishlist/wishlist_screen.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';

const int pageTransitionDuration = 200;

// Professional booking flow routes
final List<GetPage> routesProfessional = [
  /// FLIGHT BOOKING - PROFESSIONAL
  GetPage(
    name: '/flight-search-home',
    page: () => const GeneralLayout(content: FlightSearchHome()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: '/flight-results',
    page: () => const GeneralLayout(content: FlightResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: '/flight-detail-professional',
    page: () => const GeneralLayout(content: FlightDetailProfessional()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// TRAIN BOOKING - PROFESSIONAL
  GetPage(
    name: '/train-search-home',
    page: () => const GeneralLayout(content: TrainSearchHome()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: '/train-results',
    page: () => const GeneralLayout(content: TrainResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: '/train-passengers',
    page: () => const GeneralLayout(content: TrainPassengerForm()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// PAYMENT - PROFESSIONAL
  GetPage(
    name: '/payment-professional',
    page: () => const GeneralLayout(content: PaymentScreenProfessional()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// HOTEL BOOKING
  GetPage(
    name: AppLink.hotelSearch,
    page: () => const GeneralLayout(content: HotelSearchScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.hotelResults,
    page: () => const GeneralLayout(content: HotelResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.hotelDetail,
    page: () => const GeneralLayout(content: HotelDetailScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.hotelGuestForm,
    page: () => const GeneralLayout(content: HotelGuestFormScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.hotelCheckout,
    page: () => const GeneralLayout(content: HotelCheckout()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.hotelPackageAll,
    page: () => const GeneralLayout(content: HotelPackageDetail()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// LOCAL TRANSPORT
  GetPage(
    name: AppLink.transport,
    page: () => const GeneralLayout(content: TransportScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// AI ASSISTANT
  GetPage(
    name: AppLink.aiAssistant,
    page: () => const GeneralLayout(content: AIAssistantScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// WEATHER
  GetPage(
    name: AppLink.weather,
    page: () => const GeneralLayout(content: WeatherScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// HEALTHCARE
  GetPage(
    name: AppLink.healthcare,
    page: () => const GeneralLayout(content: HealthcareScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),

  /// WISHLIST / SAVED
  GetPage(
    name: AppLink.wishlist,
    page: () => const WishlistScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
];
