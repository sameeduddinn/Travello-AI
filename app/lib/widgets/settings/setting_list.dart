import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/services/api_client.dart';
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
  String _currentCityName = 'Karachi';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _currentCityName = cityData['cityName']!;
      });
    }
  }

Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.logout();
    Get.snackbar('Signed Out', 'You have been signed out successfully.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.check_circle, color: Colors.white));
    Get.offAllNamed(AppLink.welcome);
  }

  bool _isDeletingAccount = false;

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete your account and all associated data — bookings, reviews, and preferences. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Second confirmation — type DELETE
    final controller = TextEditingController();
    final typed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type DELETE to confirm account deletion:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim() == 'DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (typed != true) {
      if (mounted) {
        Get.snackbar('Cancelled', 'You must type DELETE to confirm.',
            backgroundColor: Colors.orange.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2));
      }
      return;
    }

    if (mounted) setState(() => _isDeletingAccount = true);
    try {
      await ApiClient.deleteAccount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Get.offAllNamed(AppLink.welcome);
        Get.snackbar('Account Deleted', 'Your account has been permanently deleted.',
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        Get.snackbar('Error', 'Failed to delete account. Please try again.',
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3));
      }
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
                subtitle: const Text('View your completed & past bookings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.myTicket,
                    arguments: {'historyMode': true}),
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
                leading: const Icon(Icons.manage_search_rounded,
                    color: Color(0xFF6366F1)),
                title: const Text('Saved Searches',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Your recent flight, train & hotel searches'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Get.toNamed(AppLink.savedSearches),
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
              const ListTile(
                leading: Icon(Icons.attach_money_rounded,
                    color: Color(0xFF059669)),
                title: Text('Currency',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'PKR',
                  style: TextStyle(
                      color: Color(0xFF059669), fontWeight: FontWeight.w600),
                ),
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
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.exit_to_app, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const VSpace(),

        // ── Danger Zone ────────────────────────────────────────────────
        ...[
          const TitleBasicSmall(title: 'Danger Zone'),
          PaperCard(
            content: Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                leading: _isDeletingAccount
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red))
                    : const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete Account',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.red)),
                subtitle: const Text('Permanently remove your account and all data'),
                trailing: _isDeletingAccount
                    ? null
                    : const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
              ),
            ),
          ),
          const VSpace(),
        ],

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
