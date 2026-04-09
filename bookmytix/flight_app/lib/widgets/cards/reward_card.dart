import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.image,
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.point,
  });
  
  final String image;
  final String logo;
  final String title;
  final String subtitle;
  final int point;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.medium,
        color: TravelloTheme.primaryMainContainer
      ),
      child: Column(
        children: [
          Expanded(
            child: PaperCard(
              content: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    height: 100,
                    child: ClipRRect(
                      borderRadius: ThemeRadius.small,
                      child: Image.network(
                        image,
                        fit: BoxFit.cover,
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: double.infinity,
                            height: 100,
                            child: ShimmerPreloader()
                          );
                        },
                    )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(logo),
                      ),
                      const SizedBox(width: 4),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TravelloTheme.subtitle2),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TravelloTheme.paragraph)
                ]),
              )
            ),
          ),

          /// POINT AND ACTION BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$point Point', style: TravelloTheme.paragraph.copyWith(color: colorScheme(context).onPrimaryContainer, fontWeight: FontWeight.bold)),
              Icon(Icons.arrow_circle_right_outlined, color: colorScheme(context).onPrimaryContainer, size: 16)
            ]),
          )
        ],
      )
    );
  }
}