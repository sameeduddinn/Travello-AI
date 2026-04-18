import 'package:flutter/material.dart';
import 'package:flight_app/models/rewards_history.dart';
import 'package:flight_app/widgets/cards/activity_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TimelineActivities extends StatelessWidget {
  const TimelineActivities({super.key});

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 60;

    return ListView(padding: const EdgeInsets.all(4), children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('History', style: TravelloTheme.title2,)
      ),
      const VSpaceShort(),
      Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 24,
            child: Container(
              width: 3,
              height: itemHeight * pointHistory.length,
              decoration: BoxDecoration(
                color: colorScheme(context).outline,
                borderRadius: BorderRadius.circular(5)
              )
            ),
          ),
          ListView.builder(
            itemCount: pointHistory.length,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(0),
            itemBuilder: ((context, index) {
              Reward item = pointHistory[index];
              return ActivityCard(
                title: item.title,
                time: item.date,
                icon: item.icon,
                color: item.color,
                isHighlighted: item.isOut,
              );
            })
          )
        ],
      ),
    ]);
  }
}