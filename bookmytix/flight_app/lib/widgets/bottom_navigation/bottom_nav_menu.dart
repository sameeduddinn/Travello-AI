import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/custom_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:overlay_tooltip/overlay_tooltip.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class BottomNavMenu extends StatelessWidget {
  const BottomNavMenu({super.key});

  @override
  Widget build(BuildContext context) {
    String currentRoute = Get.currentRoute;
    final bool hasTooltipScaffold =
        context.findAncestorWidgetOfExactType<OverlayTooltipScaffold>() != null;

    return BottomAppBar(
        elevation: 20,
        shadowColor: Colors.black,
        height: 60,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.all(0),
        child: LayoutBuilder(builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth / 5).clamp(44.0, 96.0);
          final isCompact = itemWidth < 74;
          final isVeryCompact = itemWidth < 62;

          final bookingLabel = isVeryCompact
              ? 'Book'
              : isCompact
                  ? 'Booking'
                  : 'My Booking';
          final aiLabel = itemWidth < 76 ? 'AI' : 'AI Assistant';

          final Widget myBookingButton = Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: TravelloTheme.paperLight,
            ),
            child: MenuItem(
              title: bookingLabel,
              icon: CupertinoIcons.tickets_fill,
              compact: isCompact,
              veryCompact: isVeryCompact,
              itemWidth: itemWidth,
              isActive: currentRoute == AppLink.myTicket,
              onTap: () {
                Get.toNamed(AppLink.myTicket);
              },
            ),
          );

          return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MenuItem(
                    title: 'Home',
                    icon: Icons.home,
                    compact: isCompact,
                    veryCompact: isVeryCompact,
                    itemWidth: itemWidth,
                    isActive: currentRoute == AppLink.home,
                    onTap: () {
                      Get.toNamed(AppLink.home);
                    }),
                MenuItem(
                    title: 'Explore',
                    icon: CupertinoIcons.location_fill,
                    compact: isCompact,
                    veryCompact: isVeryCompact,
                    itemWidth: itemWidth,
                    isActive: currentRoute == AppLink.explore,
                    onTap: () {
                      Get.toNamed(AppLink.explore);
                    }),
                MenuItem(
                    title: aiLabel,
                    icon: Icons.smart_toy_outlined,
                    iconWidget: _buildAiNavIcon(
                      isActive: currentRoute == AppLink.aiAssistant,
                      size: isVeryCompact ? 19 : isCompact ? 21 : 24,
                      context: context,
                    ),
                    compact: isCompact,
                    veryCompact: isVeryCompact,
                    itemWidth: itemWidth,
                    isActive: currentRoute == AppLink.aiAssistant,
                    onTap: () {
                      Get.toNamed(AppLink.aiAssistant);
                    }),
                hasTooltipScaffold
                    ? OverlayTooltipItem(
                        displayIndex: 3,
                        tooltip: (controller) => Padding(
                          padding: const EdgeInsets.only(right: 15),
                          child: MTooltip(
                            title:
                                'Your scheduled booking tiket will be listed here.',
                            controller: controller,
                          ),
                        ),
                        tooltipVerticalPosition: TooltipVerticalPosition.TOP,
                        tooltipHorizontalPosition:
                            TooltipHorizontalPosition.CENTER,
                        child: myBookingButton,
                      )
                    : myBookingButton,
                MenuItem(
                    title: 'Profile',
                    icon: CupertinoIcons.person_fill,
                    compact: isCompact,
                    veryCompact: isVeryCompact,
                    itemWidth: itemWidth,
                    isActive: currentRoute == AppLink.profile,
                    onTap: () => Get.toNamed(AppLink.profile)),
              ]);
        }));
  }
}

Widget _buildAiNavIcon({
  required bool isActive,
  required double size,
  required BuildContext context,
}) {
  final color = isActive
      ? TravelloTheme.primaryMain
      : Theme.of(context).colorScheme.onSurface;
  return SizedBox(
    width: size + 8,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Center(child: Icon(Icons.smart_toy_outlined, size: size, color: color)),
        Positioned(
          top: -3,
          right: -1,
          child: Icon(Icons.auto_awesome,
              size: size * 0.4,
              color: isActive ? TravelloTheme.primaryMain : Colors.grey),
        ),
      ],
    ),
  );
}

class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.icon,
    this.iconWidget,
    required this.title,
    this.compact = false,
    this.veryCompact = false,
    this.itemWidth = 64,
    this.isActive = false,
    required this.onTap,
  });

  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final bool compact;
  final bool veryCompact;
  final double itemWidth;
  final bool isActive;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ZoomTapAnimation(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => {onTap()},
        child: SizedBox(
          width: itemWidth,
          height: 50,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconWidget ??
                    Icon(icon,
                        size: veryCompact
                            ? 19
                            : compact
                                ? 21
                                : 24,
                        color: isActive
                            ? TravelloTheme.primaryMain
                            : Theme.of(context).colorScheme.onSurface),
                Text(title,
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TravelloTheme.caption.copyWith(
                      fontSize: veryCompact
                          ? 8.5
                          : compact
                              ? 10
                              : 12,
                      height: 1.1,
                    )),
                isActive
                    ? Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: const BoxDecoration(
                            borderRadius: ThemeRadius.big,
                            color: TravelloTheme.primaryMain),
                      )
                    : const SizedBox.shrink()
              ]),
        ),
      ),
    );
  }
}
