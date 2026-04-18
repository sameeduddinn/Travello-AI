import 'package:flutter/material.dart';
import 'package:flight_app/widgets/review/rating_star.dart';
import 'package:flight_app/widgets/review/review_form.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ReviewButton extends StatelessWidget {
  const ReviewButton({super.key, this.reviewed = false});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    return reviewed
        ? GestureDetector(
            onTap: () {
              showModalBottomSheet<dynamic>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext context) {
                    return const Wrap(children: [ReviewForm()]);
                  });
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: ThemeRadius.medium,
                  border: Border.all(
                      width: 1, color: colorScheme(context).outline)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Review',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RatingStar(initVal: 5),
                          Text('2 day ago', style: TravelloTheme.caption)
                        ]),
                    SizedBox(height: 4),
                    Text(
                        'Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae',
                        textAlign: TextAlign.start,
                        style: TravelloTheme.paragraph)
                  ]),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Write your review and get 10 coins'),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                    onPressed: () {
                      showModalBottomSheet<dynamic>(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) {
                            return const Wrap(children: [ReviewForm()]);
                          });
                    },
                    style: ThemeButton.outlinedPrimary(context),
                    child: const Row(children: [
                      Icon(Icons.edit_note_rounded),
                      SizedBox(width: 4),
                      Text(
                        'Write Review',
                      )
                    ])),
              ),
            ]),
          );
  }
}
