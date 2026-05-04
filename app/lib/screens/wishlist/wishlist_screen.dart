import 'dart:async';

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/flight_package.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/models/train_package.dart';
import 'package:flight_app/utils/wishlist_service.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';

const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8935C);
const _bg = Color(0xFFF9F5E8);

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Set<String> _hotelIds = {};
  Set<String> _flightIds = {};
  Set<String> _trainIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    await WishlistService.syncFromBackend();
    final h = await WishlistService.getAll('hotel');
    final f = await WishlistService.getAll('flight');
    final t = await WishlistService.getAll('train');
    if (mounted) {
      setState(() {
        _hotelIds = h;
        _flightIds = f;
        _trainIds = t;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Hotel> get _savedHotels {
    final all = PakistanHotels.getHotels('');
    return all.where((h) => _hotelIds.contains(h.id)).toList();
  }

  List<FlightPackage> get _savedFlights {
    return flightPackageList.where((f) => _flightIds.contains(f.id)).toList();
  }

  List<TrainPackage> get _savedTrains {
    return featuredTrainPackages
        .where((t) => _trainIds.contains(t.id))
        .toList();
  }

  Future<void> _removeItem(String type, String id) async {
    await WishlistService.remove(type, id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _gold,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Saved',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hotel_outlined, size: 15),
                const SizedBox(width: 5),
                Text('Hotels (${_hotelIds.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flight_outlined, size: 15),
                const SizedBox(width: 5),
                Text('Flights (${_flightIds.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.train_outlined, size: 15),
                const SizedBox(width: 5),
                Text('Trains (${_trainIds.length})'),
              ]),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHotelTab(),
                _buildFlightTab(),
                _buildTrainTab(),
              ],
            ),
    );
  }

  // ── HOTELS TAB ────────────────────────────────────────────────────────────

  Widget _buildHotelTab() {
    final hotels = _savedHotels;
    if (hotels.isEmpty) {
      return _buildEmpty('No saved hotels yet', Icons.hotel_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hotels.length,
      itemBuilder: (context, index) {
        final h = hotels[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SavedHotelCard(
            hotel: h,
            onTap: () {
              final checkIn = DateTime.now().add(const Duration(days: 3));
              final checkOut = DateTime.now().add(const Duration(days: 5));
              Get.toNamed(AppLink.hotelDetail, arguments: {
                'hotel': h,
                'checkInDate': checkIn,
                'checkOutDate': checkOut,
                'rooms': 1,
                'guests': 2,
                'discountPct': 15,
                'originalPrice': h.pricePerNight * 2,
                'finalPrice': h.pricePerNight * 2 * 0.85,
              });
            },
            onRemove: () => _removeItem('hotel', h.id),
          ),
        );
      },
    );
  }

  // ── FLIGHTS TAB ───────────────────────────────────────────────────────────

  Widget _buildFlightTab() {
    final flights = _savedFlights;
    if (flights.isEmpty) {
      return _buildEmpty('No saved flights yet', Icons.flight_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final f = flights[index];
        final departDate = DateTime.now().add(Duration(days: 30 + index * 2));
        final returnDate =
            f.roundTrip ? departDate.add(const Duration(days: 2)) : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SavedFlightCard(
            pkg: f,
            departDate: departDate,
            returnDate: returnDate,
            onTap: () {
              Get.toNamed(AppLink.flightDetailPackage, arguments: {
                'package': f,
                'departDate': departDate,
                'returnDate': returnDate,
              });
            },
            onRemove: () => _removeItem('flight', f.id),
          ),
        );
      },
    );
  }

  // ── TRAINS TAB ────────────────────────────────────────────────────────────

  Widget _buildTrainTab() {
    final trains = _savedTrains;
    if (trains.isEmpty) {
      return _buildEmpty('No saved trains yet', Icons.train_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trains.length,
      itemBuilder: (context, index) {
        final t = trains[index];
        final departDate = DateTime.now().add(Duration(days: 7 + index));

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SavedTrainCard(
            pkg: t,
            departDate: departDate,
            onTap: () {
              Get.toNamed(AppLink.trainDetailPackage, arguments: {
                'package': t,
                'departDate': departDate,
              });
            },
            onRemove: () => _removeItem('train', t.id),
          ),
        );
      },
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        const Text('Tap the ❤ icon on any package to save it',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.explore_outlined, size: 18),
          label: const Text('Browse Packages',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () => Get.toNamed(AppLink.home),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Saved hotel card
// ═══════════════════════════════════════════════════════════════════════════
class _SavedHotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedHotelCard({
    required this.hotel,
    required this.onTap,
    required this.onRemove,
  });

  int get _stars {
    if (hotel.category.contains('5')) return 5;
    if (hotel.category.contains('4')) return 4;
    if (hotel.category.contains('3')) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.30,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: hotel.images.isNotEmpty
                            ? Image.network(hotel.images.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.hotel,
                                        size: 32, color: Colors.grey)))
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.hotel,
                                    size: 32, color: Colors.grey)),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite,
                                size: 14, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ...List.generate(
                              _stars,
                              (_) => const Icon(Icons.star,
                                  size: 11, color: _gold)),
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
                            child: Text(hotel.category,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(hotel.name,
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
                            child: Text(hotel.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                            'From PKR ${fmt.format(hotel.pricePerNight)} / night',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _gold)),
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

// ═══════════════════════════════════════════════════════════════════════════
// Saved flight card
// ═══════════════════════════════════════════════════════════════════════════
class _SavedFlightCard extends StatelessWidget {
  final FlightPackage pkg;
  final DateTime departDate;
  final DateTime? returnDate;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedFlightCard({
    required this.pkg,
    required this.departDate,
    required this.returnDate,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = returnDate != null
        ? '${DateFormat('d MMM').format(departDate)} → ${DateFormat('d MMM yyyy').format(returnDate!)}'
        : DateFormat('d MMM yyyy').format(departDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image strip
              Stack(children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Image.network(pkg.img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.flight,
                              size: 40, color: Colors.grey))),
                ),
                // Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: pkg.roundTrip ? _goldDark : _gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(pkg.roundTrip ? 'Round-Trip' : 'One-Way',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                // Remove button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
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
                      child: const Icon(Icons.favorite,
                          size: 15, color: Colors.red),
                    ),
                  ),
                ),
              ]),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${pkg.from.name}  →  ${pkg.to.name}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 8),
                    Text('PKR ${fmt.format(pkg.price)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _gold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Saved train card
// ═══════════════════════════════════════════════════════════════════════════
class _SavedTrainCard extends StatelessWidget {
  final TrainPackage pkg;
  final DateTime departDate;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedTrainCard({
    required this.pkg,
    required this.departDate,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image strip
              Stack(children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Image.network(pkg.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.train,
                              size: 40, color: Colors.grey))),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _goldDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(pkg.trainClass,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
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
                      child: const Icon(Icons.favorite,
                          size: 15, color: Colors.red),
                    ),
                  ),
                ),
              ]),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(pkg.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(height: 3),
                    Text(
                      '${pkg.fromStation.split(' ').first}  →  '
                      '${pkg.toStation.split(' ').first}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                          '${DateFormat('d MMM yyyy').format(departDate)} · ${pkg.departureTime}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 8),
                    Text('PKR ${fmt.format(pkg.price)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _gold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
