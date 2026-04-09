import 'package:flutter/material.dart';
import 'package:change_case/change_case.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.thumb,
    this.liked = false,
    required this.point,
    required this.time,
    required this.title,
    this.onTap,
  });

  final String thumb;
  final bool liked;
  final double point;
  final String time;
  final String title;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(alignment: Alignment.topRight, children: [
          /// HERO THUMB
          ClipRRect(
            borderRadius: ThemeRadius.small,
            child: Image.network(
              thumb,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: ShimmerPreloader()
                );
              },
            ),
          ),
          liked ? Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: TravelloTheme.paperLight,
              child: Icon(Icons.favorite, size: 16, color: TravelloTheme.tertiaryMain),
            ),
          ) : Container(),
        ]),

        /// EVENT PROPERTIES
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMainContainer,
                borderRadius: ThemeRadius.medium
              ),
              child: Text('$point POINT', style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold))
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme(context).onSurface,
                borderRadius: ThemeRadius.medium
              ),
              child: Row(children: [
                const Icon(Icons.access_time_outlined, size: 12, color: TravelloTheme.paperLight),
                const SizedBox(width: 2),
                Text(time, style: TravelloTheme.caption.copyWith(color: TravelloTheme.paperLight)),
              ],)
            ),
          ]),
        ),
        /// EVENT TITLE
        SizedBox(
          height: 60,
          child: Text(
            title.toCapitalCase(),
            style: TravelloTheme.subtitle2,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          )
        ),
      ]),
    );
  }
}