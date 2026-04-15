import 'dart:math';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/flight_package.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/widgets/cards/package_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8935C);

class PromoDetail extends StatefulWidget {
  const PromoDetail({super.key});

  @override
  State<PromoDetail> createState() => _PromoDetailState();
}

class _PromoDetailState extends State<PromoDetail> {
  String _selectedFilter = 'All';
  String _userOriginCityCode = 'KHI';
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
        _userOriginCityCode = cityData['cityCode']!;
        _userOriginCityName = cityData['cityName']!;
        _isLoading = false;
      });
    }
  }

  /// Packages from user's origin city (mirrors package_list_slider.dart logic)
  List<FlightPackage> get _cityPackages {
    if (_isGuestMode) {
      final seed = DateTime.now().day * 31 + DateTime.now().month;
      final rng = Random(seed);
      final all = List<FlightPackage>.from(flightPackageList);
      all.shuffle(rng);
      return all;
    }
    final lowerCity = _userOriginCityName.toLowerCase();
    final isISBZone = lowerCity == 'islamabad' || lowerCity == 'rawalpindi';
    return flightPackageList.where((pkg) {
      final fromName = pkg.from.name.toLowerCase();
      if (isISBZone) {
        return fromName == 'islamabad' ||
            fromName == 'rawalpindi' ||
            pkg.from.code == 'ISB' ||
            pkg.from.code == 'RWP';
      }
      return fromName.contains(lowerCity) ||
          pkg.from.code == _userOriginCityCode;
    }).toList();
  }

  static const Map<String, String> _durationMap = {
    'Karachi-Lahore': '1h 30m',
    'Lahore-Karachi': '1h 30m',
    'Karachi-Islamabad': '2h 00m',
    'Islamabad-Karachi': '2h 00m',
    'Karachi-Peshawar': '2h 15m',
    'Peshawar-Karachi': '2h 15m',
    'Karachi-Multan': '1h 15m',
    'Multan-Karachi': '1h 15m',
    'Karachi-Quetta': '1h 30m',
    'Quetta-Karachi': '1h 30m',
    'Karachi-Gwadar': '1h 10m',
    'Gwadar-Karachi': '1h 10m',
    'Karachi-Gilgit': '2h 30m',
    'Gilgit-Karachi': '2h 30m',
    'Karachi-Skardu': '2h 30m',
    'Skardu-Karachi': '2h 30m',
    'Lahore-Islamabad': '0h 50m',
    'Islamabad-Lahore': '0h 50m',
    'Lahore-Peshawar': '1h 10m',
    'Peshawar-Lahore': '1h 10m',
    'Lahore-Multan': '1h 00m',
    'Multan-Lahore': '1h 00m',
    'Lahore-Quetta': '2h 00m',
    'Quetta-Lahore': '2h 00m',
    'Lahore-Gilgit': '1h 45m',
    'Gilgit-Lahore': '1h 45m',
    'Lahore-Skardu': '2h 00m',
    'Skardu-Lahore': '2h 00m',
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
  };

  String _duration(String from, String to) => _durationMap['$from-$to'] ?? '';

  List<FlightPackage> get _filtered {
    final base = _cityPackages;
    if (_selectedFilter == 'One-Way') return base.where((p) => !p.roundTrip).toList();
    if (_selectedFilter == 'Round-Trip') return base.where((p) => p.roundTrip).toList();
    return base;
  }

  String get _appBarTitle {
    if (_isLoading || _isGuestMode) return 'Featured Packages';
    return 'Flight Packages from $_userOriginCityName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
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

          // ── Stats row ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, 0),
              child: _buildStatsRow(),
            ),
          ),

          // ── Package Grid ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _filtered[index];
                  final departDate =
                      DateTime.now().add(Duration(days: 30 + index * 2));
                  final returnDate = item.roundTrip
                      ? departDate.add(const Duration(days: 2))
                      : null;
                  final dateStr = item.roundTrip
                      ? '${DateFormat('d').format(departDate)} - ${DateFormat('d MMM yyyy').format(returnDate!)}'
                      : DateFormat('d MMM yyyy').format(departDate);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () =>
                          Get.toNamed(AppLink.flightDetailPackage, arguments: {
                        'package': item,
                        'departDate': departDate,
                        'returnDate': returnDate,
                      }),
                      child: SizedBox(
                        height: 220,
                        child: PackageCard(
                          image: item.img,
                          label: item.label ?? '',
                          from: item.from.name,
                          to: item.to.name,
                          date: dateStr,
                          duration: _duration(item.from.name, item.to.name),
                          tags: item.tags ?? [],
                          price: item.price,
                          plane: item.plane,
                          roundTrip: item.roundTrip,
                        ),
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
    final all = base.length;
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
        _statItem('$all', 'Total Packages', Icons.confirmation_number_outlined),
        _divider(),
        _statItem('$oneWay', 'One-Way', Icons.flight_takeoff),
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
}
