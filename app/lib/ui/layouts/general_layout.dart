import 'package:flutter/material.dart';
import 'package:flight_app/utils/responsive_utils.dart';

class GeneralLayout extends StatelessWidget {
  const GeneralLayout({super.key, required this.content, this.isHome = false});

  final Widget content;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getMaxWidth(context), minHeight: 480),
        child: SafeArea(bottom: false, top: !isHome, child: content),
      ),
    ));
  }
}
