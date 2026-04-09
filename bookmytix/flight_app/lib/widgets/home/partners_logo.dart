import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PartnersLogo extends StatelessWidget {
  const PartnersLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TitleBasic(
            title: 'Our Partners',
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          physics: const ClampingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ThemeBreakpoints.smUp(context) ? 6 : 4,
            crossAxisSpacing: ThemeBreakpoints.smUp(context) ? 24 : 16,
            mainAxisSpacing: ThemeBreakpoints.smUp(context) ? 24 : 16,
            childAspectRatio: 1,
          ),
          itemCount: 12, // Replace with the actual number of items
          itemBuilder: (context, index) {
            return Image.network(
              ImgApi.photo[95 + index],
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: TravelloTheme.paperLightContainerHighest,
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: TravelloTheme.paperLightContainerHighest,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: TravelloTheme.textMuted,
                  size: 20,
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
