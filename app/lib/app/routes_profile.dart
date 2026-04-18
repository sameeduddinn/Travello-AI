import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:flight_app/screens/profile/detail_point.dart';
import 'package:flight_app/screens/profile/edit_password.dart';
import 'package:flight_app/screens/profile/edit_profile.dart';
import 'package:flight_app/screens/profile/profile_main.dart';
import 'package:flight_app/screens/profile/rewards.dart';
import 'package:flight_app/screens/profile/faq_list.dart';
import 'package:flight_app/screens/profile/contact.dart';
import 'package:flight_app/screens/profile/terms_condition.dart';
import 'package:flight_app/screens/profile/privacy_policy.dart';
import 'package:flight_app/screens/profile/cancellation_policy.dart';
import 'package:flight_app/screens/profile/about_us.dart';
import 'package:flight_app/screens/profile/careers.dart';
import 'package:flight_app/screens/profile/blog.dart';
import 'package:flight_app/ui/layouts/home_layout.dart';
import 'package:get/route_manager.dart';

const int pageTransitionDuration = 200;

final List<GetPage> routesProfile = [
  GetPage(
      name: AppLink.profile,
      page: () => const HomeLayout(content: ProfileMain()),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: pageTransitionDuration)),
  GetPage(
    name: AppLink.reward,
    page: () => const GeneralLayout(content: Rewards()),
  ),
  GetPage(
    name: AppLink.detailPoint,
    page: () => const GeneralLayout(content: DetailPoint()),
  ),
  GetPage(
    name: AppLink.editProfile,
    page: () => const GeneralLayout(content: EditProfile()),
  ),
  GetPage(
    name: AppLink.editPassword,
    page: () => const GeneralLayout(content: EditPassword()),
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
    name: AppLink.privacy,
    page: () => const GeneralLayout(content: PrivacyPolicy()),
  ),
  GetPage(
    name: AppLink.cancellation,
    page: () => const GeneralLayout(content: CancellationPolicy()),
  ),
  GetPage(
    name: AppLink.aboutUs,
    page: () => const GeneralLayout(content: AboutUs()),
  ),
  GetPage(
    name: AppLink.careers,
    page: () => const GeneralLayout(content: Careers()),
  ),
  GetPage(
    name: AppLink.blog,
    page: () => const GeneralLayout(content: Blog()),
  ),
];
