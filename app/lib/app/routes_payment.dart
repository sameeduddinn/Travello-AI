import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/booking/booking_payment.dart';
import 'package:flight_app/screens/railway_booking/railway_booking_payment.dart';
import 'package:flight_app/screens/payment/payment_detail_cc.dart';
import 'package:flight_app/screens/payment/payment_detail_transfer.dart';
import 'package:flight_app/screens/payment/payment_detail_vac.dart';
import 'package:flight_app/screens/payment/payment_detail_wallet.dart';
import 'package:flight_app/screens/payment/payment_status.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:get/route_manager.dart';

const int pageTransitionDuration = 200;

final List<GetPage> routesPayment = [
  GetPage(
      name: AppLink.railwayPayment,
      page: () => const GeneralLayout(content: RailwayBookingPayment()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
      name: AppLink.payment,
      page: () => const GeneralLayout(content: BookingPayment()),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.paymentCc,
    page: () => const GeneralLayout(content: PaymentDetailCC()),
  ),
  GetPage(
    name: AppLink.paymentEWallet,
    page: () => const GeneralLayout(content: PaymentDetailWallet()),
  ),
  GetPage(
    name: AppLink.paymentVac,
    page: () => const GeneralLayout(content: PaymentDetailVac()),
  ),
  GetPage(
    name: AppLink.paymentTransfer,
    page: () => const GeneralLayout(content: PaymentDetailTransfer()),
  ),
  GetPage(
    name: AppLink.paymentStatus,
    page: () => const GeneralLayout(content: PaymentStatus()),
  ),
];
