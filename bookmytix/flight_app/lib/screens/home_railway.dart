import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/widgets/bottom_navigation/bottom_nav_menu.dart';
import 'package:flight_app/widgets/home/city_destinations/city_destinations_main.dart';
import 'package:flight_app/widgets/home/flight_list_double.dart';
import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flight_app/widgets/home/quick_access_features.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HomeRailway extends StatefulWidget {
  const HomeRailway({super.key});

  @override
  State<HomeRailway> createState() => _HomeRailwayState();
}

class _HomeRailwayState extends State<HomeRailway> {
  String _userName = 'User';
  String _userAvatar = '';
  String _userCountry = 'Pakistan';
  bool _isFixed = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _isFixed = _scrollController.offset > 60;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final isGuest = await AuthService.isGuestMode();

    if (isGuest) {
      final guestUser = AuthService.getGuestUser();
      setState(() {
        _userName = guestUser['name'];
        _userAvatar = '';
        _userCountry = 'Visitor';
      });
    } else {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _userName = user['name'] ?? 'User';
          _userAvatar = userDummy.avatar;
          _userCountry = 'Pakistan';
        });
      } else {
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
    final String avatarUrl =
        (_userAvatar.isEmpty ? userDummy.avatar : _userAvatar).trim();

    return Scaffold(
      bottomNavigationBar: const SafeArea(top: false, child: BottomNavMenu()),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar with Header
            SliverAppBar(
              expandedHeight: 450,
              floating: false,
              pinned: true,
              toolbarHeight: 60,
              scrolledUnderElevation: 0.0,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              titleSpacing: 8,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(ImgApi.railwayBanner),
                      alignment: const Alignment(0, -0.3),
                      fit: BoxFit.cover,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade700.withValues(alpha: 0.7),
                        Colors.green.shade400.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: spacingUnit(8)),
                          const Text(
                            'Where do you want to go?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  Get.toNamed(AppLink.profile);
                },
                child: Row(children: [
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
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName,
                            style: TravelloTheme.title2.copyWith(
                                color: _isFixed
                                    ? colorScheme(context).onSurface
                                    : Colors.white)),
                        Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: ThemeRadius.small,
                              color: TravelloTheme.paperLight
                                  .withValues(alpha: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 12, color: Colors.red),
                                const SizedBox(width: 2),
                                Text('Karachi • $_userCountry',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ))
                      ])
                ]),
              ),
              actions: [
                _iconBtn(
                  context,
                  Icons.flight,
                  _isFixed,
                  () => _showModeSwitch(context),
                ),
                Obx(() {
                  final ctrl = Get.find<NotificationController>();
                  final n = ctrl.unreadCount.value;
                  return Badge.count(
                    backgroundColor: TravelloTheme.primaryMain,
                    textColor: Colors.black,
                    count: n,
                    isLabelVisible: n > 0,
                    offset: const Offset(0, -1),
                    child: _iconBtn(
                      context,
                      Icons.notifications,
                      _isFixed,
                      () {
                        Get.toNamed(AppLink.notification);
                      },
                    ),
                  );
                }),
                Tooltip(
                  message: 'Help and Support',
                  child: _iconBtn(
                    context,
                    Icons.chat_bubble_outline,
                    _isFixed,
                    () {
                      Get.toNamed(AppLink.faq);
                    },
                  ),
                )
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Book Your Train Button - Professional Design
                  Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width > 1200
                            ? 800
                            : double.infinity,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade700,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Get.toNamed('/train-search-home');
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.train,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Book Your Train',
                                        style: TravelloTheme.title2.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Search trains & reserve your seat',
                                        style: TravelloTheme.caption.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: Colors.green.shade700,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Access Features
                  const QuickAccessFeatures(),

                  const SizedBox(height: 24),

                  // Popular Destinations
                  const CityDestinations(),

                  const VSpaceBig(),

                  // Featured Packages
                  const PackageListSlider(),

                  const VSpaceBig(),

                  // Top Destinations
                  const FlightListDouble(),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, bool isFixed,
      void Function() onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(32)),
            color: isFixed
                ? colorScheme(context).outline
                : TravelloTheme.paperLight),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            size: 24,
            color: colorScheme(context).onSurface,
          ),
        ),
      ),
    );
  }

  void _showModeSwitch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('travel_mode', 'airline');
    Get.offAllNamed(AppLink.home);
  }
}
