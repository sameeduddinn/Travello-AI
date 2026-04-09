import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';

class TravelModeSelection extends StatelessWidget {
  const TravelModeSelection({super.key});

  Future<void> _selectMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('travel_mode', mode);
    Get.offAllNamed(AppLink.home); // Navigate to home with selected mode
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme(context).primary,
              colorScheme(context).secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacingUnit(3)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Choose Your Travel Mode',
                  style: ThemeText.title.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacingUnit(1)),
                Text(
                  'Select how you prefer to travel',
                  style: ThemeText.subtitle.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacingUnit(6)),

                // Airline Mode Card
                _ModeCard(
                  icon: Icons.flight,
                  title: 'Airline Mode',
                  description: 'Book flights across Pakistan',
                  gradient: [Colors.blue.shade700, Colors.blue.shade400],
                  onTap: () => _selectMode('airline'),
                ),

                SizedBox(height: spacingUnit(3)),

                // Railway Mode Card
                _ModeCard(
                  icon: Icons.train,
                  title: 'Railway Mode',
                  description: 'Book train tickets nationwide',
                  gradient: [Colors.green.shade700, Colors.green.shade400],
                  onTap: () => _selectMode('railway'),
                ),

                SizedBox(height: spacingUnit(4)),

                // Info Text
                Container(
                  padding: EdgeInsets.all(spacingUnit(2)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      SizedBox(width: spacingUnit(1)),
                      Expanded(
                        child: Text(
                          'You can switch modes anytime from settings',
                          style: ThemeText.caption.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(spacingUnit(3)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(spacingUnit(2)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
            ),
            SizedBox(width: spacingUnit(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ThemeText.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: spacingUnit(0.5)),
                  Text(
                    description,
                    style: ThemeText.subtitle.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
