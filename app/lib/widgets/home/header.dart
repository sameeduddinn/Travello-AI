import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/utils/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/widgets/action_headers/home_action_group.dart';
import 'package:overlay_tooltip/overlay_tooltip.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, this.isFixed = false});

  final bool isFixed;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String _userName = 'User';
  String _userAvatar = '';
  String _userCountry = 'Pakistan';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data whenever widget rebuilds (e.g., after login)
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Check if in guest mode first
    final isGuest = await AuthService.isGuestMode();

    if (isGuest) {
      // Show guest user data
      final guestUser = AuthService.getGuestUser();
      setState(() {
        _userName = guestUser['name'];
        _userAvatar = ''; // No avatar for guest
        _userCountry = 'Visitor'; // Guest indicator
      });
    } else {
      // Load logged-in user data
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _userName = user['name'] ?? 'User';
          _userAvatar = userDummy.avatar; // Using default avatar for now
          _userCountry = 'Pakistan'; // Default country
        });
      } else {
        // No user logged in, show default
        setState(() {
          _userName = 'Guest User';
          _userAvatar = '';
          _userCountry = 'Visitor';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTooltipScaffold =
        context.findAncestorWidgetOfExactType<OverlayTooltipScaffold>() != null;

    final String avatarUrl =
        (_userAvatar.isEmpty ? userDummy.avatar : _userAvatar).trim();

    final Widget notificationsButton = Obx(() {
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
          widget.isFixed,
          () {
            Get.toNamed(AppLink.notification);
          },
        ),
      );
    });

    return AppBar(
      toolbarHeight: 60,
      scrolledUnderElevation: 0.0,
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      flexibleSpace: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: widget.isFixed ? TravelloTheme.paperLight : Colors.transparent,
      ),
      title: GestureDetector(
        onTap: () {
          Get.toNamed(AppLink.profile);
        },
        child: Row(children: [
          /// AVATAR AND USER PROFILE
          CircleAvatar(
            radius: 24,
            backgroundColor: TravelloTheme.paperLightContainerHighest,
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.person,
                          color: TravelloTheme.textMuted,
                          size: 24,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.person,
                        color: TravelloTheme.textMuted,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_userName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TravelloTheme.title2.copyWith(
                      color: widget.isFixed
                          ? colorScheme(context).onSurface
                          : Colors.white)),
              Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: ThemeRadius.small,
                    color: TravelloTheme.paperLight.withValues(alpha: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.red),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text('Karachi • $_userCountry',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ))
            ]),
          )
        ]),
      ),

      /// ACTION BUTTONS
      actions: [
        // Switch to Railway Mode Button
        iconBtn(
          context,
          Icons.train,
          widget.isFixed,
          () => _showModeSwitch(context),
        ),
        hasTooltipScaffold
            ? OverlayTooltipItem(
                displayIndex: 2,
                tooltip: (controller) => Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: MTooltip(
                    title:
                        'Check messages, the best deals, or notification here.',
                    controller: controller,
                  ),
                ),
                child: notificationsButton,
              )
            : notificationsButton,
        const SizedBox(width: 4),
        Tooltip(
          message: 'Help and Support',
          child: iconBtn(
            context,
            Icons.chat_bubble_outline,
            widget.isFixed,
            () {
              Get.toNamed(AppLink.faq);
            },
          ),
        )
      ],
    );
  }

  void _showModeSwitch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('travel_mode', 'railway');
    Get.offAllNamed(AppLink.home);
  }
}
