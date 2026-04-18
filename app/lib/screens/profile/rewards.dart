import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/profile/reward_list.dart';
import 'package:flight_app/widgets/profile/tag_fliter_reward.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/cards/point_card.dart';
import 'package:flight_app/widgets/notifications/notif_block.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class Rewards extends StatelessWidget {
  const Rewards({super.key});

  @override
  Widget build(BuildContext context) {
    const Color gold = Colors.amber;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        })
      ),
      body: Container(
        padding: EdgeInsets.only(top: spacingUnit(7)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: <Color>[lighten(gold, 0.2), darken(gold, 0.2)]
          )
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wallet_giftcard, color: Colors.white, size: 24),
              const SizedBox(width: 4),
              Text('Youre in Gold Member', style: TravelloTheme.title2.copyWith(color: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PointCard(
              color: gold,
              title: 'Points'.toUpperCase(),
              progress: 30,
              btnText: 'History',
              onTap: () {
                Get.toNamed(AppLink.detailPoint);
              },
            )
          ),
          /// INFORMATION
          Expanded(child: 
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                )
              ),
              child: ListView(padding: const EdgeInsets.all(0), children: const [
                VSpaceShort(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Redeem your point with for exciting rewards', textAlign: TextAlign.center, style: TravelloTheme.subtitle,),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: NotifBlock(type: 'info', title: 'Information', subtitle: 'Lorem ipsum dolor sit amet consectetur adipiscing elit'),
                ),
                TagFilterReward(),
                RewardList()
              ]),
            )
          )
        ],),
      )
    );
  }
}