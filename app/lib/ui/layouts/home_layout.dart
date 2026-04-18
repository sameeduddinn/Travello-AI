import 'package:flutter/material.dart';
import 'package:flight_app/widgets/bottom_navigation/bottom_nav_menu.dart';
import 'package:flight_app/utils/responsive_utils.dart';

class HomeLayout extends StatelessWidget {
  const HomeLayout({super.key, required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxWidth(context), minHeight: 480),
          child: SafeArea(bottom: false, child: content),
        ),
      ),
      bottomNavigationBar: const BottomNavMenu(),
    );
  }
}
