import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// Category chip filter bar - Wego / Expedia style
class ExploreCategoryFilter extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const ExploreCategoryFilter({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const List<Map<String, dynamic>> categories = [
    {'label': 'All', 'icon': Icons.explore},
    {'label': 'Adventure', 'icon': Icons.terrain},
    {'label': 'Mountains', 'icon': Icons.filter_hdr},
    {'label': 'Beaches', 'icon': Icons.beach_access},
    {'label': 'Historical', 'icon': Icons.account_balance},
    {'label': 'Nature', 'icon': Icons.park},
    {'label': 'Cities', 'icon': Icons.location_city},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final cat = categories[i];
            final isActive = selected == cat['label'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(cat['label'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? TravelloTheme.primaryMain
                        : TravelloTheme.paperLightContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isActive
                          ? TravelloTheme.primaryMain
                          : colorScheme(context).outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 14,
                        color: isActive
                            ? Colors.black
                            : colorScheme(context)
                                .onSurface
                                .withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? Colors.black
                              : colorScheme(context).onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
