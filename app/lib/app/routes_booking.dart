import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/booking/add_passengger.dart';
import 'package:flight_app/screens/booking/booking_checkout.dart';
import 'package:flight_app/screens/booking/booking_facilites.dart';
import 'package:flight_app/screens/booking/booking_passengers.dart';
import 'package:flight_app/screens/orders/airline_grade_e_ticket.dart';
import 'package:flight_app/screens/orders/order_history.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:get/route_manager.dart';

const int pageTransitionDuration = 200;

final List<GetPage> routesBooking = [
  GetPage(
    name: AppLink.bookingStep1,
    page: () => const GeneralLayout(content: BookingPassengers()),
  ),
  GetPage(
      name: AppLink.bookingStep2,
      page: () => const GeneralLayout(content: BookingFacilites()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
      name: AppLink.bookingStep3,
      page: () => const GeneralLayout(content: BookingCheckout()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.addPassengger,
    page: () => const GeneralLayout(content: AddPassengger()),
  ),
  GetPage(
    name: AppLink.eTicket,
    page: () => const AirlineGradeETicket(),
  ),
  GetPage(
    name: AppLink.orderHistory,
    page: () => const GeneralLayout(content: OrderHistory()),
  ),
];
