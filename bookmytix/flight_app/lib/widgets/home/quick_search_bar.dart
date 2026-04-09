import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class QuickSearchBar extends StatelessWidget {
  final String service;

  const QuickSearchBar({super.key, this.service = 'flight'});

  String get _searchPlaceholder {
    switch (service) {
      case 'train':
        return 'Search trains, destinations...';
      case 'hotel':
        return 'Search hotels, destinations...';
      case 'flight':
      default:
        return 'Search flights, destinations...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 800 : double.infinity,
        ),
        padding:
            EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
        child: GestureDetector(
          onTap: () {
            Get.toNamed(AppLink.searchList);
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: ThemeRadius.medium,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.search,
                  color: TravelloTheme.primaryMain,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _searchPlaceholder,
                    style: TravelloTheme.paragraph.copyWith(
                      color:
                          colorScheme(context).onSurface.withValues(alpha: 0.5),
                    ),
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
