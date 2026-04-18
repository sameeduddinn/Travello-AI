import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/city.dart';
import 'package:flight_app/utils/shimmer_preloader.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CityDestinationsList extends StatefulWidget {
  const CityDestinationsList({super.key});

  @override
  State<CityDestinationsList> createState() => _CityDestinationsListState();
}

class _CityDestinationsListState extends State<CityDestinationsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: spacingUnit(5)),
      decoration: const BoxDecoration(
          color: TravelloTheme.paperLightContainerLowest,
          borderRadius: ThemeRadius.medium),
      child: Column(
        children: [
          const TitleBasic(title: 'Popular Destinations'),
          const SizedBox(
            height: 16,
          ),
          LayoutBuilder(builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth;
            final cardSize =
                (viewportWidth * 0.62).clamp(180.0, 220.0).toDouble();
            final listHeight = cardSize + 40;
            final scrollStep = cardSize + 16;
            final showArrows = viewportWidth >= 760;

            return Stack(
              alignment: Alignment.center,
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: SizedBox(
                    height: listHeight,
                    child: ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: recomendedCityList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final item = recomendedCityList[index];
                          final String photoUrl =
                              item.photos.isNotEmpty ? item.photos.first : '';
                          return GestureDetector(
                              onTap: () {
                                Get.toNamed(AppLink.flightSearchHome,
                                    arguments: {
                                      'toCode': item.code,
                                      'toCity': item.name,
                                    });
                              },
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: cardSize,
                                      width: cardSize,
                                      decoration: BoxDecoration(
                                        borderRadius: ThemeRadius.medium,
                                        boxShadow: [
                                          ThemeShade.shadeMedium(context)
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: ThemeRadius.medium,
                                        child: Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (BuildContext context,
                                              Widget child,
                                              ImageChunkEvent?
                                                  loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return const SizedBox(
                                                width: double.infinity,
                                                height: 60,
                                                child: ShimmerPreloader());
                                          },
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: TravelloTheme
                                                .paperLightContainerHighest,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: TravelloTheme.textMuted,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TravelloTheme.subtitle.copyWith(
                                        fontSize: cardSize < 200 ? 16 : 18,
                                      ),
                                    )
                                  ]));
                        }),
                  ),
                ),
                if (showArrows)
                  Positioned(
                    left: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TravelloTheme.paperLight.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [ThemeShade.shadeMedium(context)],
                      ),
                      child: IconButton(
                        onPressed: () => _scrollBy(-scrollStep),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: TravelloTheme.primaryMain),
                      ),
                    ),
                  ),
                if (showArrows)
                  Positioned(
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TravelloTheme.paperLight.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [ThemeShade.shadeMedium(context)],
                      ),
                      child: IconButton(
                        onPressed: () => _scrollBy(scrollStep),
                        icon: const Icon(Icons.arrow_forward_ios,
                            color: TravelloTheme.primaryMain),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
