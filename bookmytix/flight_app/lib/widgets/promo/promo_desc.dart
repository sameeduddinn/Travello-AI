import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/image_viewer.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PromoDesc extends StatelessWidget {
  const PromoDesc({
    super.key,
    required this.title,
    required this.desc,
    required this.thumb,
    required this.terms1,
    required this.terms2,
    required this.terms3,
    required this.date,
    required this.point,
    required this.liked
  });

  final String title;
  final String desc;
  final String thumb;
  final String terms1;
  final String terms2;
  final String terms3;
  final String date;
  final double point;
  final bool liked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            /// EVENT TITLE
            Expanded(child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TravelloTheme.title2.copyWith(fontWeight: FontWeight.bold))
            ),
            const SizedBox(width: 8),

            /// TIME REMAINING
            Container(
              width: 120,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: ThemeRadius.medium
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.access_time_outlined, size: 15, color: Colors.white),
                const SizedBox(width: 2),
                Text(date, style: TravelloTheme.paragraph.copyWith(color: Colors.white)),
              ],)
            ),
          ]),
        ),

        /// THUMBNAIL HERO
        Hero(
          tag: thumb,
          child: GestureDetector(
            onTap: () {
              Get.to(() => ImageViewer(img: thumb));
            },
            child: ClipRRect(
              borderRadius: ThemeRadius.medium,
              child: Image.network(
                thumb,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: ShimmerPreloader()
                  );
                },
              ),
            ),
          )
        ),

        /// DESCRIPTION AND termsS
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc, style: TravelloTheme.paragraph),
            const SizedBox(height: 16),
            Text('Terms of use:', style: TravelloTheme.subtitle2.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('1. $terms1', style: TravelloTheme.paragraph),
            const SizedBox(height: 8),
            Text('2. $terms2', style: TravelloTheme.paragraph),
            const SizedBox(height: 8),
            Text('3. $terms3', style: TravelloTheme.paragraph),
          ]),
        )
      ]),
    );
  }
}