import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/models/user.dart';
import 'package:flight_app/utils/location_preference_service.dart';

class AuthService {
  static const String _usersKey = 'registered_users';
  static const String _currentUserKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _demoUsersInitialized = 'demo_users_initialized';
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedUserKey = 'remembered_user';
  static const String _guestModeKey = 'guest_mode';

  // Initialize demo users from user.dart on first app launch
  static Future<void> initializeDemoUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_demoUsersInitialized) ?? false;

    if (!initialized) {
      List<Map<String, dynamic>> users = [];

      // Add all demo users from userList with name as username and idCard as password
      for (var user in userList) {
        users.add({
          'name': user.name,
          'emailOrPhone': user.name, // Use name as login identifier
          'password': user.idCard, // Use idCard as password
          'email': user.email,
          'phone': user.phone,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      // Save all users
      await prefs.setString(_usersKey, jsonEncode(users));
      await prefs.setBool(_demoUsersInitialized, true);
    }
  }

  // Get all registered users
  static Future<List<Map<String, dynamic>>> getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null || usersJson.isEmpty) {
      return [];
    }

    final List<dynamic> usersList = jsonDecode(usersJson);
    return usersList.cast<Map<String, dynamic>>();
  }

  // Register new user
  static Future<bool> registerUser({
    required String name,
    required String emailOrPhone,
    required String password,
    String? phone,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      List<Map<String, dynamic>> users = await getRegisteredUsers();

      // Check if user already exists - check BOTH email AND phone separately
      bool userExists = users.any((user) {
        // Check email match if provided
        if (email != null && email.trim().isNotEmpty) {
          final userEmail =
              user['email']?.toString().toLowerCase().trim() ?? '';
          if (userEmail == email.toLowerCase().trim()) return true;
        }

        // Check phone match if provided
        if (phone != null && phone.trim().isNotEmpty) {
          final userPhone = user['phone']?.toString().trim() ?? '';
          if (userPhone == phone.trim()) return true;
        }

        // Also check emailOrPhone field for backward compatibility
        final userEmailOrPhone =
            user['emailOrPhone']?.toString().toLowerCase().trim() ?? '';
        if (userEmailOrPhone == emailOrPhone.toLowerCase().trim()) return true;

        return false;
      });

      if (userExists) {
        return false; // User already exists
      }

      // Add new user with separate fields
      users.add({
        'name': name,
        'emailOrPhone': emailOrPhone,
        'email': email ?? emailOrPhone,
        'phone': phone ?? '',
        'password': password,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Save to SharedPreferences
      await prefs.setString(_usersKey, jsonEncode(users));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Login user - supports email, phone, or name
  static Future<Map<String, dynamic>?> loginUser({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      List<Map<String, dynamic>> users = await getRegisteredUsers();

      // Find user by emailOrPhone, name, email, or phone
      Map<String, dynamic>? user = users.firstWhere(
        (user) {
          String input = emailOrPhone.toLowerCase().trim();
          String userEmailOrPhone =
              (user['emailOrPhone'] ?? '').toLowerCase().trim();
          String userName = (user['name'] ?? '').toLowerCase().trim();
          String userEmail = (user['email'] ?? '').toLowerCase().trim();
          String userPhone = (user['phone'] ?? '').toLowerCase().trim();

          return (userEmailOrPhone == input ||
                  userName == input ||
                  userEmail == input ||
                  userPhone == input) &&
              user['password'] == password;
        },
        orElse: () => {},
      );

      if (user.isEmpty) {
        return null; // User not found or wrong password
      }

      // Save current user and login status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user));
      await prefs.setBool(_isLoggedInKey, true);

      // Clear guest mode if user logs in
      await prefs.remove(_guestModeKey);

      return user;
    } catch (e) {
      return null;
    }
  }

  // Get current logged-in user
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      return jsonDecode(userJson);
    } catch (e) {
      return null;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.setBool(_isLoggedInKey, false);

    // Clear city preference on logout (Professional standard - different users may be in different cities)
    await LocationPreferenceService.clearOriginCity();

    // Don't remove remembered credentials on logout
  }

  // Save Remember Me credentials
  static Future<void> saveRememberMe(
      String emailOrPhone, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, true);
    await prefs.setString(
        _rememberedUserKey,
        jsonEncode({
          'emailOrPhone': emailOrPhone,
          'password': password,
        }));
  }

  // Get remembered credentials
  static Future<Map<String, String>?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

    if (!rememberMe) return null;

    final credentialsJson = prefs.getString(_rememberedUserKey);
    if (credentialsJson == null) return null;

    final Map<String, dynamic> credentials = jsonDecode(credentialsJson);
    return {
      'emailOrPhone': credentials['emailOrPhone'] as String,
      'password': credentials['password'] as String,
    };
  }

  // Clear Remember Me
  static Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_rememberedUserKey);
  }

  // Check if email exists
  static Future<bool> checkEmailExists(String email) async {
    try {
      List<Map<String, dynamic>> users = await getRegisteredUsers();

      return users.any((user) =>
          user['email']?.toLowerCase() == email.toLowerCase() ||
          user['emailOrPhone']?.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  // Reset Password
  static Future<bool> resetPassword({
    required String emailOrPhone,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> users = await getRegisteredUsers();

      // Find user by email or phone
      int userIndex = users.indexWhere((user) =>
          user['email']?.toLowerCase() == emailOrPhone.toLowerCase() ||
          user['emailOrPhone']?.toLowerCase() == emailOrPhone.toLowerCase() ||
          user['phone'] == emailOrPhone);

      if (userIndex == -1) {
        return false; // User not found
      }

      // Update password
      users[userIndex]['password'] = newPassword;

      // Save updated users
      await prefs.setString(_usersKey, jsonEncode(users));

      // Update current user if logged in
      final currentUser = await getCurrentUser();
      if (currentUser != null &&
          (currentUser['email']?.toLowerCase() == emailOrPhone.toLowerCase() ||
              currentUser['emailOrPhone']?.toLowerCase() ==
                  emailOrPhone.toLowerCase())) {
        await prefs.setString(_currentUserKey, jsonEncode(users[userIndex]));
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Enable Guest Mode
  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentUserKey);
  }

  // Check if in Guest Mode
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  // Exit Guest Mode
  static Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }

  // Get Guest User Data
  static Map<String, dynamic> getGuestUser() {
    return {
      'name': 'Guest User',
      'email': 'guest@example.com',
      'phone': '',
      'avatar': '', // Empty avatar for guest
      'isGuest': true,
    };
  }

  // Clear all users (for testing purposes)
  static Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usersKey);
    await prefs.remove(_currentUserKey);
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove('finishedIntro');
  }

  // Update current user profile (name, phone, email)
  static Future<bool> updateUserProfile({
    required String name,
    required String phone,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await getCurrentUser();
      if (currentUser == null) return false;

      // Update in users list
      List<Map<String, dynamic>> users = await getRegisteredUsers();
      final idx = users.indexWhere((u) =>
          u['emailOrPhone'] == currentUser['emailOrPhone'] ||
          u['email'] == currentUser['email']);
      if (idx != -1) {
        users[idx]['name'] = name;
        users[idx]['phone'] = phone;
        users[idx]['email'] = email;
        await prefs.setString(_usersKey, jsonEncode(users));
      }

      // Update current user cache
      currentUser['name'] = name;
      currentUser['phone'] = phone;
      currentUser['email'] = email;
      await prefs.setString(_currentUserKey, jsonEncode(currentUser));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Change password – verifies old password first
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await getCurrentUser();
      if (currentUser == null) return 'not_logged_in';

      if (currentUser['password'] != currentPassword) return 'wrong_password';

      List<Map<String, dynamic>> users = await getRegisteredUsers();
      final idx = users.indexWhere((u) =>
          u['emailOrPhone'] == currentUser['emailOrPhone'] ||
          u['email'] == currentUser['email']);
      if (idx != -1) {
        users[idx]['password'] = newPassword;
        await prefs.setString(_usersKey, jsonEncode(users));
      }

      currentUser['password'] = newPassword;
      await prefs.setString(_currentUserKey, jsonEncode(currentUser));
      return 'success';
    } catch (e) {
      return 'error';
    }
  }
}
