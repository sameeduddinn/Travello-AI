import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/models/promo.dart';
import 'package:flight_app/widgets/cards/promo_card.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PromoList extends StatelessWidget {
  const PromoList({super.key, required this.items, this.isHome = false});

  final List<Promotion> items;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: isHome ? 100 : 8),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        Promotion item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PromoCard(
            thumb: item.thumb,
            title: item.name,
            liked: false,
            point: item.price,
            time: item.date,
            onTap: () {
              Get.toNamed(AppLink.promoDetail);
            },
          ),
        );
      },
    );
  }
}