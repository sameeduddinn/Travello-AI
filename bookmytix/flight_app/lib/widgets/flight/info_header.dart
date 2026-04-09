import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class InfoHeader extends StatelessWidget {
  const InfoHeader({
    super.key,
    this.roundTrip = false,
    required this.date,
    required this.from,
    required this.to,
    required this.passengers,
    this.withEdit = true,
  });

  final bool roundTrip;
  final String date;
  final String from;
  final String to;
  final int passengers;
  final bool withEdit;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      forceMaterialTransparency: true,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () {
          Get.back();
        },
      ),
      titleSpacing: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(from, style: TravelloTheme.headline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: roundTrip ? const Icon(CupertinoIcons.arrow_right_arrow_left, size: 14) : const Icon(CupertinoIcons.arrow_right, size: 14),
          ),
          Text(to, style: TravelloTheme.headline),
          const SizedBox(width: 8,),
          Text(passengers.toString(), style: TravelloTheme.headline.copyWith(color: colorScheme(context).onSurfaceVariant)),
          Icon(Icons.person_outline, size: 16, color: colorScheme(context).onSurfaceVariant),
        ]),
        Text(date, style: TravelloTheme.caption.copyWith(color: colorScheme(context).onSurfaceVariant),)
      ]),
      actions: <Widget>[
        withEdit ? IconButton(
          icon: const Icon(Icons.edit_note_outlined, size: 32),
          onPressed: () {
            Get.toNamed('/search-flight');
          },
        ) : const SizedBox(width: 20,),
      ],
    );
  }
}