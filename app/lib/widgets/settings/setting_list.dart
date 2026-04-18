import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/widgets/settings/account_info.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/widgets/onboarding/city_selection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SettingList extends StatefulWidget {
  const SettingList({super.key});

  @override
  State<SettingList> createState() => _SettingListState();
}

class _SettingListState extends State<SettingList> {
  bool _isGuestMode = false;
  String _currentCityName = 'Karachi';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isGuest = await AuthService.isGuestMode();
    final isLoggedIn = await AuthService.isLoggedIn();
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _isGuestMode = isGuest || !isLoggedIn;
        _currentCityName = cityData['cityName']!;
      });
    }
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CitySelectionSheet(
        onComplete: () {
          Navigator.pop(context);
          _checkAuthStatus();
          Get.snackbar(
            'Home City Updated',
            'Featured packages will now show from $_currentCityName',
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.location_city, color: Colors.white),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // ── Guest: quick auth access ───────────────────────────────────
        if (_isGuestMode) ...[
          const TitleBasicSmall(title: 'Quick Access'),
          PaperCard(
            content: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.green),
                  title: const Text('Login',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Access your account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () => Get.toNamed('/login'),
                ),
                const LineList(),
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blue),
                  title: const Text('Sign Up',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create a new account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () => Get.toNamed('/register'),
                ),
              ]),
            ),
          ),
          const VSpace(),
        ],

        // ── My Bookings ────────────────────────────────────────────────
        const TitleBasicSmall(title: 'My Bookings'),
        PaperCard(
          content: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.airplane_ticket_rounded,
                    color: Color(0xFF3B82F6)),
                title: const Text('My Tickets',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View your flight & train tickets'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.myTicket),
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.history_rounded,
                    color: Color(0xFF059669)),
                title: const Text('Booking History',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('All past and upcoming bookings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.orderHistory),
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.favorite_rounded,
                    color: Color(0xFFD4AF37)),
                title: const Text('Saved Packages',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Your liked flights, hotels & trains'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.wishlist),
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.confirmation_num_rounded,
                    color: Color(0xFF7C3AED)),
                title: const Text('E-Ticket',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Download or view your e-tickets'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.eTicket),
              ),
            ]),
          ),
        ),
        const VSpace(),

        // ── Account Settings ───────────────────────────────────────────
        const TitleBasicSmall(title: 'Account Settings'),
        PaperCard(
          content: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Account Information',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View and edit your profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) =>
                        const Wrap(children: [AccountInfo()]),
                  );
                },
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.location_city_rounded,
                    color: Color(0xFFD4AF37)),
                title: const Text('Home City',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _currentCityName,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: _openCityPicker,
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: const Text('Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Manage your notification preferences'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.notification),
              ),
            ]),
          ),
        ),
        const VSpace(),

        // ── Support ────────────────────────────────────────────────────
        const TitleBasicSmall(title: 'Support'),
        PaperCard(
          content: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('FAQ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Frequently asked questions'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed('/faq'),
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: const Text('Contact Support',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Get help from our team'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed('/contact'),
              ),
              const LineList(),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms & Conditions',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed('/terms-conditions'),
              ),
            ]),
          ),
        ),
        const VSpace(),

        // ── Logout ─────────────────────────────────────────────────────
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final isGuest = prefs.getBool('guest_mode') ?? false;

              if (isGuest) {
                await prefs.remove('guest_mode');
                Get.snackbar(
                  'Goodbye!',
                  'Login to access all features!',
                  backgroundColor: Colors.blue.shade600,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                );
                Get.offAllNamed(AppLink.welcome);
              } else {
                await AuthService.logout();
                await prefs.setBool('guest_mode', true);
                Get.snackbar(
                  'Signed Out',
                  'You have been signed out successfully.',
                  backgroundColor: Colors.green.shade600,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 3),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                );
                Get.offAllNamed(AppLink.home);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Sign Out'),
                SizedBox(width: 6),
                Icon(Icons.exit_to_app, size: 18),
              ],
            ),
          ),
        ),
        const VSpace(),

        Center(
          child: Text(
            '${branding.name}  v${branding.version}',
            style: TravelloTheme.caption,
          ),
        ),
        const VSpaceBig(),
      ],
    );
  }
}
