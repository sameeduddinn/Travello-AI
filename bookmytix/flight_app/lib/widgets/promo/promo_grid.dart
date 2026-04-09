import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/models/promo.dart';
import 'package:flight_app/widgets/cards/promo_card.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PromoGrid extends StatelessWidget {
  const PromoGrid({super.key, required this.items, this.isHome = false});

  final List<Promotion> items;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: isHome ? 100 : 8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        mainAxisExtent: 300,
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
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