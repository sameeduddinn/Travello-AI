import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/booking.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/cards/airport_card.dart';
import 'package:flight_app/widgets/cards/flight_card.dart';
import 'package:flight_app/widgets/cards/flight_portrait_card.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flight_app/widgets/cards/pricing_card.dart';
import 'package:flight_app/widgets/cards/profile_card.dart';
import 'package:flight_app/widgets/cards/promo_card.dart';
import 'package:flight_app/widgets/cards/ticket_card.dart';
import 'package:flight_app/widgets/cards/title_icon_card.dart';
import 'package:flight_app/widgets/cards/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CardCollection extends StatelessWidget {
  const CardCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Card Collection',
            style: TravelloTheme.subtitle,
          ),
          centerTitle: true,
          leading: BackIconButton(onTap: () {
            Get.back();
          }),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Airport Card', style: TravelloTheme.subtitle2),
          const AirportCard(
              name: 'Soekarno-Hatta', code: 'JKT', location: 'Jakarta'),
          const VSpace(),
          const Text('Flight Card', style: TravelloTheme.subtitle2),
          FlightCard(
              from: cityList[0],
              to: cityList[2],
              plane: planeList[4],
              price: 2000,
              depart: DateTime.parse('2025-07-20 20:18:00'),
              arrival: DateTime.parse('2025-07-21 20:18:00'),
              transit: 1),
          const VSpace(),
          const Text('Flight Portrait Card', style: TravelloTheme.subtitle2),
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
          const Text('Flight Route Card', style: TravelloTheme.subtitle2),
          FlightRouteCard(
            time: '22 Jun 2026',
            type: RouteType.arrival,
            airport: airportList[0],
          ),
          const VSpace(),
          const Text('Pricing Card', style: TravelloTheme.subtitle2),
          const PricingCard(
              mainIcon: Icon(Icons.discount,
                  size: 56, color: TravelloTheme.primaryMain),
              color: TravelloTheme.primaryMain,
              title: 'Best Value',
              price: 200,
              desc: 'Lorem ipsum dolor sit amet',
              features: <String>[
                'Feature 1',
                'Feature 2',
                'Feature 3',
                'Feature 4',
                'Feature 5'
              ],
              enableIcons: <bool>[
                true,
                true,
                true,
                false,
                false
              ]),
          const VSpace(),
          const Text('Profile Card', style: TravelloTheme.subtitle2),
          ProfileCard(avatar: ImgApi.avatar[3], name: 'Jean Doe', distance: 19),
          const VSpace(),
          const Text('Promo Card', style: TravelloTheme.subtitle2),
          PromoCard(
              thumb: ImgApi.photo[82],
              point: 20,
              time: '15 Aug 2025',
              title: 'Lorem ipsum dolor sit amet'),
          const VSpace(),
          const Text('Ticket Card', style: TravelloTheme.subtitle2),
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
          const Text('Title Icon Card', style: TravelloTheme.subtitle2),
          const TitleIconCard(
              icon: Icons.settings,
              title: 'Title',
              content: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit'),
              )),
          const VSpace(),
          const Text('Voucher Card', style: TravelloTheme.subtitle2),
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
