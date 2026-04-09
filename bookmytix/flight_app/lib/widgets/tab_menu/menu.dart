import 'package:flutter/material.dart';
import 'package:flight_app/widgets/tab_menu/button_tab.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TabMenu extends StatelessWidget {
  const TabMenu({
    super.key,
    required this.onSelect,
    required this.current,
    required this.menus,
  });

  final Function(int) onSelect;
  final int current;
  final List<String> menus; 

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      width: MediaQuery.of(context).size.width.clamp(0.0, 600.0),
      height: 40,
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        boxShadow: [ThemeShade.shadeSoft(context)],
        borderRadius: ThemeRadius.medium,
        border: Border.all(
          width: 1,
          color: TravelloTheme.paperLightDim
        )
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: menus.asMap().entries.map((entry) {
          String item = entry.value;
          int index = entry.key;

          return Expanded(
            flex: 1,
            child: ButtonTab(
              isSelected: current == index,
              text: item,
              onSelect: () => onSelect(index)
            ),
          );
        }).toList()
      ),
    );
  }
}