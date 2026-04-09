import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class NoData extends StatelessWidget {
  const NoData({
    super.key,
    required this.image,
    required this.title,
    required this.desc,
    this.primaryTxtBtn,
    this.secondaryTxtBtn,
    this.primaryAction,
    this.secondaryAction,
  });

  final String image;
  final String title;
  final String desc;
  final String? primaryTxtBtn;
  final String? secondaryTxtBtn;
  final Function()? primaryAction;
  final Function()? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: ThemeSize.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// ILLUSTRATION
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TravelloTheme.primaryMain.withValues(alpha: 0.15),
                    TravelloTheme.primaryLight.withValues(alpha: 0.30),
                  ],
                ),
                border: Border.all(
                  color: TravelloTheme.primaryMain.withValues(alpha: 0.20),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child:
                    SvgPicture.asset(image, height: 110, fit: BoxFit.contain),
              ),
            ),

            const SizedBox(height: 24),

            /// TITLE
            Text(
              title,
              textAlign: TextAlign.center,
              style: TravelloTheme.title.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: colorScheme(context).onSurface,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            /// DESCRIPTION
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                desc,
                textAlign: TextAlign.center,
                style: TravelloTheme.headline.copyWith(
                  color: colorScheme(context).onSurface.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 28),

            /// PRIMARY BUTTON
            if (primaryTxtBtn != null)
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: primaryAction,
                  style: ThemeButton.tonalPrimary(context).copyWith(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    elevation: WidgetStateProperty.all(0),
                  ),
                  child: Text(
                    primaryTxtBtn!,
                    style: TravelloTheme.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            if (primaryTxtBtn != null && secondaryTxtBtn != null)
              const SizedBox(height: 12),

            /// SECONDARY BUTTON
            if (secondaryTxtBtn != null)
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: secondaryAction,
                  style: ThemeButton.outlinedSecondary(context).copyWith(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    side: WidgetStateProperty.all(
                      BorderSide(
                        color: TravelloTheme.primaryMain.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    secondaryTxtBtn!,
                    style: TravelloTheme.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
