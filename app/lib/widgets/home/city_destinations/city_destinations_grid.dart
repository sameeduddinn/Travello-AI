import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CityDestinationsGrid extends StatelessWidget {
  const CityDestinationsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // Popular Pakistani destinations: Top 10 flight destinations
    final List<City> recomendedCityList = [
      cityList.firstWhere((city) => city.name == 'Skardu'),
      cityList.firstWhere((city) => city.name == 'Lahore'),
      cityList.firstWhere((city) => city.name == 'Karachi'),
      cityList.firstWhere((city) => city.name == 'Islamabad'),
      cityList.firstWhere((city) => city.name == 'Quetta'),
      cityList.firstWhere((city) => city.name == 'Gilgit'),
      cityList.firstWhere((city) => city.name == 'Peshawar'),
      cityList.firstWhere((city) => city.name == 'Multan'),
      cityList.firstWhere((city) => city.name == 'Faisalabad'),
      cityList.firstWhere((city) => city.name == 'Sialkot'),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final horizontalPadding = width > 1200 ? spacingUnit(8) : 16.0;
      final spacing = width > 1200 ? 16.0 : 8.0;
      final gridWidth =
          (width - (horizontalPadding * 2)).clamp(0.0, width).toDouble();
      final targetTileWidth = width > 1200
          ? 96.0
          : width > 900
              ? 90.0
              : width > 600
                  ? 84.0
                  : 76.0;
      final crossAxisCount = (gridWidth / targetTileWidth).floor().clamp(3, 7);
      final childAspectRatio = width > 900
          ? 0.85
          : width > 600
              ? 0.8
              : 0.75;
      final imageSize = width > 1200
          ? 64.0
          : width > 600
              ? 60.0
              : 56.0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: const BoxDecoration(
            color: TravelloTheme.paperLightContainerLowest,
            borderRadius: ThemeRadius.medium),
        child: Column(
          children: [
            const TitleBasic(title: 'Popular Destinations'),
            const SizedBox(
              height: 16,
            ),
            GridView.builder(
                padding: const EdgeInsets.all(0),
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: recomendedCityList.length,
                itemBuilder: (context, index) {
                  final City item = recomendedCityList[index];
                  final String photoUrl =
                      item.photos.isNotEmpty ? item.photos.first : '';
                  return GestureDetector(
                      onTap: () {
                        Get.toNamed(AppLink.flightSearchHome, arguments: {
                          'toCode': item.code,
                          'toCity': item.name,
                        });
                      },
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              height: imageSize,
                              width: imageSize,
                              decoration: BoxDecoration(
                                borderRadius: ThemeRadius.medium,
                                boxShadow: [ThemeShade.shadeMedium(context)],
                              ),
                              child: ClipRRect(
                                borderRadius: ThemeRadius.medium,
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: ShimmerPreloader());
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    color: TravelloTheme
                                        .paperLightContainerHighest,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: TravelloTheme.textMuted,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(item.name,
                                overflow: TextOverflow.ellipsis,
                                style: TravelloTheme.paragraph)
                          ]));
                }),
          ],
        ),
      );
    });
  }
}
