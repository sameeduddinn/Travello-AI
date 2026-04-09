import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_radius.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/custom_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:overlay_tooltip/overlay_tooltip.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class BottomNavMenu extends StatelessWidget {
  const BottomNavMenu({super.key});

  @override
  Widget build(BuildContext context) {
    String currentRoute = Get.currentRoute;

    return BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: 60,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.all(0),
        child: LayoutBuilder(builder: (context, constraints) {
          return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MenuItem(
                    title: 'Home',
                    icon: Icons.home,
                    isActive: currentRoute == AppLink.home,
                    onTap: () {
                      Get.toNamed(AppLink.home);
                    }),
                MenuItem(
                    title: 'Explore',
                    icon: CupertinoIcons.location_fill,
                    isActive: currentRoute == AppLink.explore,
                    onTap: () {
                      Get.toNamed(AppLink.explore);
                    }),
                MenuItem(
                    title: 'AI Assistant',
                    icon: Icons.psychology_outlined,
                    isActive: currentRoute == AppLink.aiAssistant,
                    onTap: () {
                      Get.toNamed(AppLink.aiAssistant);
                    }),
                OverlayTooltipItem(
                  displayIndex: 3,
                  tooltip: (controller) => Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: MTooltip(
                        title:
                            'Your scheduled booking tiket will be listed here.',
                        controller: controller),
                  ),
                  tooltipVerticalPosition: TooltipVerticalPosition.TOP,
                  tooltipHorizontalPosition: TooltipHorizontalPosition.CENTER,
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme(context).surface),
                    child: MenuItem(
                        title: 'My Booking',
                        icon: CupertinoIcons.tickets_fill,
                        isActive: currentRoute == AppLink.myTicket,
                        onTap: () {
                          Get.toNamed(AppLink.myTicket);
                        }),
                  ),
                ),
                MenuItem(
                    title: 'Profile',
                    icon: CupertinoIcons.person_fill,
                    isActive: currentRoute == AppLink.profile,
                    onTap: () => Get.toNamed(AppLink.profile)),
              ]);
        }));
  }
}

class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.isActive = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isActive;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ZoomTapAnimation(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => {onTap()},
        child: SizedBox(
          width: (MediaQuery.of(context).size.width / 5).clamp(48.0, 80.0),
          height: 50,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isActive
                        ? ThemePalette.primaryMain
                        : Theme.of(context).colorScheme.onSurface),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThemeText.caption),
                isActive
                    ? Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                            borderRadius: ThemeRadius.big,
                            color: ThemePalette.primaryMain),
                      )
                    : Container()
              ]),
        ),
      ),
    );
  }
}
