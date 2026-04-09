import 'package:flight_app/app/routes_auth.dart';
import 'package:flight_app/app/routes_booking.dart';
import 'package:flight_app/app/routes_flight.dart';
import 'package:flight_app/app/routes_payment.dart';
import 'package:flight_app/app/routes_profile.dart';
import 'package:flight_app/app/routes_ui_collection.dart';
import 'package:flight_app/app/routes_professional.dart';
import 'package:flight_app/screens/ai/ai_assistant.dart';
import 'package:flight_app/screens/auth/email_verification.dart';
import 'package:flight_app/screens/explore/explore_main.dart';
import 'package:flight_app/screens/healthcare/healthcare_screen.dart';
import 'package:flight_app/screens/intro/intro_screen.dart';
import 'package:flight_app/screens/intro/start_screen.dart';
import 'package:flight_app/screens/messages/notification.dart';
import 'package:flight_app/screens/mode_selector/travel_mode_selection.dart';
import 'package:flight_app/screens/home/unified_home_screen.dart';
import 'package:flight_app/screens/not_found.dart';
import 'package:flight_app/screens/orders/booking_detail.dart';
import 'package:flight_app/screens/orders/hotel_booking_confirmation.dart';
import 'package:flight_app/screens/orders/my_bookings.dart';
import 'package:flight_app/screens/profile/contact.dart';
import 'package:flight_app/screens/profile/faq_list.dart';
import 'package:flight_app/screens/profile/terms_condition.dart';
import 'package:flight_app/screens/promo/flight_package_detail.dart';
import 'package:flight_app/screens/promo/promo_main.dart';
import 'package:flight_app/screens/promo/voucher_detail.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/screens/railway/train_search_home.dart';
import 'package:flight_app/screens/railway/train_detail_package.dart';
import 'package:flight_app/screens/railway/train_package_detail.dart';
import 'package:flight_app/screens/railway_booking/railway_booking_passengers.dart';
import 'package:flight_app/screens/railway_booking/railway_booking_facilities.dart';
import 'package:flight_app/screens/railway_booking/railway_booking_checkout.dart';
import 'package:flight_app/screens/search/search_flight.dart';
import 'package:flight_app/screens/search/search_list.dart';
import 'package:flight_app/screens/search/city_search_results.dart';
import 'package:flight_app/screens/weather/weather_screen.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:flight_app/ui/layouts/home_layout.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/app/app_link.dart';

const int pageTransitionDuration = 200;

final List<GetPage> appRoutes = [
  /// START - INTRO & AUTH FLOW
  GetPage(
      name: AppLink.home,
      page: () => const StartScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),

  /// UNIFIED HOME HUB
  GetPage(
      name: '/home-hub',
      page: () => const UnifiedHomeScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),

  /// WELCOME / ONBOARDING
  GetPage(
      name: '/welcome',
      page: () => const StartScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.intro,
    page: () => GeneralLayout(content: IntroScreen(saveIntroStatus: () {})),
  ),
  GetPage(
    name: AppLink.modeSelection,
    page: () => const TravelModeSelection(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.emailVerification,
    page: () => const EmailVerification(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.notification,
    page: () => const GeneralLayout(content: Notification()),
  ),
  GetPage(
    name: AppLink.faq,
    page: () => const GeneralLayout(content: FaqList()),
  ),
  GetPage(
    name: AppLink.contact,
    page: () => const GeneralLayout(content: Contact()),
  ),
  GetPage(
    name: AppLink.terms,
    page: () => const GeneralLayout(content: TermsCondition()),
  ),
  GetPage(
    name: AppLink.notFound,
    page: () => const GeneralLayout(content: NotFound()),
  ),

  // MY TICKET
  GetPage(
      name: AppLink.myTicket,
      page: () => const HomeLayout(content: MyBookings()),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.ticketDetail,
    page: () => const GeneralLayout(content: BookingDetail()),
  ),
  GetPage(
    name: AppLink.hotelBookingDetail,
    page: () => const GeneralLayout(content: HotelBookingConfirmation()),
  ),

  /// SEARCH
  GetPage(
    name: AppLink.searchFlight,
    page: () => const GeneralLayout(content: SearchFlight()),
  ),
  GetPage(
    name: AppLink.searchList,
    page: () => const GeneralLayout(content: SearchList()),
  ),
  GetPage(
    name: '/city-search-results',
    page: () => const GeneralLayout(content: CitySearchResults()),
  ),

  /// EXPLORE
  GetPage(
      name: AppLink.explore,
      page: () => const HomeLayout(content: ExploreMain()),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),

  /// PROMO
  GetPage(
      name: AppLink.promo,
      page: () => const HomeLayout(content: PromoMain()),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.promoDetail,
    page: () => const GeneralLayout(content: PromoDetail()),
  ),
  GetPage(
    name: AppLink.voucherDetail,
    page: () => const GeneralLayout(content: VoucherDetail()),
  ),

  /// TRAVELLO AI FEATURES
  // Redirect old railway-search to new train-search-home
  GetPage(
    name: AppLink.railwaySearch,
    page: () => const GeneralLayout(content: TrainSearchHome()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  // Redirect old railway-list to new train-results
  GetPage(
    name: AppLink.railwayList,
    page: () => const GeneralLayout(content: TrainResultsScreen()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.trainDetailPackage,
    page: () => const GeneralLayout(content: TrainDetailPackage()),
  ),
  GetPage(
    name: AppLink.trainPackageAll,
    page: () => const GeneralLayout(content: TrainPackageDetail()),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: pageTransitionDuration),
  ),
  GetPage(
    name: AppLink.railwayBookingStep1,
    page: () => const GeneralLayout(content: RailwayBookingPassengers()),
  ),
  GetPage(
      name: AppLink.railwayBookingStep2,
      page: () => const GeneralLayout(content: RailwayBookingFacilities()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
      name: AppLink.railwayBookingStep3,
      page: () => const GeneralLayout(content: RailwayBookingCheckout()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.aiAssistant,
    page: () => const GeneralLayout(content: AIAssistantScreen()),
  ),
  GetPage(
    name: AppLink.weather,
    page: () => const GeneralLayout(content: WeatherScreen()),
  ),
  GetPage(
    name: AppLink.healthcare,
    page: () => const GeneralLayout(content: HealthcareScreen()),
  ),

  /// AUTH
  ...routesAuth,

  /// PROFILE
  ...routesProfile,

  /// FLIGHT LIST
  ...routesFlight,

  /// BOOKING
  ...routesBooking,

  /// PAYMENT
  ...routesPayment,

  /// SAMPLE UI
  ...routesUiCollection,

  /// PROFESSIONAL BOOKING FLOWS
  ...routesProfessional,
];
