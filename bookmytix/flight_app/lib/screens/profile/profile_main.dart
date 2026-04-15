import 'dart:io';

import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/settings/setting_list.dart';
import 'package:flight_app/widgets/profile/profile_banner_header.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          _userAvatar = (user['avatar'] ?? '').toString();
        });
      } else {
        setState(() {
          _userName = 'Guest User';
          _userAvatar = '';
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Change Profile Photo',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: TravelloTheme.primaryMain),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(_, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: TravelloTheme.primaryMain),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(_, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last;
      final path = 'avatars/${user.id}.$ext';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      // Add cache-buster so NetworkImage refreshes
      final avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await AuthService.updateUserProfile(avatarUrl: avatarUrl);

      setState(() => _userAvatar = avatarUrl);

      if (mounted) {
        Get.snackbar(
          'Profile Photo Updated',
          'Your profile photo has been saved.',
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Upload Failed',
          'Could not update profile photo. Please try again.',
          backgroundColor: Colors.orange.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
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
            onPickAvatar: _pickAndUploadAvatar,
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
