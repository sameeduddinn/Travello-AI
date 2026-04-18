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

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: IconButton(
                  onPressed: () => Get.toNamed(AppLink.notification),
                  style: iconBtn,
                  icon: Obx(() {
                    final ctrl = Get.find<NotificationController>();
                    final n = ctrl.unreadCount.value;
                    return Badge.count(
                      backgroundColor: TravelloTheme.primaryMain,
                      textColor: Colors.black,
                      count: n,
                      isLabelVisible: n > 0,
                      child: const Icon(Icons.notifications_outlined,
                          size: 20, color: TravelloTheme.textPrimary),
                    );
                  })),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              height: 38,
              child: IconButton(
                  onPressed: () => Get.toNamed(AppLink.faq),
                  style: iconBtn,
                  icon: const Icon(Icons.help_outline,
                      size: 20, color: TravelloTheme.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
