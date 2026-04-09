import 'package:flutter/material.dart';
import 'package:flight_app/widgets/decorations/dashed_border.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CutDeco extends StatelessWidget {
  const CutDeco({super.key, this.color, this.radius = 12});

  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cutDeco(context, false),
          Expanded(child: DashedBorder(color: color)),
          _cutDeco(context, true),
        ],
      ),
    );
  }

  Widget _cutDeco(BuildContext context, bool isLast) {
    final bool isDark = Get.isDarkMode;
    final Color cardColor = isDark
        ? colorScheme(context).outline
        : TravelloTheme.primaryMainContainer;

    return Container(
      width: radius / 2,
      height: radius,
      decoration: BoxDecoration(
          color: color != null
              ? color!
              : TravelloTheme.paperLightContainerLowest,
          border: Border(
            top:
                BorderSide(color: color != null ? color! : cardColor, width: 1),
            bottom:
                BorderSide(color: color != null ? color! : cardColor, width: 1),
            right: BorderSide(
                color: color != null ? color! : cardColor,
                width: 1,
                style: isLast ? BorderStyle.none : BorderStyle.solid),
            left: BorderSide(
                color: color != null ? color! : cardColor,
                width: 1,
                style: isLast ? BorderStyle.solid : BorderStyle.none),
          ),
          borderRadius: BorderRadius.only(
            topRight:
                isLast ? const Radius.circular(0) : Radius.circular(radius),
            bottomRight:
                isLast ? const Radius.circular(0) : Radius.circular(radius),
            topLeft:
                isLast ? Radius.circular(radius) : const Radius.circular(0),
            bottomLeft:
                isLast ? Radius.circular(radius) : const Radius.circular(0),
          )),
    );
  }
}
