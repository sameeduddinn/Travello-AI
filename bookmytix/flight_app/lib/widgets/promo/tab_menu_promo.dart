import 'package:flutter/material.dart';
import 'package:flight_app/widgets/tab_menu/menu.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TabMenuPromo extends StatelessWidget {
  const TabMenuPromo({super.key, required this.onSelect, required this.current});

  final Function(int) onSelect;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: TravelloTheme.paperLightContainerLowest,
      child: TabMenu(
        onSelect: onSelect,
        current: current,
        menus: const ['Promos', 'Vouchers']
      )
    );
  }
}