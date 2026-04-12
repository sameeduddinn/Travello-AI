import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flight_app/components/home/service_tabs.dart';
import 'package:flight_app/components/home/hero_section.dart';
import 'package:flight_app/widgets/home/quick_search_bar.dart';
import 'package:flight_app/widgets/home/quick_access_features.dart';
import 'package:flight_app/widgets/home/dynamic_destination_cards.dart';
import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flight_app/widgets/home/train_package_slider.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flight_app/widgets/home/premium_carousel.dart';
import 'package:flight_app/widgets/bottom_navigation/bottom_nav_menu.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/models/destination.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// 🔥 TRAVELLO AI - UNIFIED HOME SCREEN
///
/// Enterprise-grade unified booking hub following Wego architecture
///
/// ## Features:
/// - ✅ Single entry point for Flight, Train, Hotel booking
/// - ✅ Dynamic hero section with smooth transitions
/// - ✅ No UI duplication - navigates to existing screens
/// - ✅ Premium animations and glassmorphism design
/// - ✅ Scalable for future services
///
/// ## Architecture Benefits (FYP Defense):
/// 1. **Centralized State**: Single `selectedService` state drives all UI
/// 2. **No Duplication**: Reuses existing booking screens
/// 3. **Scalability**: Easy to add new services (Bus, Car Rental)
/// 4. **Clean Separation**: Presentation vs Business Logic
/// 5. **Wego-Inspired**: Aggregator pattern for travel services
///
/// @author Travello AI Team
/// @version 2.0 - Unified Hub Architecture
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🎯 CORE STATE - Single source of truth
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  String _selectedService = 'flight'; // flight | train | hotel

  // User state
  String _userName = 'User';
  String _userAvatar = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// Load current authenticated user from AuthService
  Future<void> _loadUserProfile() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userName = user['name'] ?? 'User';
        _userAvatar = user['avatar'] ?? '';
      });
    } else {
      // No authenticated user - redirect to login
      Future.delayed(Duration.zero, () {
        Get.offAllNamed(AppLink.welcome);
      });
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🚀 NAVIGATION LOGIC - Routes to existing booking screens
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _navigateToBooking() {
    // Search is FREE for all users — auth gate only at BOOK NOW (Expedia/Booking.com standard)
    switch (_selectedService) {
      case 'flight':
        Get.toNamed('/flight-search-home');
        break;
      case 'train':
        Get.toNamed('/train-search-home');
        break;
      case 'hotel':
        Get.toNamed(AppLink.hotelSearch);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: TravelloTheme.paperLight,
      bottomNavigationBar: const BottomNavMenu(),

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 📱 PROFESSIONAL STICKY NAVBAR - Wego/Booking.com Standard
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kToolbarHeight + MediaQuery.of(context).padding.top,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TravelloTheme.primaryMain,
                TravelloTheme.primaryMain.withValues(alpha: 0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  // 👤 USER AVATAR - Touch-friendly 44x44 target
                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  GestureDetector(
                    onTap: () => Get.toNamed(AppLink.profile),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: _userAvatar.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _userAvatar,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    CupertinoIcons.person_fill,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 22,
                                  ),
                                ),
                              )
                            : Icon(
                                CupertinoIcons.person_fill,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 22,
                              ),
                      ),
                    ),
                  ),

                  SizedBox(width: isSmallScreen ? 10 : 12),

                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  // 📝 USER INFO - Flexible with ellipsis
                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.toNamed(AppLink.profile),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: isSmallScreen ? 4 : 8),

                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  // 🔔 NOTIFICATION ICON - 44x44 touch target
                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  Obx(() {
                    final ctrl = Get.find<NotificationController>();
                    final unreadCount = ctrl.unreadCount.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Get.toNamed(
                          AppLink.notification,
                          arguments: {'tab': 0},
                        ),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                CupertinoIcons.bell,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: 24,
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                    ),
                                    height: 16,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: TravelloTheme.primaryMain,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  SizedBox(width: isSmallScreen ? 2 : 4),

                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  // 💬 CHAT ICON - 44x44 touch target
                  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.toNamed(
                        AppLink.notification,
                        arguments: {'tab': 1},
                      ),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.chat_bubble_text,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 📜 MAIN BODY - Scrollable content
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 🌟 HERO SECTION - Dynamic background & CTA
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Stack(
              children: [
                HeroSection(
                  serviceType: _selectedService,
                  onCtaTap: _navigateToBooking,
                ),

                // Service tabs overlay (positioned at bottom of hero)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: ServiceTabs(
                    selectedService: _selectedService,
                    onServiceChanged: (service) {
                      setState(() {
                        _selectedService = service;
                      });
                    },
                  ),
                ),
              ],
            ),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 🔍 QUICK SEARCH BAR
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            const SizedBox(height: 16),
            QuickSearchBar(service: _selectedService),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // ⚡ FEATURES SECTION
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            const SizedBox(height: 24),
            const QuickAccessFeatures(),

            const SizedBox(height: 24),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // � DYNAMIC SECTIONS - Changes based on selected service
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            _buildDynamicContent(),

            const SizedBox(height: 24),

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 🇵🇰 DISCOVER PAKISTAN CAROUSEL (static — same on all tabs)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            const PremiumCarousel(),

            const SizedBox(height: 80), // Bottom nav clearance
          ],
        ),
      ),
    );
  }

  /// Features section with AI Assistant, Weather, Healthcare
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(spacingUnit(isCompact ? 2 : 2.5)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isCompact ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isCompact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 🎯 DYNAMIC CONTENT - Changes based on selected service
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildDynamicContent() {
    switch (_selectedService) {
      case 'flight':
        return _buildFlightContent();
      case 'train':
        return _buildTrainContent();
      case 'hotel':
        return _buildHotelContent();
      default:
        return _buildFlightContent();
    }
  }

  /// ✈️ Flight-specific content
  Widget _buildFlightContent() {
    return Column(
      children: [
        // Top Flight Destinations
        DynamicDestinationCards(
          destinations: flightDestinations,
          travelMode: 'flight',
        ),
        const SizedBox(height: 32),

        // Featured Flight Packages
        const PackageListSlider(),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 🚆 Train-specific content
  Widget _buildTrainContent() {
    return Column(
      children: [
        // Popular Train Routes
        DynamicDestinationCards(
          destinations: trainDestinations,
          travelMode: 'train',
        ),
        const SizedBox(height: 32),

        // Featured Train Journeys
        const TrainPackageSlider(),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 🏨 Hotel-specific content
  Widget _buildHotelContent() {
    return Column(
      children: [
        // Top Tourist Destinations
        DynamicDestinationCards(
          destinations: hotelDestinations,
          travelMode: 'hotel',
        ),
        const SizedBox(height: 32),

        // Featured Hotel Packages with deal cards below heading
        _buildHotelPackagesSection(),
        const SizedBox(height: 16),

        // SECTION 2 – TOP HOTELS OF PAKISTAN
        Container(
          margin: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.of(context).size.width > 1200 ? spacingUnit(8) : 16,
          ),
          child: const _TopHotelsOfPakistanSection(),
        ),
        const SizedBox(height: 16),

        // SECTION 3 – EXPLORE PAKISTAN DESTINATIONS
        Container(
          margin: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.of(context).size.width > 1200 ? spacingUnit(8) : 16,
          ),
          child: _HotelExplorePakistanSection(
            onCityTap: (city) =>
                Get.toNamed(AppLink.hotelSearch, arguments: {'city': city}),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Train benefits info section
  /// Hotel packages section
  Widget _buildHotelPackagesSection() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.of(context).size.width > 1200 ? spacingUnit(8) : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitleAction(
            title: 'Featured Hotel Packages',
            textAction: 'See All',
            onTap: () => Get.toNamed(AppLink.hotelPackageAll),
          ),
          const SizedBox(height: 4),
          Text(
            'Curated stays in Pakistan\'s most beautiful locations',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme(context).onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // Deal cards below the heading
          Builder(builder: (context) {
            final now = DateTime.now();
            final checkIn = now.add(const Duration(days: 3));
            final checkOut = checkIn.add(const Duration(days: 2));
            return _HotelWeekendDealsSection(
              checkInDate: checkIn,
              checkOutDate: checkOut,
              nights: 2,
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HOTEL SECTION 1 — FEATURED HOTEL DEALS
// ═══════════════════════════════════════════════════════════════════════════
class _HotelWeekendDealsSection extends StatefulWidget {
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int nights;

  const _HotelWeekendDealsSection({
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
  });

  @override
  State<_HotelWeekendDealsSection> createState() =>
      _HotelWeekendDealsSectionState();
}

class _HotelWeekendDealsSectionState extends State<_HotelWeekendDealsSection> {
  final ScrollController _scroll = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      setState(() {
        _canScrollLeft = _scroll.offset > 8;
        _canScrollRight = _scroll.offset < _scroll.position.maxScrollExtent - 8;
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotels = PakistanHotels.getHotels('').take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 356,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                itemCount: hotels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final h = hotels[i];
                  final discountPct = (i % 3 == 0)
                      ? 20
                      : (i % 3 == 1)
                          ? 15
                          : 10;
                  final origPrice = h.pricePerNight * widget.nights;
                  final finalPrice = origPrice * (1 - discountPct / 100);
                  final guestCount = Random().nextInt(2) + 1; // 1 or 2
                  return SizedBox(
                    height: 352,
                    child: _HotelWeekendDealCard(
                      hotel: h,
                      nights: widget.nights,
                      guests: guestCount,
                      originalPrice: origPrice,
                      finalPrice: finalPrice,
                      discountPct: discountPct,
                      isGenius: h.rating >= 4.4,
                      isDeal: discountPct >= 20,
                      onTap: () => Get.toNamed(
                        AppLink.hotelDetail,
                        arguments: {
                          'hotel': h,
                          'checkInDate': widget.checkInDate,
                          'checkOutDate': widget.checkOutDate,
                          'rooms': 1,
                          'guests': guestCount,
                          'discountPct': discountPct,
                          'originalPrice': origPrice,
                          'finalPrice': finalPrice,
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            // Left arrow
            if (_canScrollLeft)
              Positioned(
                left: 4,
                child: _ScrollArrow(
                  icon: Icons.chevron_left,
                  onTap: () => _scrollBy(-480),
                ),
              ),
            // Right arrow
            if (_canScrollRight)
              Positioned(
                right: 4,
                child: _ScrollArrow(
                  icon: Icons.chevron_right,
                  onTap: () => _scrollBy(480),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ScrollArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  State<_ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<_ScrollArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFD4AF37)
                : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: _hovered ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

class _HotelWeekendDealCard extends StatefulWidget {
  final Hotel hotel;
  final int nights;
  final int guests;
  final double originalPrice;
  final double finalPrice;
  final int discountPct;
  final bool isGenius;
  final bool isDeal;
  final VoidCallback onTap;

  const _HotelWeekendDealCard({
    required this.hotel,
    required this.nights,
    required this.guests,
    required this.originalPrice,
    required this.finalPrice,
    required this.discountPct,
    required this.isGenius,
    required this.isDeal,
    required this.onTap,
  });

  @override
  State<_HotelWeekendDealCard> createState() => _HotelWeekendDealCardState();
}

class _HotelWeekendDealCardState extends State<_HotelWeekendDealCard>
    with SingleTickerProviderStateMixin {
  bool _wishlisted = false;
  bool _hovered = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
    _loadWishlistState();
  }

  Future<void> _loadWishlistState() async {
    final liked = await WishlistService.isLiked('hotel', widget.hotel.id);
    if (mounted) setState(() => _wishlisted = liked);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleWishlist() async {
    final added = await WishlistService.toggle('hotel', widget.hotel.id);
    if (mounted) {
      setState(() => _wishlisted = added);
      _heartCtrl.forward(from: 0);
      if (added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.favorite, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text('Added to Saved',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
      }
    }
  }

  Color get _ratingColor {
    final r = widget.hotel.rating;
    if (r >= 4.5) return const Color(0xFF1B4332);
    if (r >= 4.0) return const Color(0xFF1565C0);
    if (r >= 3.5) return const Color(0xFF4A90E2);
    return Colors.grey.shade600;
  }

  String get _ratingLabel {
    final r = widget.hotel.rating;
    if (r >= 4.7) return 'Exceptional';
    if (r >= 4.5) return 'Wonderful';
    if (r >= 4.2) return 'Excellent';
    if (r >= 4.0) return 'Very Good';
    if (r >= 3.5) return 'Good';
    return 'Okay';
  }

  int _starsForCategory(String cat) {
    if (cat.contains('5')) return 5;
    if (cat.contains('4')) return 4;
    if (cat.contains('3')) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final h = widget.hotel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 230,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFD4AF37)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.07),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Image ──────────────────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      height: 145,
                      width: double.infinity,
                      child: h.images.isNotEmpty
                          ? Image.network(
                              h.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.hotel,
                                    size: 40, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.hotel,
                                  size: 40, color: Colors.grey),
                            ),
                    ),
                    // Discount badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${widget.discountPct}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Wishlist
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleWishlist,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4),
                            ],
                          ),
                          child: ScaleTransition(
                            scale: _heartScale,
                            child: Icon(
                              _wishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: _wishlisted
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Info ────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1 – Star icons + category pill
                      Row(
                        children: [
                          ...List.generate(
                            _starsForCategory(h.category),
                            (_) => const Icon(Icons.star,
                                size: 11, color: Color(0xFFD4AF37)),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              h.category,
                              style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Hotel name
                      Text(
                        h.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Location + distance from centre
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${h.city} · ${h.distanceFromCenter.toStringAsFixed(1)} km from centre',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Review score
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _ratingColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              h.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_ratingLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A))),
                                Text('${fmt.format(h.totalReviews)} reviews',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // Amenity badges — fixed height keeps all cards equal
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            if (h.isRefundable) ...[
                              const _AmenityBadge(
                                  label: 'Free Cancellation',
                                  bgColor: TravelloTheme.primaryMain,
                                  textColor: Colors.black),
                              if (h.hasBreakfast) const SizedBox(width: 4),
                            ],
                            if (h.hasBreakfast)
                              const _AmenityBadge(
                                  label: 'Breakfast \u2713',
                                  bgColor: TravelloTheme.primaryMain,
                                  textColor: Colors.black),
                            if (!h.isRefundable && !h.hasBreakfast)
                              _AmenityBadge(
                                  label:
                                      h.hasFreeWifi ? 'Free WiFi' : 'Room Only',
                                  bgColor: Colors.grey.shade200,
                                  textColor: Colors.grey.shade700),
                          ],
                        ),
                      ),
                      const Divider(height: 10),
                      // Per night label
                      Text('Per night',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      // Prices
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'PKR ${fmt.format(h.pricePerNight.round())}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'PKR ${fmt.format((h.pricePerNight * (1 - widget.discountPct / 100)).round())}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: TravelloTheme.primaryMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'PKR ${fmt.format(widget.finalPrice.round())} total · ${widget.nights} nights · ${widget.guests} ${widget.guests == 1 ? 'guest' : 'guests'}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HOTEL SECTION 2 — TOP HOTELS OF PAKISTAN
// ═══════════════════════════════════════════════════════════════════════════
class _TopHotelEntry {
  final String name;
  final String city;
  final String category;
  final double rating;
  final int reviewCount;
  final int pricePerNight;
  final String imageUrl;
  final List<String> amenities;
  final Color accentColor;

  const _TopHotelEntry({
    required this.name,
    required this.city,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.pricePerNight,
    required this.imageUrl,
    required this.amenities,
    required this.accentColor,
  });
}

const List<_TopHotelEntry> _topPakHotels = [
  _TopHotelEntry(
    name: 'Pearl Continental Karachi',
    city: 'Karachi',
    category: '5-Star',
    rating: 4.6,
    reviewCount: 4821,
    pricePerNight: 42000,
    imageUrl:
        'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Spa', 'Fine Dining'],
    accentColor: Color(0xFF1A237E),
  ),
  _TopHotelEntry(
    name: 'Serena Hotel Islamabad',
    city: 'Islamabad',
    category: '5-Star',
    rating: 4.7,
    reviewCount: 3956,
    pricePerNight: 38000,
    imageUrl:
        'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Spa', 'Multiple Restaurants'],
    accentColor: Color(0xFF006064),
  ),
  _TopHotelEntry(
    name: 'Marriott Hotel Islamabad',
    city: 'Islamabad',
    category: '5-Star',
    rating: 4.6,
    reviewCount: 3104,
    pricePerNight: 36000,
    imageUrl:
        'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Rooftop', 'Business Center'],
    accentColor: Color(0xFF4A148C),
  ),
  _TopHotelEntry(
    name: 'Avari Towers Karachi',
    city: 'Karachi',
    category: '5-Star',
    rating: 4.5,
    reviewCount: 2874,
    pricePerNight: 28000,
    imageUrl:
        'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Gym', 'City View'],
    accentColor: Color(0xFFBF360C),
  ),
  _TopHotelEntry(
    name: 'Pearl Continental Lahore',
    city: 'Lahore',
    category: '5-Star',
    rating: 4.5,
    reviewCount: 3312,
    pricePerNight: 34000,
    imageUrl:
        'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Spa', 'Garden'],
    accentColor: Color(0xFF880E4F),
  ),
  _TopHotelEntry(
    name: 'Avari Hotel Lahore',
    city: 'Lahore',
    category: '5-Star',
    rating: 4.4,
    reviewCount: 2648,
    pricePerNight: 22000,
    imageUrl:
        'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=600&q=80',
    amenities: ['Pool', 'Free WiFi', 'Fine Dining', 'Business Center'],
    accentColor: Color(0xFF1B5E20),
  ),
  _TopHotelEntry(
    name: 'PC Bhurban Murree',
    city: 'Murree',
    category: '5-Star',
    rating: 4.6,
    reviewCount: 1892,
    pricePerNight: 25000,
    imageUrl:
        'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600&q=80',
    amenities: ['Forest Views', 'Free WiFi', 'Heated Pool', 'Bonfire'],
    accentColor: Color(0xFF2E7D32),
  ),
  _TopHotelEntry(
    name: 'Hunza Serena Inn',
    city: 'Hunza',
    category: '4-Star',
    rating: 4.7,
    reviewCount: 1543,
    pricePerNight: 18000,
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&q=80',
    amenities: ['Mountain Views', 'Free WiFi', 'Garden', 'Local Cuisine'],
    accentColor: Color(0xFF1565C0),
  ),
  _TopHotelEntry(
    name: 'Shangrila Resort Skardu',
    city: 'Skardu',
    category: '4-Star',
    rating: 4.6,
    reviewCount: 2108,
    pricePerNight: 15000,
    imageUrl:
        'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600&q=80',
    amenities: ['Lake View', 'Free WiFi', 'Orchard', 'Boat Rides'],
    accentColor: Color(0xFF006064),
  ),
  _TopHotelEntry(
    name: 'Swat Serena Hotel',
    city: 'Swat',
    category: '4-Star',
    rating: 4.4,
    reviewCount: 1276,
    pricePerNight: 14000,
    imageUrl:
        'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=600&q=80',
    amenities: ['Valley Views', 'Free WiFi', 'Restaurant', 'Garden'],
    accentColor: Color(0xFF37474F),
  ),
];

class _TopHotelsOfPakistanSection extends StatelessWidget {
  const _TopHotelsOfPakistanSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Hotels of Pakistan',
          style: TravelloTheme.title2.copyWith(
            color: colorScheme(context).onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Handpicked luxury & premium stays across Pakistan',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme(context).onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 295,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: _topPakHotels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final h = _topPakHotels[i];
              return GestureDetector(
                onTap: () => Get.toNamed(
                  AppLink.hotelSearch,
                  arguments: {'city': h.city},
                ),
                child: _TopHotelCard(hotel: h),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopHotelCard extends StatelessWidget {
  final _TopHotelEntry hotel;
  const _TopHotelCard({required this.hotel});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: hotel.accentColor.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    hotel.imageUrl,
                    width: 210,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 210,
                      height: 140,
                      color: hotel.accentColor.withValues(alpha: 0.2),
                      child:
                          Icon(Icons.hotel, color: hotel.accentColor, size: 40),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 210,
                        height: 140,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                  // Category badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TravelloTheme.primaryMain,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: TravelloTheme.primaryDark
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        hotel.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B2A00),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1400).withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              TravelloTheme.primaryMain.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: TravelloTheme.primaryMain, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            hotel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: TravelloTheme.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotel.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 12,
                          color: colorScheme(context)
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 2),
                      Text(
                        hotel.city,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme(context)
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${hotel.reviewCount >= 1000 ? '${(hotel.reviewCount / 1000).toStringAsFixed(1)}k' : hotel.reviewCount} reviews)',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme(context)
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: hotel.amenities
                        .take(3)
                        .map((a) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: TravelloTheme.primaryMain
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: TravelloTheme.primaryDark
                                      .withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: TravelloTheme.primaryDark,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PKR ${hotel.pricePerNight >= 1000 ? '${(hotel.pricePerNight / 1000).toStringAsFixed(0)}k' : hotel.pricePerNight}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: TravelloTheme.primaryDark,
                        ),
                      ),
                      Text(
                        '/night',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme(context)
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HOTEL SECTION 3 — EXPLORE PAKISTAN DESTINATIONS
// ═══════════════════════════════════════════════════════════════════════════
class _HotelExplorePakistanSection extends StatefulWidget {
  final void Function(String city) onCityTap;
  const _HotelExplorePakistanSection({required this.onCityTap});

  @override
  State<_HotelExplorePakistanSection> createState() =>
      _HotelExplorePakistanSectionState();
}

class _HotelExplorePakistanSectionState
    extends State<_HotelExplorePakistanSection> {
  final ScrollController _scroll = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      setState(() {
        _canScrollLeft = _scroll.offset > 8;
        _canScrollRight = _scroll.offset < _scroll.position.maxScrollExtent - 8;
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  static const _destinations = [
    {
      'city': 'Lahore',
      'properties': 2250,
      'image':
          'https://images.unsplash.com/photo-1587474260584-136574528ed5?w=400'
    },
    {
      'city': 'Islamabad',
      'properties': 2722,
      'image':
          'https://images.unsplash.com/photo-1548013146-72479768bada?w=400&q=80'
    },
    {
      'city': 'Karachi',
      'properties': 943,
      'image':
          'https://images.unsplash.com/photo-1529253355930-ddbe423a2ac7?w=400'
    },
    {
      'city': 'Rawalpindi',
      'properties': 960,
      'image':
          'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=400'
    },
    {
      'city': 'Peshawar',
      'properties': 64,
      'image': 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400'
    },
    {
      'city': 'Bhurban',
      'properties': 80,
      'image':
          'https://images.unsplash.com/photo-1574615552267-e8516b7aade0?w=400'
    },
    {
      'city': 'Sialkot',
      'properties': 10,
      'image': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400'
    },
    {
      'city': 'Muzaffarabad',
      'properties': 67,
      'image':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400'
    },
    {
      'city': 'Multan',
      'properties': 80,
      'image':
          'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=400'
    },
    {
      'city': 'Quetta',
      'properties': 45,
      'image': 'https://images.unsplash.com/photo-1549880338-65ddcdfd017b?w=400'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explore Pakistan',
                style:
                    TravelloTheme.title2.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Find your perfect stay across Pakistan\'s finest cities',
                style: TravelloTheme.caption
                    .copyWith(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 264,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                itemCount: _destinations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final d = _destinations[i];
                  return GestureDetector(
                    onTap: () => widget.onCityTap(d['city'] as String),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                d['image'] as String,
                                width: 200,
                                height: 178,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 200,
                                  height: 178,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.location_city,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(d['city'] as String,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                              '${fmt.format(d['properties'] as int)} properties',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_canScrollLeft)
              Positioned(
                left: 4,
                child: _ScrollArrow(
                  icon: Icons.chevron_left,
                  onTap: () => _scrollBy(-500),
                ),
              ),
            if (_canScrollRight)
              Positioned(
                right: 4,
                child: _ScrollArrow(
                  icon: Icons.chevron_right,
                  onTap: () => _scrollBy(500),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AMENITY BADGE — used by _HotelWeekendDealCard
// ═══════════════════════════════════════════════════════════════════════════
class _AmenityBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _AmenityBadge(
      {required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: textColor, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      );
}
