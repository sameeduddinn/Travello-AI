import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/train_package.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:flight_app/widgets/cards/train_package_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

/// Featured train packages slider - DYNAMIC based on user's city
class TrainPackageSlider extends StatefulWidget {
  const TrainPackageSlider({super.key});

  @override
  State<TrainPackageSlider> createState() => _TrainPackageSliderState();
}

class _TrainPackageSliderState extends State<TrainPackageSlider> {
  final ScrollController _scrollController = ScrollController();
  String _userOriginCityName = 'Karachi';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserOriginCity();
  }

  /// Fetch user's selected origin city
  Future<void> _loadUserOriginCity() async {
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _userOriginCityName = cityData['cityName']!;
        _isLoading = false;
      });
    }
  }

  /// Filter packages FROM user's city.
  /// Rawalpindi station serves Islamabad (no PR station in ISB).
  List<TrainPackage> get _relevantPackages {
    final lowerCity = _userOriginCityName.toLowerCase();
    final isRWPZone = lowerCity == 'islamabad' || lowerCity == 'rawalpindi';
    return featuredTrainPackages
        .where((pkg) {
          final fromLower = pkg.fromStation.toLowerCase();
          if (isRWPZone) {
            return fromLower.contains('rawalpindi') ||
                fromLower.contains('islamabad');
          }
          return fromLower.contains(lowerCity);
        })
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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
        padding: EdgeInsets.all(R.r(context, 16)),
        child: Container(
          padding: EdgeInsets.all(R.r(context, 24)),
          decoration: BoxDecoration(
            color: TravelloTheme.paperLightContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.train_outlined,
                size: R.r(context, 48),
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
                'Check flight options or search for other routes',
                style: TextStyle(
                  fontSize: R.sp(context, 12),
                  color: colorScheme(context).onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final viewportWidth = constraints.maxWidth;
      final isDesktop = viewportWidth > 1200;
      final horizontalPadding = isDesktop ? spacingUnit(8) : R.r(context, 16);
      final usableWidth =
          (viewportWidth - (horizontalPadding * 2)).clamp(0.0, viewportWidth);
      final cardWidth = isDesktop
          ? 320.0
          : (usableWidth * 0.86).clamp(280.0, 320.0).toDouble();
      const cardHeight = 220.0;
      final scrollStep = cardWidth + 16;
      final showArrows = viewportWidth >= 950;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: TitleAction(
              title: 'Featured Packages',
              textAction: 'See All',
              onTap: () {
                Get.toNamed(AppLink.trainPackageAll);
              },
            ),
          ),
          SizedBox(height: R.rh(context, 16)),
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
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    itemCount: packageList.length,
                    itemBuilder: (context, index) {
                      final item = packageList[index];

                      return _TrainCardHover(
                        packageId: item.id,
                        itemData: {
                          'id': item.id,
                          'name': item.name,
                          'train_number': item.trainNumber,
                          'from': item.fromStation,
                          'to': item.toStation,
                          'departure_time': item.departureTime,
                          'duration': item.duration,
                          'class': item.trainClass,
                          'price': item.price,
                          'round_trip': item.roundTrip,
                          'image': item.imageUrl,
                        },
                        onTap: () {
                          Get.toNamed(
                            AppLink.trainDetailPackage,
                            arguments: {
                              'package': item,
                              'departDate':
                                  DateTime.now().add(Duration(days: 7 + index)),
                            },
                          );
                        },
                        child: SizedBox(
                          width: cardWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: TrainPackageCard(
                              image: item.imageUrl,
                              label: _getDiscountLabel(item),
                              trainName: item.name,
                              trainNumber: item.trainNumber,
                              from: _getShortStationName(item.fromStation),
                              to: _getShortStationName(item.toStation),
                              date: _getDateString(item, index),
                              duration: item.duration,
                              tags: [
                                ...item.amenities
                                    .where((a) =>
                                        !a.toLowerCase().contains('meal'))
                                    .take(1),
                                _getDiscountTag(item),
                              ],
                              price: item.price,
                              trainClass: item.trainClass,
                              roundTrip: item.roundTrip,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showArrows) ...[
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              TravelloTheme.paperLight.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => _scrollBy(-scrollStep),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: TravelloTheme.primaryMain,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              TravelloTheme.paperLight.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => _scrollBy(scrollStep),
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: TravelloTheme.primaryMain,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  String _getDateString(TrainPackage pkg, int index) {
    // Show upcoming departure date — trip type shown via badge, time in train info
    final base = DateTime.now().add(Duration(days: 7 + index));
    return DateFormat('d MMM yyyy').format(base);
  }

  String _getDiscountLabel(TrainPackage package) {
    switch (package.packageType) {
      case 'business':
        return '30%\nOFF';
      case 'sleeper':
        return '20%\nOFF';
      case 'express':
        return '15%\nOFF';
      default:
        return '10%\nOFF';
    }
  }

  String _getDiscountTag(TrainPackage package) {
    switch (package.packageType) {
      case 'business':
        return '30% OFF';
      case 'sleeper':
        return '20% OFF';
      case 'express':
        return '15% OFF';
      default:
        return '10% OFF';
    }
  }

  String _getShortStationName(String fullName) {
    // Shorten station names like "Karachi Cantt" -> "Karachi"
    return fullName.split(' ').first;
  }
}

class _TrainCardHover extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String packageId;
  final Map<String, dynamic>? itemData;
  const _TrainCardHover(
      {required this.child,
      required this.onTap,
      required this.packageId,
      this.itemData});

  @override
  State<_TrainCardHover> createState() => _TrainCardHoverState();
}

class _TrainCardHoverState extends State<_TrainCardHover>
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
    final liked = await WishlistService.isLiked('train', widget.packageId);
    if (mounted) setState(() => _wishlisted = liked);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final added = await WishlistService.toggle(
        'train', widget.packageId,
        itemData: widget.itemData);
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
