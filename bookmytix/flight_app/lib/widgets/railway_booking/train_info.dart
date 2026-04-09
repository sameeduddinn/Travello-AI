import 'package:flight_app/models/train.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TrainInfo extends StatelessWidget {
  const TrainInfo({super.key, required this.train});

  final Train train;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(
          Icons.train,
          color: TravelloTheme.primaryMain,
          size: 24,
        ),
        const SizedBox(
          width: 8,
        ),
        Text(train.name,
            style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(train.trainNumber, style: TravelloTheme.paragraph),
        const SizedBox(
          width: 8,
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
              borderRadius: ThemeRadius.xsmall,
              color: TravelloTheme.primaryMainContainer),
          child: Text(train.trainClass, style: TravelloTheme.caption),
        )
      ]),
    );
  }
}
