import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/cards/activity_card.dart';
import 'package:flight_app/widgets/cards/airport_card.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/cards/flight_portrait_card.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flight_app/widgets/cards/news_card.dart';
import 'package:flight_app/widgets/cards/pricing_card.dart';
import 'package:flight_app/widgets/cards/profile_card.dart';
import 'package:flight_app/widgets/cards/promo_card.dart';
import 'package:flight_app/widgets/cards/rating_card.dart';
import 'package:flight_app/widgets/cards/reward_card.dart';
import 'package:flight_app/widgets/cards/ticket_card.dart';
import 'package:flight_app/widgets/cards/title_icon_card.dart';
import 'package:flight_app/widgets/cards/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class CardCollection extends StatelessWidget {
  const CardCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Card Collection',
            style: ThemeText.subtitle,
          ),
          centerTitle: true,
          leading: BackIconButton(onTap: () {
            Get.back();
          }),
        ),
        body: ListView(padding: EdgeInsets.all(spacingUnit(2)), children: [
          const Text('Activty Card', style: ThemeText.subtitle2),
          const ActivityCard(
              title: 'Sample Activity',
              time: 'Yesterday',
              icon: Icons.history,
              color: Colors.orange),
          const VSpace(),
          const Text('Airport Card', style: ThemeText.subtitle2),
          const AirportCard(
              name: 'Soekarno-Hatta', code: 'JKT', location: 'Jakarta'),
          const VSpace(),
          const Text('Flight Card', style: ThemeText.subtitle2),
          FlightCard(
              from: cityList[0],
              to: cityList[2],
              plane: planeList[4],
              price: 2000,
              depart: DateTime.parse('2025-07-20 20:18:00'),
              arrival: DateTime.parse('2025-07-21 20:18:00'),
              transit: 1),
          const VSpace(),
          const Text('Flight Portrait Card', style: ThemeText.subtitle2),
          Row(
            children: [
              SizedBox(
                  width: 200,
                  child: FlightPortraitCard(
                      plane: planeList[0],
                      label: '20% OFF',
                      from: 'Jakarta',
                      to: 'Bandung',
                      date: '22 Nov 2026',
                      price: 100)),
            ],
          ),
          const VSpace(),
          const Text('Flight Route Card', style: ThemeText.subtitle2),
          FlightRouteCard(
            time: '22 Jun 2026',
            type: RouteType.arrival,
            airport: airportList[0],
          ),
          const VSpace(),
          const Text('News Card', style: ThemeText.subtitle2),
          Row(
            children: [
              SizedBox(
                  width: 200,
                  child: NewsCard(
                      thumb: ImgApi.photo[1],
                      title: 'News Title',
                      date: '11 Apr 2026')),
            ],
          ),
          const VSpace(),
          const Text('Pricing Card', style: ThemeText.subtitle2),
          PricingCard(
              mainIcon: Icon(Icons.discount,
                  size: 56, color: ThemePalette.primaryMain),
              color: ThemePalette.primaryMain,
              title: 'Best Value',
              price: 200,
              desc: 'Lorem ipsum dolor sit amet',
              features: const <String>[
                'Feature 1',
                'Feature 2',
                'Feature 3',
                'Feature 4',
                'Feature 5'
              ],
              enableIcons: const <bool>[
                true,
                true,
                true,
                false,
                false
              ]),
          const VSpace(),
          const Text('Profile Card', style: ThemeText.subtitle2),
          ProfileCard(avatar: ImgApi.avatar[3], name: 'Jean Doe', distance: 19),
          const VSpace(),
          const Text('Promo Card', style: ThemeText.subtitle2),
          PromoCard(
              thumb: ImgApi.photo[82],
              point: 20,
              time: '15 Aug 2025',
              title: 'Lorem ipsum dolor sit amet'),
          const VSpace(),
          const Text('Rating Card', style: ThemeText.subtitle2),
          RatingCard(
              name: 'John Doe',
              avatar: ImgApi.avatar[8],
              date: '22 May 2024',
              description: 'Fusce et sagittis risus, et condimentum libero. ',
              rating: 4),
          const VSpace(),
          const Text('Reward Card', style: ThemeText.subtitle2),
          Row(
            children: [
              SizedBox(
                  height: 250,
                  width: 200,
                  child: RewardCard(
                      image: ImgApi.photo[89],
                      logo: ImgApi.photo[96],
                      title: 'Reward Title',
                      subtitle:
                          'Fusce et sagittis risus, et condimentum libero.',
                      point: 200)),
            ],
          ),
          const VSpace(),
          const Text('Ticket Card', style: ThemeText.subtitle2),
          TicketCard(
            from: cityList[3],
            to: cityList[8],
            plane: planeList[5],
            price: 999,
            depart: DateTime.parse('2025-07-20 20:18:00'),
            arrival: DateTime.parse('2025-07-21 20:18:00'),
            transit: 1,
            status: BookStatus.active,
            timeLeft: '2 days 3 hours',
            bookingCode: 'CEN1J4',
          ),
          const VSpace(),
          const Text('Title Icon Card', style: ThemeText.subtitle2),
          const TitleIconCard(
              icon: Icons.settings,
              title: 'Title',
              content: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit'),
              )),
          const VSpace(),
          const Text('Voucher Card', style: ThemeText.subtitle2),
          SizedBox(
              height: 80,
              child: VoucherCard(
                  title: 'Title Voucher',
                  color: Colors.pink,
                  status: VoucherStatus.enable,
                  desc: 'Lorem ipsum dolor sit amet',
                  onSelected: (_) {},
                  isSelected: false)),
          const VSpaceBig(),
        ]));
  }
}
