import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/settings/setting_list.dart';
import 'package:flight_app/widgets/profile/profile_banner_header.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/constants/app_constants.dart';

class ProfileMain extends StatefulWidget {
  const ProfileMain({super.key});

  @override
  State<ProfileMain> createState() => _ProfileMainState();
}

class _ProfileMainState extends State<ProfileMain> {
  String _userName = 'User';
  String _userAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data whenever widget rebuilds
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Check if in guest mode
    final isGuest = await AuthService.isGuestMode();

    if (isGuest) {
      final guestUser = AuthService.getGuestUser();
      setState(() {
        _userName = guestUser['name'];
        _userAvatar = ''; // No avatar for guest
      });
    } else {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _userName = user['name'] ?? 'User';
          _userAvatar = userDummy.avatar; // Using default avatar
        });
      } else {
        setState(() {
          _userName = 'Guest User';
          _userAvatar = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: ProfileBannerHeader(
            minExtent: topPadding + 120,
            maxExtent: 300,
            userName: _userName,
            userAvatar: _userAvatar,
          ),
          pinned: true,
        ),
        SliverToBoxAdapter(
          child: Align(
              alignment: Alignment.center,
              child: Container(
                  constraints: BoxConstraints(maxWidth: ThemeSize.sm),
                  child: const SettingList())),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80))
      ],
    );
  }
}
