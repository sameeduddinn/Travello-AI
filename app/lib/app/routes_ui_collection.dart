import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/samples/button_collection.dart';
import 'package:flight_app/screens/samples/card_collection.dart';
import 'package:flight_app/screens/samples/color_collection.dart';
import 'package:flight_app/screens/samples/form_input_collection.dart';
import 'package:flight_app/screens/samples/shadow_border_radius.dart';
import 'package:flight_app/screens/samples/typography_collection.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:get/route_manager.dart';

const int pageTransitionDuration = 200;

final List<GetPage> routesUiCollection = [
  GetPage(
    name: AppLink.buttonCollection,
    page: () => const GeneralLayout(content: ButtonCollection()),
  ),
  GetPage(
    name: AppLink.shadowRoundedCollection,
    page: () => const GeneralLayout(content: ShadowBorderRadius()),
  ),
  GetPage(
    name: AppLink.typographyCollection,
    page: () => const GeneralLayout(content: TypographyCollection()),
  ),
  GetPage(
    name: AppLink.colorCollection,
    page: () => const GeneralLayout(content: ColorCollection()),
  ),
  GetPage(
    name: AppLink.formSample,
    page: () => const GeneralLayout(content: FormInputCollection()),
  ),
  GetPage(
    name: AppLink.cardCollection,
    page: () => const GeneralLayout(content: CardCollection()),
  ),
];