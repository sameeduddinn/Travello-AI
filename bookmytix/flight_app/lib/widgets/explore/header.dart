import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HeaderExplore extends StatelessWidget {
  const HeaderExplore({super.key});

  @override
  Widget build(BuildContext context) {
    final ButtonStyle iconBtn = IconButton.styleFrom(
        padding: const EdgeInsets.all(0),
        backgroundColor: TravelloTheme.paperLight,
        shadowColor: Colors.grey.withValues(alpha: 0.5),
        elevation: 3);

    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          /// ACTIONS HEADER BUTTON
          Row(children: [
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                  onPressed: () {
                    Get.toNamed(AppLink.notification);
                  },
                  style: iconBtn,
                  icon: Obx(() {
                    final ctrl = Get.find<NotificationController>();
                    final n = ctrl.unreadCount.value;
                    return Badge.count(
                      backgroundColor: TravelloTheme.primaryMain,
                      textColor: Colors.black,
                      count: n,
                      isLabelVisible: n > 0,
                      child: Icon(Icons.notifications,
                          size: 24, color: colorScheme(context).onSurface),
                    );
                  })),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                  onPressed: () {
                    Get.toNamed(AppLink.faq);
                  },
                  style: iconBtn,
                  icon: Icon(Icons.help,
                      size: 24, color: colorScheme(context).onSurface)),
            )
          ])
        ],
      ),
    );
  }
}
