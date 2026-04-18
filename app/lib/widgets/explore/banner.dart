import 'package:flight_app/constants/image_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/widgets/decorations/rounded_deco_main.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class BannerExplore extends StatelessWidget {
  const BannerExplore({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.isDarkMode;

    return Container(
        decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFBF9B30), // deeper gold top
                      TravelloTheme.primaryLight, // lighter gold bottom
                    ],
                  ),
            color: isDark ? TravelloTheme.primaryDark : null),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              /// TEXT TITLE (above clouds — clean background)
              Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 12,
                    top: 72,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore the most beautiful places around Pakistan',
                        style: TravelloTheme.title2.copyWith(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        branding.desc,
                        style: TravelloTheme.paragraph.copyWith(
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )),

              /// CLOUDS + LANDMARKS ILLUSTRATION
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Cloud SVG behind landmarks
                  Positioned.fill(
                    child: SvgPicture.asset(
                      isDark ? ImgApi.bgCloudDark : ImgApi.bgCloud,
                      fit: BoxFit.cover,
                      colorFilter: isDark
                          ? ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.5),
                              BlendMode.srcIn)
                          : null,
                    ),
                  ),
                  const Positioned(
                      bottom: 0,
                      left: 0,
                      child: RoundedDecoMain(
                        height: 100,
                        bgDecoration: BoxDecoration(
                            color: TravelloTheme.paperLightContainerLowest),
                      )),
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SvgPicture.asset(ImgApi.bgPakistanLandmarks,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                              TravelloTheme.primaryMain, BlendMode.srcIn)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
  }
}
