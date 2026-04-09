import 'package:flight_app/widgets/profile/timeline_activities.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class DetailPoint extends StatelessWidget {
  const DetailPoint({super.key});

  @override
  Widget build(BuildContext context) {

    final ButtonStyle iconBtn = IconButton.styleFrom(
      backgroundColor: TravelloTheme.paperLight,
      shadowColor: Colors.grey.withValues(alpha: 0.5),
      elevation: 3
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          style: iconBtn,
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
        ),
        title: Text('Your Points', style: TravelloTheme.subtitle.copyWith(color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.only(top: spacingUnit(7)),
        decoration: const BoxDecoration(
          color: TravelloTheme.primaryMain,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.stars, color: Colors.white.withValues(alpha: 0.5), size: 40),
            const SizedBox(width: 8),
            Text('3000', style: TravelloTheme.title.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          const VSpaceShort(),
          /// HISTORY
          Expanded(child: 
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                )
              ),
              child: const TimelineActivities()
            )
          )
        ],),
      )
    );
  }
}