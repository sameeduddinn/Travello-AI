import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

List<Widget> homeActionGroup(BuildContext context, bool isFixed) {
  return [
    Obx(() {
      final ctrl = Get.find<NotificationController>();
      final n = ctrl.unreadCount.value;
      return Badge.count(
        backgroundColor: TravelloTheme.primaryMain,
        textColor: Colors.black,
        count: n,
        isLabelVisible: n > 0,
        offset: const Offset(0, -1),
        child: iconBtn(
          context,
          Icons.notifications,
          isFixed,
          () {
            Get.toNamed(AppLink.notification);
          },
        ),
      );
    }),
    const SizedBox(width: 6),
    iconBtn(
      context,
      Icons.help,
      isFixed,
      () {
        Get.toNamed(AppLink.faq);
      },
    )
  ];
}

Widget iconBtn(
    BuildContext context, IconData icon, bool isFixed, void Function() onTap) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          color: isFixed
              ? colorScheme(context).outline
              : TravelloTheme.paperLight),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 24,
          color: colorScheme(context).onSurface,
        ),
      ),
    ),
  );
}
