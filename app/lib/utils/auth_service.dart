import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flight_app/utils/location_preference_service.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedUserKey = 'remembered_user';
  static const String _guestModeKey = 'guest_mode';
  static String? _lastAuthError;

  static String? get lastAuthError => _lastAuthError;

  static void _setAuthError(String? message) {
    _lastAuthError = message;
  }

  /// Translates raw Supabase / network error messages into user-friendly text.
  static String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials') ||
        msg.contains('email not confirmed') ||
        msg.contains('invalid_grant')) {
      return 'Invalid email or password. If you signed up with Google, continue with Google or use Forgot Password once to set a password.';
    }
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('email address is already')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (msg.contains('invalid email') ||
        msg.contains('invalid format') ||
        msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('password') &&
        (msg.contains('weak') ||
            msg.contains('short') ||
            msg.contains('at least') ||
            msg.contains('characters'))) {
      return 'Password is too weak. Use 8+ characters with upper, lower, number & symbol.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('socket')) {
      return 'Network error. Please check your internet connection.';
    }
    return raw;
  }

  // Retained for backward compatibility with existing startup flow.
  static Future<void> initializeDemoUsers() async {
    return;
  }

  // Legacy API retained for compatibility with older UI code.
  static Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    return [];
  }

  static Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toAppUser(
    User user, {
    Map<String, dynamic>? profile,
  }) {
    final metadata = user.userMetadata ?? <String, dynamic>{};

    final name = (profile?['full_name'] ?? metadata['full_name'] ?? '')
        .toString()
        .trim();
    final phone =
        (profile?['phone'] ?? metadata['phone'] ?? '').toString().trim();
    final avatar = (profile?['avatar_url'] ?? metadata['avatar_url'] ?? '')
        .toString()
        .trim();

    return {
      'id': user.id,
      'name': name.isEmpty ? 'User' : name,
      'email': user.email ?? '',
      'phone': phone,
      'avatar': avatar,
      'createdAt': user.createdAt,
    };
  }

  static Future<void> _upsertOwnProfile({
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final payload = <String, dynamic>{
      'id': user.id,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) payload['full_name'] = name;
    if (phone != null) payload['phone'] = phone;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

    await _supabase.from('profiles').upsert(payload);
  }

  static Future<bool> registerUser({
    required String name,
    required String emailOrPhone,
    required String password,
    String? phone,
    String? email,
  }) async {
    try {
      _setAuthError(null);
      final normalizedEmail =
          ((email ?? emailOrPhone).toString()).trim().toLowerCase();
      final normalizedPhone = (phone ?? '').trim();

      // Basic client-side email sanity check before hitting the network.
      if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
        _setAuthError('Please enter a valid email address.');
        return false;
      }

      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': name.trim(),
          'phone': normalizedPhone,
        },
      );

      // When email confirmation is enabled, Supabase does NOT throw for a
      // duplicate email — it silently returns a user whose identities list is
      // empty.  Detect this case and surface a clear error.
      final user = response.user;
      if (user != null && user.identities != null && user.identities!.isEmpty) {
        _setAuthError(
          'This email is already registered. Please sign in instead.',
        );
        return false;
      }

      return true;
    } on AuthException catch (e) {
      _setAuthError(_friendlyAuthError(e.message));
      return false;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('timeout')) {
        _setAuthError('Network error. Please check your internet connection.');
      } else {
        _setAuthError('Something went wrong. Please try again.');
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> loginUser({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      _setAuthError(null);
      final login = emailOrPhone.trim().toLowerCase();
      if (!login.contains('@')) {
        _setAuthError('Please use a valid email address.');
        return null;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: login,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      final profile = await _fetchProfile(user.id);
      final appUser = _toAppUser(user, profile: profile);

      await _upsertOwnProfile(
        name: appUser['name']?.toString(),
        phone: appUser['phone']?.toString(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestModeKey);

      return appUser;
    } on AuthException catch (e) {
      _setAuthError(_friendlyAuthError(e.message));
      return null;
    } catch (e) {
      _setAuthError(e.toString());
      return null;
    }
  }

  static Future<bool> signInWithGoogle() async {
    try {
      _setAuthError(null);
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'travelloai://auth-callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      return true;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<Map<String, dynamic>?> waitForAuthenticatedUser({
    Duration timeout = const Duration(seconds: 40),
    Duration interval = const Duration(milliseconds: 350),
  }) async {
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < timeout) {
      final user = await getCurrentUser();
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_guestModeKey);
        return user;
      }

      await Future.delayed(interval);
    }

    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (isDesktop) {
      _setAuthError(
        'OAuth callback did not return to app. On desktop debug builds, custom URI scheme may require protocol registration. Test Google login on Android/iOS for now.',
      );
    } else {
      _setAuthError('OAuth timed out. Please try again.');
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profile = await _fetchProfile(user.id);
      return _toAppUser(user, profile: profile);
    } catch (e) {
      _setAuthError(e.toString());
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool(_guestModeKey) ?? false;
    return !isGuest && _supabase.auth.currentSession != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _supabase.auth.signOut();
    await prefs.remove(_guestModeKey);

    // Different users may be in different cities.
    await LocationPreferenceService.clearOriginCity();
  }

  static Future<void> saveRememberMe(
      String emailOrPhone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, true);
    await prefs.setString(
      _rememberedUserKey,
      jsonEncode({
        'emailOrPhone': emailOrPhone,
        'password': password,
      }),
    );
  }

  static Future<Map<String, String>?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

    if (!rememberMe) return null;

    final credentialsJson = prefs.getString(_rememberedUserKey);
    if (credentialsJson == null || credentialsJson.isEmpty) return null;

    final decoded = jsonDecode(credentialsJson) as Map<String, dynamic>;
    final emailOrPhone = (decoded['emailOrPhone'] ?? '').toString();
    final password = (decoded['password'] ?? '').toString();

    if (emailOrPhone.isEmpty || password.isEmpty) return null;

    return {
      'emailOrPhone': emailOrPhone,
      'password': password,
    };
  }

  static Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_rememberedUserKey);
  }

  // Kept for compatibility. In Supabase auth, existence checks should not be exposed.
  static Future<bool> checkEmailExists(String email) async {
    return email.trim().isNotEmpty;
  }

  static Future<bool> resendSignupCode(String email) async {
    try {
      _setAuthError(null);
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
      return true;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<bool> verifySignupCode({
    required String email,
    required String code,
  }) async {
    try {
      _setAuthError(null);
      final response = await _supabase.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.signup,
      );

      return response.user != null || response.session != null;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<bool> sendPasswordResetCode(String emailOrPhone) async {
    try {
      _setAuthError(null);
      final email = emailOrPhone.trim().toLowerCase();
      if (!email.contains('@')) return false;

      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  // Step 1 — yeh session store karne ke liye add karo class mein
  static Session? _recoverySession;

  static Future<bool> verifyPasswordResetCode({
    required String emailOrPhone,
    required String code,
  }) async {
    try {
      _setAuthError(null);
      final email = emailOrPhone.trim().toLowerCase();

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: code.trim(),
        type: OtpType.recovery,
      );

      // ── FIX: recovery session ko store karo ──
      if (response.session != null) {
        _recoverySession = response.session;
      }

      return response.user != null || response.session != null;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<bool> resetPassword({
    required String emailOrPhone,
    required String newPassword,
  }) async {
    try {
      _setAuthError(null);

      // ── FIX: recovery session set karo ──
      if (_recoverySession != null) {
        await _supabase.auth.setSession(_recoverySession!.refreshToken!);
        _recoverySession = null;
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _setAuthError(_friendlyAuthError(e.message));
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await _supabase.auth.signOut();
    await prefs.setBool(_guestModeKey, true);
  }

  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  static Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }

  static Map<String, dynamic> getGuestUser() {
    return {
      'name': 'Guest User',
      'email': 'guest@example.com',
      'phone': '',
      'avatar': '',
      'isGuest': true,
    };
  }

  static Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await _supabase.auth.signOut();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_rememberedUserKey);
    await prefs.remove(_guestModeKey);
    await prefs.remove('finishedIntro');
  }

  static Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
  }) async {
    try {
      _setAuthError(null);
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final trimmedName = name?.trim();
      final trimmedPhone = phone?.trim();
      final trimmedEmail = email?.trim().toLowerCase();

      if (trimmedEmail != null &&
          trimmedEmail.isNotEmpty &&
          trimmedEmail != (currentUser.email ?? '')) {
        await _supabase.auth.updateUser(UserAttributes(email: trimmedEmail));
      }

      final metaData = <String, dynamic>{};
      if (trimmedName != null) metaData['full_name'] = trimmedName;
      if (trimmedPhone != null) metaData['phone'] = trimmedPhone;
      if (avatarUrl != null) metaData['avatar_url'] = avatarUrl;

      if (metaData.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(data: metaData));
      }

      await _upsertOwnProfile(
        name: trimmedName,
        phone: trimmedPhone,
        avatarUrl: avatarUrl,
      );
      return true;
    } on AuthException catch (e) {
      _setAuthError(e.message);
      return false;
    } catch (e) {
      _setAuthError(e.toString());
      return false;
    }
  }

  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'not_logged_in';
      final email = user.email;
      if (email == null || email.isEmpty) return 'error';

      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
      } on AuthException {
        return 'wrong_password';
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return 'success';
    } on AuthException {
      return 'error';
    } catch (_) {
      return 'error';
    }
  }
}
