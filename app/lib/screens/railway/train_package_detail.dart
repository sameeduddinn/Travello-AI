import 'dart:math';

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/models/train_package.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:flight_app/widgets/cards/train_package_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8935C);

class TrainPackageDetail extends StatefulWidget {
  const TrainPackageDetail({super.key});

  @override
  State<TrainPackageDetail> createState() => _TrainPackageDetailState();
}

class _TrainPackageDetailState extends State<TrainPackageDetail> {
  String _selectedFilter = 'All';
  String _userOriginCityName = 'Karachi';
  bool _isLoading = true;
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserOriginCity();
  }

  Future<void> _loadUserOriginCity() async {
    final isGuest = await AuthService.isGuestMode();
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _userOriginCityName = cityData['cityName']!;
        _isLoading = false;
      });
    }
  }

  /// Packages filtered by user's selected home city (same logic as train_package_slider)
  List<TrainPackage> get _cityPackages {
    if (_isGuestMode) {
      final seed = DateTime.now().day * 31 + DateTime.now().month;
      final rng = Random(seed);
      final all = List<TrainPackage>.from(featuredTrainPackages);
      all.shuffle(rng);
      return all;
    }
    final lowerCity = _userOriginCityName.toLowerCase();
    final isRWPZone = lowerCity == 'islamabad' || lowerCity == 'rawalpindi';
    return featuredTrainPackages.where((pkg) {
      final fromLower = pkg.fromStation.toLowerCase();
      if (isRWPZone) {
        return fromLower.contains('rawalpindi') ||
            fromLower.contains('islamabad');
      }
      return fromLower.contains(lowerCity);
    }).toList();
  }

  /// Apply One-Way / Round-Trip filter on top of city packages
  List<TrainPackage> get _filtered {
    final base = _cityPackages;
    if (_selectedFilter == 'One-Way') {
      return base.where((p) => !p.roundTrip).toList();
    }
    if (_selectedFilter == 'Round-Trip') {
      return base.where((p) => p.roundTrip).toList();
    }
    return base;
  }

  String get _appBarTitle {
    if (_isLoading || _isGuestMode) return 'Featured Train Packages';
    return 'Train Packages from $_userOriginCityName';
  }

  String _getDiscountLabel(TrainPackage pkg) {
    switch (pkg.packageType) {
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

  String _getDiscountTag(TrainPackage pkg) {
    switch (pkg.packageType) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _gold,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                  ),
                  title: Text(_appBarTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(52),
                    child: _buildFilterBar(),
                  ),
                ),

                // ── City banner (logged-in users only) ────────────────────
                if (!_isGuestMode)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 0),
                      child: _buildCityBanner(),
                    ),
                  ),

                // ── Stats row ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 0),
                    child: _buildStatsRow(),
                  ),
                ),

                // ── Package list ──────────────────────────────────────────
                _filtered.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty())
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _filtered[index];
                              final departDate =
                                  DateTime.now().add(Duration(days: 7 + index));

                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 16),
                                child: _TrainPackageCardItem(
                                  package: item,
                                  departDate: departDate,
                                  discountLabel: _getDiscountLabel(item),
                                  discountTag: _getDiscountTag(item),
                                  onTap: () => Get.toNamed(
                                    AppLink.trainDetailPackage,
                                    arguments: {
                                      'package': item,
                                      'departDate': departDate,
                                    },
                                  ),
                                ),
                              );
                            },
                            childCount: _filtered.length,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildCityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 9.6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.train, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing trains departing from $_userOriginCityName',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _gold,
      padding: const EdgeInsets.fromLTRB(
          16, 0, 16, 12),
      child: Row(children: [
        _filterChip('All'),
        const SizedBox(width: 8),
        _filterChip('One-Way'),
        const SizedBox(width: 8),
        _filterChip('Round-Trip'),
      ]),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? _goldDark : Colors.white,
            )),
      ),
    );
  }

  Widget _buildStatsRow() {
    final base = _cityPackages;
    final total = base.length;
    final oneWay = base.where((p) => !p.roundTrip).length;
    final roundTrip = base.where((p) => p.roundTrip).length;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statItem('$total', 'Total', Icons.train_outlined),
        _divider(),
        _statItem('$oneWay', 'One-Way', Icons.arrow_right_alt),
        _divider(),
        _statItem('$roundTrip', 'Round-Trip', Icons.swap_horiz),
      ]),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, size: 18, color: _gold),
      SizedBox(height: spacingUnit(0.3)),
      Text(value,
          style: TextStyle(
              fontSize: R.sp(context, 20),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827))),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
    ]);
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: const Color(0xFFE5E7EB));

  Widget _buildEmpty() {
    return NoData(
      image: ImgApi.emptyNotFound,
      title: 'No Train Packages Found',
      desc:
          'No train packages available from $_userOriginCityName right now. Try updating your home city in Settings.',
      primaryTxtBtn: 'GO TO SETTINGS',
      primaryAction: () => Get.toNamed(AppLink.profile),
      secondaryTxtBtn: 'BACK TO HOME',
      secondaryAction: () => Get.toNamed(AppLink.home),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Train package card with persistent wishlist heart
// ═══════════════════════════════════════════════════════════════════════════
class _TrainPackageCardItem extends StatefulWidget {
  final TrainPackage package;
  final DateTime departDate;
  final String discountLabel;
  final String discountTag;
  final VoidCallback onTap;

  const _TrainPackageCardItem({
    required this.package,
    required this.departDate,
    required this.discountLabel,
    required this.discountTag,
    required this.onTap,
  });

  @override
  State<_TrainPackageCardItem> createState() => _TrainPackageCardItemState();
}

class _TrainPackageCardItemState extends State<_TrainPackageCardItem>
    with SingleTickerProviderStateMixin {
  bool _wishlisted = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  static String _shortStation(String full) => full.split(' ').first;

  String get _dateStr {
    return '${DateFormat('d MMM yyyy').format(widget.departDate)} · ${widget.package.departureTime}';
  }

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
    final liked = await WishlistService.isLiked('train', widget.package.id);
    if (mounted) setState(() => _wishlisted = liked);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final added = await WishlistService.toggle('train', widget.package.id,
        itemData: {
          'id': widget.package.id,
          'name': widget.package.name,
          'fromStation': widget.package.fromStation,
          'toStation': widget.package.toStation,
          'price': widget.package.price,
          'imageUrl': widget.package.imageUrl,
          'trainClass': widget.package.trainClass,
          'departureTime': widget.package.departureTime,
        });
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            child: TrainPackageCard(
              image: widget.package.imageUrl,
              label: widget.discountLabel,
              trainName: widget.package.name,
              trainNumber: widget.package.trainNumber,
              from: _shortStation(widget.package.fromStation),
              to: _shortStation(widget.package.toStation),
              date: _dateStr,
              duration: widget.package.duration,
              tags: [
                ...widget.package.amenities
                    .where((a) => !a.toLowerCase().contains('meal'))
                    .take(1),
                widget.discountTag,
              ],
              price: widget.package.price,
              trainClass: widget.package.trainClass,
              roundTrip: widget.package.roundTrip,
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
                        color: Colors.black.withValues(alpha: 0.12),
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
