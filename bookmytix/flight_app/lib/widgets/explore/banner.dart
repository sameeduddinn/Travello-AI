import 'package:flight_app/constants/image_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart' as svg_img;
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
            color:
                isDark ? TravelloTheme.primaryDark : TravelloTheme.primaryLight),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
                image: isDark
                    ? svg_img.Svg(ImgApi.bgCloudDark)
                    : svg_img.Svg(ImgApi.bgCloud),
                fit: BoxFit.contain,
                alignment: Alignment.center,
                colorFilter: isDark
                    ? ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5), BlendMode.srcIn)
                    : null),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              /// TEXT TITLE
              Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    top: 80,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Explore the most beautiful places around Pakistan',
                        style: TravelloTheme.title2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        branding.desc,
                        style: TravelloTheme.subtitle.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.4,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )),

              /// BANNER WITH ILLUSTRATION
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
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
        ));
  }
}
