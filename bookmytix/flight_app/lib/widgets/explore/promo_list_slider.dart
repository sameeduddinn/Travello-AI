import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/cards/promo_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/models/promo.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PromoListSlider extends StatelessWidget {
  const PromoListSlider({super.key});

  @override
  Widget build(BuildContext context) {
    const double cardHeight = 300;
    final List<Promotion> promos = [
      promoList[7],
      promoList[8],
      promoList[9],
      promoList[10],
      promoList[11],
      promoList[12],
    ];
  
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TitleAction(
          title: 'The Latest Promos',
          desc: 'Check out the latest promos just for you',
          textAction: 'See All',
          onTap: () {
            Get.toNamed(AppLink.promo);
          }
        ),
      ),
      const VSpaceShort(),
      SizedBox(
        height: cardHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: promos.length,
          itemBuilder: ((context, index) {
            Promotion item = promos[index];
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 4 : 0),
              child: Column(children: [
                SizedBox(width: 300, height: cardHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () {
                        Get.toNamed(AppLink.promoDetail);
                      },
                      child: PromoCard(
                        thumb: item.thumb,
                        title: item.name,
                        liked: false,
                        point: item.price,
                        time: item.date,
                      ),
                    ),
                  )
                ),
              ]),
            );
          }),
        ),
      )
    ]);
  }
}