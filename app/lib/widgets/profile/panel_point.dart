import 'package:flutter/material.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PanelPoint extends StatefulWidget {
  const PanelPoint({super.key});

  @override
  State<PanelPoint> createState() => _PanelPointState();
}

class _PanelPointState extends State<PanelPoint>
    with SingleTickerProviderStateMixin {
  bool _isLoggedIn = false;
  int _totalBookings = 0;
  int _upcomingTrips = 0;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBookingData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    try {
      // Check if user is logged in
      final loggedIn = await AuthService.isLoggedIn();

      setState(() {
        _isLoggedIn = loggedIn;
      });

      if (loggedIn) {
        // Load booking statistics from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final bookingsJson = prefs.getString('user_bookings');

        if (bookingsJson != null && bookingsJson.isNotEmpty) {
          // Count total and upcoming bookings
          // For now using dummy data, replace with actual booking parsing
          setState(() {
            _totalBookings = prefs.getInt('total_bookings') ?? 0;
            _upcomingTrips = prefs.getInt('upcoming_trips') ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16),
            decoration: BoxDecoration(
              color: TravelloTheme.paperLight,
              borderRadius: ThemeRadius.medium,
              boxShadow: [
                ThemeShade.shadeSoft(context),
                BoxShadow(
                  color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            TravelloTheme.primaryMain,
                          ),
                        ),
                      ),
                    )
                  : _isLoggedIn
                      ? _buildLoggedInView(context)
                      : _buildGuestView(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Logged-in user view with booking statistics
  Widget _buildLoggedInView(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        /// TOTAL BOOKINGS
        Expanded(
          child: _buildStatCard(
            context: context,
            icon: Icons.confirmation_number_outlined,
            count: _totalBookings,
            label: 'Total Bookings',
            gradient: LinearGradient(
              colors: [
                TravelloTheme.primaryMain.withValues(alpha: 0.15),
                TravelloTheme.primaryLight.withValues(alpha: 0.1),
              ],
            ),
            iconColor: TravelloTheme.primaryMain,
            delay: 200,
          ),
        ),

        SizedBox(
          height: 40,
          child: VerticalDivider(
            color: TravelloTheme.primaryMain.withValues(alpha: 0.2),
            width: 20,
            thickness: 1,
          ),
        ),

        /// UPCOMING TRIPS
        Expanded(
          child: _buildStatCard(
            context: context,
            icon: Icons.flight_takeoff,
            count: _upcomingTrips,
            label: 'Upcoming',
            gradient: LinearGradient(
              colors: [
                TravelloTheme.secondaryMain.withValues(alpha: 0.15),
                TravelloTheme.secondaryLight.withValues(alpha: 0.1),
              ],
            ),
            iconColor: TravelloTheme.secondaryMain,
            delay: 400,
          ),
        ),
      ],
    );
  }

  /// Animated stat card
  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required int count,
    required String label,
    required LinearGradient gradient,
    required Color iconColor,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        iconColor,
                        iconColor.withValues(alpha: 0.8),
                      ],
                    ).createShader(bounds),
                    child: Icon(
                      icon,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => ThemePalette
                            .gradientPrimaryLight
                            .createShader(bounds),
                        child: Text(
                          '$count',
                          style: TravelloTheme.subtitle2.copyWith(
                            height: 1,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TravelloTheme.paragraph.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Guest user view - encourage login
  Widget _buildGuestView(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: InkWell(
              onTap: () => Get.toNamed('/login'),
              borderRadius: ThemeRadius.medium,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TravelloTheme.primaryMain.withValues(alpha: 0.08),
                      TravelloTheme.primaryLight.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: ThemeRadius.medium,
                  border: Border.all(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: TravelloTheme.gradientPrimaryLight,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: TravelloTheme.primaryMain.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.login,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => ThemePalette
                                .gradientPrimaryDark
                                .createShader(bounds),
                            child: const Text(
                              'Login to View Your Bookings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Track your trips & manage reservations',
                            style: TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
