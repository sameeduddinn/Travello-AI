import 'package:flutter/widgets.dart';
import 'package:flight_app/models/rating.dart';
import 'package:flight_app/widgets/cards/rating_card.dart';

class ReviewList extends StatelessWidget {
  const ReviewList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      itemCount: ratingList.length,
      itemBuilder: ((context, index) {
        Rating item = ratingList[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RatingCard(
            avatar: item.avatar,
            name: item.name,
            date: item.date,
            description: item.description,
            rating: item.rating,
          ),
        );
      })
    );
  }
}