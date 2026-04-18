import 'package:flight_app/models/trip.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

const _cityImages = {
  'karachi':
      'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800&q=80',
  'lahore':
      'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
  'islamabad':
      'https://images.unsplash.com/photo-1578895101408-1a36b834405b?w=800&q=80',
  'rawalpindi':
      'https://images.unsplash.com/photo-1578895101408-1a36b834405b?w=800&q=80',
  'peshawar':
      'https://images.unsplash.com/photo-1539136788836-5699e78bfc75?w=800&q=80',
  'quetta':
      'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=800&q=80',
  'multan':
      'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
  'faisalabad':
      'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
  'skardu':
      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
  'gilgit':
      'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800&q=80',
  'hunza':
      'https://images.unsplash.com/photo-1587474260584-136574528ed5?w=800&q=80',
  'swat':
      'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80',
  'murree':
      'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80',
  'gwadar':
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
};

const _fallback =
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80';

class CitySearchResults extends StatefulWidget {
  const CitySearchResults({super.key});

  @override
  State<CitySearchResults> createState() => _CitySearchResultsState();
}

class _CitySearchResultsState extends State<CitySearchResults>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String cityName;
  late List<Trip> _departures;
  late List<Trip> _arrivals;
  late List<Trip> _routes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final args = Get.arguments as Map<String, dynamic>?;
    cityName = args?['cityName'] ?? '';
    final lower = cityName.toLowerCase();

    _departures = tripList
        .where((t) => t.from.name.toLowerCase() == lower)
        .take(10)
        .toList();
    _arrivals = tripList
        .where((t) => t.to.name.toLowerCase() == lower)
        .take(10)
        .toList();
    _routes = tripList
        .where((t) =>
            t.from.name.toLowerCase() == lower ||
            t.to.name.toLowerCase() == lower)
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _imageUrl => _cityImages[cityName.toLowerCase()] ?? _fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: TravelloTheme.primaryMain,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                cityName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
              ),
              background: Stack(fit: StackFit.expand, children: [
                Image.network(_imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: TravelloTheme.primaryDark)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65)
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Stats row ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(Icons.flight_takeoff, '${_departures.length}',
                      'Departures'),
                  _divider(),
                  _stat(Icons.flight_land, '${_arrivals.length}', 'Arrivals'),
                  _divider(),
                  _stat(Icons.route, '${_routes.length}', 'Routes'),
                ],
              ),
            ),
          ),

          // ── Pinned tab bar ─────────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(
              TabBar(
                controller: _tabController,
                labelColor: TravelloTheme.primaryMain,
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: TravelloTheme.primaryMain,
                indicatorWeight: 2.5,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Departures'),
                  Tab(text: 'Arrivals'),
                  Tab(text: 'All Routes'),
                ],
              ),
            ),
          ),

          // ── Tab content ────────────────────────────────────────────────────
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _flightList(_departures, 'No departures from $cityName'),
                _flightList(_arrivals, 'No arrivals to $cityName'),
                _flightList(_routes, 'No routes found for $cityName'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _stat(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: TravelloTheme.primaryMain, size: 22),
      const SizedBox(height: 4),
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

  Widget _flightList(List<Trip> trips, String emptyMsg) {
    if (trips.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.flight_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(emptyMsg,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: trips.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: () => Get.toNamed('/flight-search-home'),
          child: _FlightCard(trip: trips[i]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Modern flight result card
// ═══════════════════════════════════════════════════════════════════════════════
class _FlightCard extends StatelessWidget {
  final Trip trip;
  const _FlightCard({required this.trip});

  String _fmt(DateTime dt) => DateFormat('HH:mm').format(dt);
  String _date(DateTime dt) => DateFormat('d MMM yyyy').format(dt);

  String _duration() {
    final diff = trip.arrival.difference(trip.depart);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final stops = trip.transit == 0
        ? 'Direct'
        : trip.transit == 1
            ? '1 Stop'
            : '${trip.transit} Stops';
    final stopColor =
        trip.transit == 0 ? const Color(0xFF059669) : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // ── Airline header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    trip.plane.logo,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.flight,
                        size: 20, color: TravelloTheme.primaryMain),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.plane.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF111827)),
                      ),
                      const Text('Economy',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                // Stops badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stopColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: stopColor.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(stops,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: stopColor)),
                ),
              ],
            ),
          ),

          // ── Route ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Departure
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmt(trip.depart),
                          style: TextStyle(
                              fontSize: R.sp(context, 22),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(trip.from.code,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB))),
                      Text(trip.from.name,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),

                // Duration + arrow
                Column(
                  children: [
                    Text(_duration(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 28, height: 1, color: const Color(0xFFD1D5DB)),
                      const Icon(Icons.flight,
                          size: 16, color: Color(0xFF2563EB)),
                      Container(
                          width: 28, height: 1, color: const Color(0xFFD1D5DB)),
                    ]),
                  ],
                ),

                // Arrival
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(trip.arrival),
                          style: TextStyle(
                              fontSize: R.sp(context, 22),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(trip.to.code,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB))),
                      Text(trip.to.name,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(_date(trip.depart),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Icon(Icons.swap_horiz, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(trip.roundTrip ? 'Round-trip' : 'One-way',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const Spacer(),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: 'PKR ',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    TextSpan(
                        text: NumberFormat('#,###').format(trip.price.toInt()),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD4AF37))),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────
class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabDelegate old) => false;
}
