import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/rating.dart';
import 'package:flight_app/widgets/cards/rating_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ReviewListSlider extends StatelessWidget {
  const ReviewListSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TitleAction(
          title: 'Reviews',
          textAction: 'See All Reviews',
          onTap: () {
            Get.toNamed('/ratings-reviews');
          }
        ),
      ),
      const VSpaceShort(),
      SizedBox(
        height: 150,
        child: ListView.builder(
          itemCount: ratingList.length,
          scrollDirection: Axis.horizontal,
          itemBuilder: ((context, index) {
            Rating item = ratingList[index];
            return Container(
              width: 300,
              padding: EdgeInsets.only(
                top: 4,
                bottom: 4,
                left: index > 0 ? 4 : 16,
                right: index < ratingList.length - 1 ? 4 : 16,
              ),
              child: RatingCard(
                avatar: item.avatar,
                name: item.name,
                date: item.date,
                description: item.description,
                rating: item.rating,
              ),
            );
          })
        ),
      )
    ]);
  }
}