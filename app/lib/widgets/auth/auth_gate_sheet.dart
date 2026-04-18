import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// Industry-standard "Soft Auth Gate" — shown when a guest attempts
/// an action that requires authentication (booking, checkout, etc.)
///
/// Pattern used by: Expedia, Booking.com, MakeMyTrip, Wego
/// ─────────────────────────────────────────────────────────────────
/// - Non-blocking: user can dismiss and keep browsing
/// - Clear value proposition before forcing login
/// - Matches app's luxury gold dark theme
class AuthGateSheet extends StatelessWidget {
  /// Short contextual reason shown to user, e.g. "to book this flight"
  final String action;

  const AuthGateSheet({super.key, this.action = 'to complete your booking'});

  /// Show the auth gate as a modal bottom sheet.
  static void show(BuildContext context,
      {String action = 'to complete your booking'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => AuthGateSheet(action: action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Icon badge ───────────────────────────────────────────
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TravelloTheme.primaryMain,
                  TravelloTheme.primaryDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: TravelloTheme.primaryMain.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.black87,
              size: 28,
            ),
          ),

          const SizedBox(height: 16),

          // ── Headline ─────────────────────────────────────────────
          const Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 8),

          // ── Sub-copy ──────────────────────────────────────────────
          Text(
            'Please sign in $action.\nIt only takes a moment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // ── Primary: Login button ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Get.back();
                Get.toNamed(AppLink.login);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TravelloTheme.primaryMain,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Secondary: Create account ─────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                Get.back();
                Get.toNamed(AppLink.register);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: TravelloTheme.primaryMain,
                side: BorderSide(
                  color: TravelloTheme.primaryMain.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Tertiary: Dismiss ──────────────────────────────────────
          GestureDetector(
            onTap: () => Get.back(),
            child: Text(
              'Continue Browsing',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
