import 'dart:math';

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8935C);

class HotelPackageDetail extends StatefulWidget {
  const HotelPackageDetail({super.key});

  @override
  State<HotelPackageDetail> createState() => _HotelPackageDetailState();
}

class _HotelPackageDetailState extends State<HotelPackageDetail> {
  String _selectedFilter = 'All';
  String _userOriginCityName = 'Karachi';
  bool _isLoading = true;
  bool _isGuestMode = false;

  DateTime _checkIn = DateTime.now().add(const Duration(days: 3));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 5));

  // BUG 1 FIX: derive nights from actual dates instead of hardcoding
  int get _nights => _checkOut.difference(_checkIn).inDays;

  @override
  void initState() {
    super.initState();
    // BUG 2 FIX: pick up dates passed from HotelSearchScreen if available
    final args = Get.arguments ?? {};
    if (args['checkInDate'] != null) _checkIn = args['checkInDate'] as DateTime;
    if (args['checkOutDate'] != null) {
      _checkOut = args['checkOutDate'] as DateTime;
    }
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
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

  /// Hotels matching user's city; guests see a daily-shuffled mix
  List<Hotel> get _cityHotels {
    if (_isGuestMode) {
      final seed = DateTime.now().day * 31 + DateTime.now().month;
      final rng = Random(seed);
      final all = List<Hotel>.from(PakistanHotels.getHotels(''));
      all.shuffle(rng);
      return all;
    }
    final fromCity = PakistanHotels.getHotels(_userOriginCityName);
    // Fallback: if no hotels for city, show all
    return fromCity.isNotEmpty ? fromCity : PakistanHotels.getHotels('');
  }

  List<Hotel> get _filtered {
    final base = _cityHotels;
    switch (_selectedFilter) {
      case '5-Star':
        return base.where((h) => h.category.contains('5')).toList();
      case '4-Star':
        return base.where((h) => h.category.contains('4')).toList();
      case '3-Star':
        return base.where((h) => h.category.contains('3')).toList();
      default:
        return base;
    }
  }

  String get _appBarTitle {
    if (_isLoading || _isGuestMode) return 'Featured Hotel Packages';
    return 'Hotels in $_userOriginCityName';
  }

  int _discountFor(int index) {
    if (index % 3 == 0) return 20;
    if (index % 3 == 1) return 15;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────
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

                // ── City banner (logged-in users only) ────────────────
                if (!_isGuestMode)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildCityBanner(),
                    ),
                  ),

                // ── Stats row ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildStatsRow(),
                  ),
                ),

                // ── Hotel cards list ──────────────────────────────────
                _filtered.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty())
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final h = _filtered[index];
                              final discountPct = _discountFor(index);
                              final origPrice = h.pricePerNight * _nights;
                              final finalPrice =
                                  origPrice * (1 - discountPct / 100);
                              // BUG 3 FIX: default guests to 1, not random index-based
                              const guestCount = 1;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _HotelDealCard(
                                  hotel: h,
                                  nights: _nights,
                                  guests: guestCount,
                                  originalPrice: origPrice,
                                  finalPrice: finalPrice,
                                  discountPct: discountPct,
                                  onTap: () => Get.toNamed(
                                    AppLink.hotelDetail,
                                    arguments: {
                                      'hotel': h,
                                      'checkInDate': _checkIn,
                                      'checkOutDate': _checkOut,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9.6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.location_on, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing hotels in $_userOriginCityName',
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        _filterChip('All'),
        const SizedBox(width: 8),
        _filterChip('5-Star'),
        const SizedBox(width: 8),
        _filterChip('4-Star'),
        const SizedBox(width: 8),
        _filterChip('3-Star'),
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
    final base = _cityHotels;
    final total = base.length;
    final fiveStar = base.where((h) => h.category.contains('5')).length;
    final fourStar = base.where((h) => h.category.contains('4')).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statItem('$total', 'Total', Icons.hotel_outlined),
        _divider(),
        _statItem('$fiveStar', '5-Star', Icons.star),
        _divider(),
        _statItem('$fourStar', '4-Star', Icons.star_half),
      ]),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Column(children: [
      Icon(icon, size: 18, color: _gold),
      SizedBox(height: spacingUnit(0.3)),
      Text(value,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827))),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
    ]);
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: const Color(0xFFE5E7EB));

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.hotel_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('No hotels found in $_userOriginCityName',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        const Text('Try updating your home city in Settings',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hotel deal card — full-width list version
// ═══════════════════════════════════════════════════════════════════════════
class _HotelDealCard extends StatefulWidget {
  final Hotel hotel;
  final int nights;
  final int guests;
  final double originalPrice;
  final double finalPrice;
  final int discountPct;
  final VoidCallback onTap;

  const _HotelDealCard({
    required this.hotel,
    required this.nights,
    required this.guests,
    required this.originalPrice,
    required this.finalPrice,
    required this.discountPct,
    required this.onTap,
  });

  @override
  State<_HotelDealCard> createState() => _HotelDealCardState();
}

class _HotelDealCardState extends State<_HotelDealCard>
    with SingleTickerProviderStateMixin {
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
        Get.snackbar(
          'Saved',
          'Added to Saved',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF1A1A1A),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
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

  int _starsFor(String cat) {
    if (cat.contains('5')) return 5;
    if (cat.contains('4')) return 4;
    if (cat.contains('3')) return 3;
    // BUG 5 FIX: Budget hotels get 0 stars, not 2
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final h = widget.hotel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Image ──────────────────────────────────────────────
                SizedBox(
                  width: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: h.images.isNotEmpty
                            ? Image.network(h.images.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.hotel,
                                          size: 32, color: Colors.grey),
                                    ))
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.hotel,
                                    size: 32, color: Colors.grey),
                              ),
                      ),
                      // Discount badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('-${widget.discountPct}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // Wishlist
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: _toggleWishlist,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: ScaleTransition(
                              scale: _heartScale,
                              child: Icon(
                                _wishlisted
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
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
                ),

                // ── Info ───────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stars + category
                        Row(children: [
                          ...List.generate(
                            _starsFor(h.category),
                            (_) =>
                                const Icon(Icons.star, size: 11, color: _gold),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: _gold.withValues(alpha: 0.35)),
                            ),
                            child: Text(h.category,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(h.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A))),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${h.city} · ${h.distanceFromCenter.toStringAsFixed(1)} km from centre',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Rating
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _ratingColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${h.rating}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Text(_ratingLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A))),
                          const SizedBox(width: 4),
                          Text(
                              '${NumberFormat('#,##0').format(h.totalReviews)} reviews',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ]),
                        const SizedBox(height: 6),
                        // Amenity chips
                        Wrap(spacing: 4, runSpacing: 4, children: [
                          if (h.isRefundable)
                            const _AmenityBadge(
                                label: 'Free Cancellation',
                                color: Color(0xFF2E7D32)),
                          if (h.hasBreakfast)
                            const _AmenityBadge(
                                label: 'Breakfast ✓', color: Color(0xFF1565C0)),
                        ]),
                        const SizedBox(height: 8),
                        // Price
                        Text('Per night',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // BUG 4 FIX: use pre-computed per-night discounted price
                              // = finalPrice / nights  (avoids double-computing)
                              Text(
                                'PKR ${fmt.format(widget.finalPrice / widget.nights)}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _gold),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PKR ${fmt.format(h.pricePerNight)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough),
                              ),
                            ]),
                        Text(
                          'PKR ${fmt.format(widget.finalPrice)} total · ${widget.nights} nights · ${widget.guests} guest',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
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

class _AmenityBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AmenityBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
