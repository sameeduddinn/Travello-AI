import 'dart:math';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/models/flight_package.dart';
import 'package:flight_app/widgets/cards/package_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PackageListSlider extends StatefulWidget {
  const PackageListSlider({super.key});

  @override
  State<PackageListSlider> createState() => _PackageListSliderState();
}

class _PackageListSliderState extends State<PackageListSlider> {
  final ScrollController _scrollController = ScrollController();
  String _userOriginCityCode = 'KHI';
  String _userOriginCityName = 'Karachi';
  bool _isLoading = true;
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserOriginCity();
  }

  /// Fetch user's selected origin city
  Future<void> _loadUserOriginCity() async {
    final isGuest = await AuthService.isGuestMode();
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _userOriginCityCode = cityData['cityCode']!;
        _userOriginCityName = cityData['cityName']!;
        _isLoading = false;
      });
    }
  }

  /// Filter packages FROM user's city.
  /// ISB airport (IATA: ISB) serves both Islamabad and Rawalpindi.
  List<FlightPackage> get _relevantPackages {
    if (_isGuestMode) {
      // Guest: show a daily-shuffled mix from all cities
      final seed = DateTime.now().day * 31 + DateTime.now().month;
      final rng = Random(seed);
      final all = List<FlightPackage>.from(flightPackageList);
      all.shuffle(rng);
      return all.take(8).toList();
    }
    final lowerCity = _userOriginCityName.toLowerCase();
    final isISBZone = lowerCity == 'islamabad' || lowerCity == 'rawalpindi';
    return flightPackageList
        .where((pkg) {
          final fromName = pkg.from.name.toLowerCase();
          if (isISBZone) {
            return fromName == 'islamabad' ||
                fromName == 'rawalpindi' ||
                pkg.from.code == 'ISB' ||
                pkg.from.code == 'RWP';
          }
          return fromName.contains(lowerCity) ||
              pkg.from.code == _userOriginCityCode;
        })
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 320,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 320,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Route duration lookup — matches the schedule map in flight_detail_package.
  static const Map<String, String> _durationMap = {
    'Karachi-Lahore': '1h 30m',
    'Lahore-Karachi': '1h 30m',
    'Karachi-Islamabad': '2h 00m',
    'Islamabad-Karachi': '2h 00m',
    'Karachi-Rawalpindi': '2h 00m',
    'Rawalpindi-Karachi': '2h 00m',
    'Karachi-Peshawar': '2h 15m',
    'Peshawar-Karachi': '2h 15m',
    'Karachi-Multan': '1h 15m',
    'Multan-Karachi': '1h 15m',
    'Karachi-Quetta': '1h 30m',
    'Quetta-Karachi': '1h 30m',
    'Karachi-Faisalabad': '1h 30m',
    'Faisalabad-Karachi': '1h 30m',
    'Karachi-Sialkot': '1h 30m',
    'Sialkot-Karachi': '1h 30m',
    'Karachi-Gwadar': '1h 10m',
    'Gwadar-Karachi': '1h 10m',
    'Karachi-Gilgit': '2h 30m',
    'Gilgit-Karachi': '2h 30m',
    'Karachi-Skardu': '2h 30m',
    'Skardu-Karachi': '2h 30m',
    'Lahore-Islamabad': '0h 50m',
    'Islamabad-Lahore': '0h 50m',
    'Lahore-Rawalpindi': '0h 50m',
    'Rawalpindi-Lahore': '0h 50m',
    'Lahore-Peshawar': '1h 10m',
    'Peshawar-Lahore': '1h 10m',
    'Lahore-Multan': '1h 00m',
    'Multan-Lahore': '1h 00m',
    'Lahore-Quetta': '2h 00m',
    'Quetta-Lahore': '2h 00m',
    'Lahore-Faisalabad': '1h 00m',
    'Faisalabad-Lahore': '1h 00m',
    'Lahore-Sialkot': '0h 45m',
    'Sialkot-Lahore': '0h 45m',
    'Lahore-Gilgit': '1h 45m',
    'Gilgit-Lahore': '1h 45m',
    'Lahore-Skardu': '2h 00m',
    'Skardu-Lahore': '2h 00m',
    'Lahore-Gwadar': '2h 30m',
    'Gwadar-Lahore': '2h 30m',
    'Islamabad-Peshawar': '0h 45m',
    'Peshawar-Islamabad': '0h 45m',
    'Islamabad-Multan': '1h 15m',
    'Multan-Islamabad': '1h 15m',
    'Islamabad-Quetta': '1h 45m',
    'Quetta-Islamabad': '1h 45m',
    'Islamabad-Gilgit': '1h 30m',
    'Gilgit-Islamabad': '1h 30m',
    'Islamabad-Skardu': '1h 30m',
    'Skardu-Islamabad': '1h 30m',
    'Islamabad-Gwadar': '2h 15m',
    'Gwadar-Islamabad': '2h 15m',
    'Peshawar-Multan': '1h 15m',
    'Multan-Peshawar': '1h 15m',
    'Peshawar-Quetta': '2h 30m',
    'Quetta-Peshawar': '2h 30m',
    'Faisalabad-Islamabad': '1h 00m',
    'Islamabad-Faisalabad': '1h 00m',
    'Sialkot-Islamabad': '1h 00m',
    'Islamabad-Sialkot': '1h 00m',
    // ── Additional / legacy routes ─────────────────────────────────────
    'Rawalpindi-Peshawar': '0h 30m',
    'Peshawar-Rawalpindi': '0h 30m',
    'Multan-Faisalabad': '0h 30m',
    'Faisalabad-Multan': '0h 30m',
    'Faisalabad-Hyderabad': '1h 30m',
    'Hyderabad-Faisalabad': '1h 30m',
    'Hyderabad-Karachi': '0h 45m',
    'Karachi-Hyderabad': '0h 45m',
    'Hyderabad-Bahawalpur': '1h 15m',
    'Bahawalpur-Hyderabad': '1h 15m',
    'Sukkur-Sialkot': '1h 45m',
    'Sialkot-Sukkur': '1h 45m',
    'Sukkur-Karachi': '1h 00m',
    'Karachi-Sukkur': '1h 00m',
    'Bahawalpur-Gujranwala': '1h 00m',
    'Gujranwala-Bahawalpur': '1h 00m',
    'Gujranwala-Sialkot': '0h 25m',
    'Sialkot-Gujranwala': '0h 25m',
    'Sialkot-Gwadar': '2h 15m',
    'Gwadar-Sialkot': '2h 15m',
    'Sargodha-Sahiwal': '0h 30m',
    'Sahiwal-Sargodha': '0h 30m',
    'Sahiwal-Gwadar': '2h 00m',
    'Gwadar-Sahiwal': '2h 00m',
    'Gwadar-Gilgit': '2h 15m',
    'Gilgit-Gwadar': '2h 15m',
    'Gilgit-Murree': '0h 30m',
    'Murree-Gilgit': '0h 30m',
    'Skardu-Murree': '0h 45m',
    'Murree-Skardu': '0h 45m',
    'Murree-Nawabshah': '2h 00m',
    'Nawabshah-Murree': '2h 00m',
    'Nawabshah-Karachi': '1h 00m',
    'Karachi-Nawabshah': '1h 00m',
    'D.I. Khan-Chitral': '0h 45m',
    'Chitral-D.I. Khan': '0h 45m',
    'D.I. Khan-Turbat': '2h 00m',
    'Turbat-D.I. Khan': '2h 00m',
    'D.I. Khan-Islamabad': '0h 45m',
    'Islamabad-D.I. Khan': '0h 45m',
    'D.I. Khan-Jacobabad': '1h 15m',
    'Jacobabad-D.I. Khan': '1h 15m',
  };

  String _getFlightDuration(String fromName, String toName) =>
      _durationMap['$fromName-$toName'] ?? '';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            color: TravelloTheme.primaryMain,
          ),
        ),
      );
    }

    final packageList = _relevantPackages;

    // Show message if no packages from user's city
    if (packageList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TravelloTheme.paperLightContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.flight_takeoff_outlined,
                size: 48,
                color: TravelloTheme.primaryMain.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No featured packages from $_userOriginCityName yet',
                style: TextStyle(
                  color: colorScheme(context).onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Search for flights to explore all available routes',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme(context).onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    const double cardWidth = 300;
    const double cardHeight = 220;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? spacingUnit(8) : 16),
        child: TitleAction(
            title: 'Featured Packages',
            textAction: 'See All',
            onTap: () {
              Get.toNamed(AppLink.promoDetail);
            }),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: cardHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? spacingUnit(8) : 16),
                  itemCount: packageList.length,
                  itemBuilder: ((context, index) {
                    FlightPackage item = packageList[index];
                    final departDate =
                        DateTime.now().add(Duration(days: 30 + index * 2));
                    final returnDate = item.roundTrip
                        ? departDate.add(const Duration(days: 2))
                        : null;
                    final dateStr = item.roundTrip
                        ? '${DateFormat('d').format(departDate)} - ${DateFormat('d MMM yyyy').format(returnDate!)}'
                        : DateFormat('d MMM yyyy').format(departDate);

                    return _FlightCardHover(
                      packageId: item.id,
                      onTap: () {
                        // Detail page is FREE — auth gate only at BOOK NOW inside detail
                        Get.toNamed(AppLink.flightDetailPackage, arguments: {
                          'package': item,
                          'departDate': departDate,
                          'returnDate': returnDate,
                        });
                      },
                      child: SizedBox(
                          width: cardWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: PackageCard(
                                image: item.img,
                                label: item.label!,
                                from: item.from.name,
                                to: item.to.name,
                                date: dateStr,
                                duration: _getFlightDuration(
                                    item.from.name, item.to.name),
                                tags: [
                                  item.plane.classType,
                                  if (item.tags != null &&
                                      item.tags!.length > 1)
                                    item.tags![1],
                                ],
                                price: item.price,
                                plane: item.plane,
                                roundTrip: item.roundTrip),
                          )),
                    );
                  })),
            ),
            if (isDesktop) ...[
              Positioned(
                left: 16,
                top: 80,
                child: Container(
                  decoration: BoxDecoration(
                    color: TravelloTheme.paperLight.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _scrollLeft,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: TravelloTheme.primaryMain,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 80,
                child: Container(
                  decoration: BoxDecoration(
                    color: TravelloTheme.paperLight.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _scrollRight,
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: TravelloTheme.primaryMain,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

class _FlightCardHover extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String packageId;
  const _FlightCardHover(
      {required this.child, required this.onTap, required this.packageId});

  @override
  State<_FlightCardHover> createState() => _FlightCardHoverState();
}

class _FlightCardHoverState extends State<_FlightCardHover>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _wishlisted = false;
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
    _loadState();
  }

  Future<void> _loadState() async {
    final liked = await WishlistService.isLiked('flight', widget.packageId);
    if (mounted) setState(() => _wishlisted = liked);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final added = await WishlistService.toggle('flight', widget.packageId);
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _hovered ? 1.025 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ),
          Positioned(
            top: 8,
            right: 22,
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4),
                  ],
                ),
                child: ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    _wishlisted ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: _wishlisted ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
