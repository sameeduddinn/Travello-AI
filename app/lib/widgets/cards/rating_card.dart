import 'package:flutter/material.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class RatingCard extends StatelessWidget {
  const RatingCard({
    super.key,
    required this.name,
    required this.avatar,
    required this.date,
    required this.description,
    required this.rating,
    this.overflowDesc = true
  });

  final String name;
  final String avatar;
  final String date;
  final String description;
  final int rating;
  final bool overflowDesc;

  @override
  Widget build(BuildContext context) {

    return PaperCard(
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          /// NAME
          Row(children: [
            CircleAvatar(
              radius: 10,
              backgroundImage: NetworkImage(avatar),
            ),
            const SizedBox(width: 8),
            Text(name, style: TravelloTheme.subtitle2),
          ]),
          

          /// DESCRIPTION
          Text(description, style: TravelloTheme.paragraph, maxLines: overflowDesc ? 2 : null, overflow: TextOverflow.ellipsis,)
        ]),
      )
    );
  }
}