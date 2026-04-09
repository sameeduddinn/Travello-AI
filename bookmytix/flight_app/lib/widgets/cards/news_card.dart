import 'package:change_case/change_case.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.thumb, required this.title, required this.date});

  final String thumb;
  final String title;
  final String date;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      content: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: ThemeRadius.small,
            child: Image.network(
              thumb,
              width: double.infinity,
              height: 80,
              fit: BoxFit.cover,
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ShimmerPreloader()
                );
              },
            )
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              date,
              style: TravelloTheme.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)
            ),
          ),
          Text(
            title.toCapitalCase(),
            style: TravelloTheme.paragraph,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ]),
      )
    );
  }
}