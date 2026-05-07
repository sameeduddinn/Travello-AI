import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/booking_service.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFEF9EC);
const _goldDark = Color(0xFFB8935C);

class MyBookings extends StatefulWidget {
  const MyBookings({super.key});

  @override
  State<MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<MyBookings>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  String _selectedFilter = 'All';
  String _selectedType = 'All';
  bool _isLoading = true;
  bool _historyMode = false;

  String _normalizedStatus(Map<String, dynamic> booking) {
    final raw = (booking['status'] ?? '').toString().toLowerCase();
    if (raw == 'canceled') return 'cancelled';
    return raw;
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map && args['historyMode'] == true) {
      _historyMode = true;
      _selectedFilter = 'Past';
    }
    _loadBookings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload every time this screen becomes visible (handles back-navigation
    // and GetX route reuse without re-running initState)
    _loadBookings();
  }

  // ── Helpers for normalizing backend flat fields ──────────────────────────

  static String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
  static String _fmtDateStr(DateTime dt) => DateFormat('d MMM yyyy').format(dt);

  static String _calcDuration(DateTime? dep, DateTime? arr) {
    if (dep == null || arr == null) return 'N/A';
    final diff = arr.difference(dep);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  /// Builds the nested detail map expected by the booking card widgets,
  /// converting flat backend fields (origin, departure_at, hotel_name, etc.)
  static Map<String, dynamic> _normalizeBackendBooking(
      Map<String, dynamic> m) {
    final bookingType = (m['booking_type'] ?? 'flight') as String;

    DateTime? depDt = _parseDt(m['departure_at'] as String?);
    DateTime? arrDt = _parseDt(m['arrival_at'] as String?);

    Map<String, dynamic>? flightDetails;
    Map<String, dynamic>? trainDetails;
    Map<String, dynamic>? hotelDetails;

    if (bookingType == 'hotel') {
      final ci = m['check_in'] as String? ?? '';
      final co = m['check_out'] as String? ?? '';
      int nights = 1;
      final ciDt = _parseDt(ci);
      final coDt = _parseDt(co);
      if (ciDt != null && coDt != null) {
        nights = coDt.difference(ciDt).inDays.clamp(1, 365);
      }
      hotelDetails = {
        'hotelName': m['hotel_name'] ?? 'Hotel',
        'city': m['destination'] ?? m['origin'] ?? '',
        'checkIn': ci,
        'checkOut': co,
        'nights': nights,
        'rating': 0,
        'roomType': 'Standard Room',
      };
    } else if (bookingType == 'train') {
      trainDetails = {
        'from': m['origin'] ?? '',
        'to': m['destination'] ?? '',
        'fromCode': _toCode(m['origin'] as String? ?? ''),
        'toCode': _toCode(m['destination'] as String? ?? ''),
        'departure':
            depDt != null ? _fmtTime(depDt) : 'N/A',
        'arrival':
            arrDt != null ? _fmtTime(arrDt) : 'N/A',
        'date': depDt != null ? _fmtDateStr(depDt) : '',
        'duration': _calcDuration(depDt, arrDt),
        'class': 'Economy',
      };
    } else {
      flightDetails = {
        'from': m['origin'] ?? '',
        'to': m['destination'] ?? '',
        'departure':
            depDt != null ? _fmtTime(depDt) : 'N/A',
        'arrival':
            arrDt != null ? _fmtTime(arrDt) : 'N/A',
        'date': depDt != null ? _fmtDateStr(depDt) : '',
      };
    }

    // Passenger count from raw_payload if available
    int passengerCount = 1;
    final rp = m['raw_payload'];
    if (rp is Map) {
      passengerCount =
          (rp['passenger_count'] ?? rp['passengers'] ?? 1) as int? ?? 1;
    }

    return {
      'bookingId': m['booking_id'] ?? m['id'] ?? '',
      'bookingType': bookingType,
      'status': m['status'] ?? 'confirmed',
      'bookingDate': m['created_at'] ?? '',
      'pnr': m['pnr'] ?? '',
      'total': (m['total_amount'] as num?)?.toDouble() ?? 0.0,
      'passengerCount': passengerCount,
      if (flightDetails != null) 'flightDetails': flightDetails,
      if (trainDetails != null) 'trainDetails': trainDetails,
      if (hotelDetails != null) 'hotelDetails': hotelDetails,
      // keep all raw backend fields for booking detail screen
      ...m,
    };
  }

  static DateTime? _parseDt(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String _toCode(String name) {
    // Extract 3-letter code from "City (CODE)" format, else use first 3 letters
    final match = RegExp(r'\(([A-Z]{2,4})\)').firstMatch(name);
    if (match != null) return match.group(1)!;
    final clean = name.trim().replaceAll(RegExp(r'[^A-Za-z ]'), '');
    final words = clean.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}${words.length > 2 ? words[2][0] : words[0][1]}'
          .toUpperCase();
    }
    return clean.substring(0, clean.length.clamp(0, 3)).toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> bookings = [];

    // 1. Try backend first
    try {
      final data = await ApiClient.getBookings(perPage: 100);
      final raw = data['bookings'] as List<dynamic>? ?? [];
      if (raw.isNotEmpty) {
        bookings = raw
            .map((b) =>
                _normalizeBackendBooking(Map<String, dynamic>.from(b as Map)))
            .toList();
      }
    } catch (_) {
      // Backend unreachable or user not logged in — fall through to local
    }

    // 2. Merge with local SharedPreferences bookings (always available)
    final local = await BookingService.getAllBookings();
    final backendIds =
        bookings.map((b) => b['bookingId']?.toString() ?? '').toSet();
    for (final lb in local) {
      final lid = lb['bookingId']?.toString() ?? '';
      if (!backendIds.contains(lid)) bookings.add(lb);
    }

    setState(() {
      _allBookings = bookings.where((b) {
        final type = b['bookingType'] as String? ?? 'flight';
        // Accept bookings that came directly from backend (they have booking_id)
        if (b.containsKey('booking_id')) return true;
        if (type == 'flight') {
          final fd = b['flightDetails'] as Map<String, dynamic>?;
          if (fd == null) return false;
          final from = fd['from']?.toString() ?? 'N/A';
          final to = fd['to']?.toString() ?? 'N/A';
          return from != 'N/A' && to != 'N/A';
        } else if (type == 'train') {
          final td = b['trainDetails'] as Map<String, dynamic>?;
          if (td == null) return false;
          return (td['from']?.toString() ?? 'N/A') != 'N/A';
        } else if (type == 'hotel') {
          return b['hotelDetails'] != null;
        }
        return true;
      }).toList();
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allBookings);
    if (_selectedType != 'All') {
      filtered = filtered
          .where((b) => b['bookingType'] == _selectedType.toLowerCase())
          .toList();
    }
    final now = DateTime.now();
    if (_selectedFilter == 'Upcoming') {
      filtered = filtered.where((b) {
        if (_normalizedStatus(b) == 'cancelled') return false;
        return _getTravelDate(b)?.isAfter(now) ?? false;
      }).toList();
    } else if (_selectedFilter == 'Past') {
      filtered = filtered.where((b) {
        if (_normalizedStatus(b) == 'cancelled') return false;
        final d = _getTravelDate(b);
        return d == null || d.isBefore(now);
      }).toList();
    } else if (_selectedFilter == 'Canceled') {
      filtered =
          filtered.where((b) => _normalizedStatus(b) == 'cancelled').toList();
    }
    setState(() => _filteredBookings = filtered);
  }

  DateTime? _getTravelDate(Map<String, dynamic> b) {
    try {
      final type = b['bookingType'] ?? 'flight';
      if (type == 'hotel') {
        final h = b['hotelDetails'] as Map<String, dynamic>?;
        if (h == null) return null;
        return _parseDate(h['checkIn']?.toString());
      } else {
        final details =
            type == 'train' ? b['trainDetails'] : b['flightDetails'];
        if (details == null) return null;
        final date = _parseDate(details['date']?.toString());
        if (date == null) return null;
        final timeStr = details['departure']?.toString();
        if (timeStr != null) {
          final parts = timeStr.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          return DateTime(date.year, date.month, date.day, h, m);
        }
        return date;
      }
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final p = s.trim().split(' ');
      if (p.length < 3) return null;
      return DateTime(int.tryParse(p[2]) ?? DateTime.now().year,
          months.indexOf(p[1]) + 1, int.tryParse(p[0]) ?? 1);
    } catch (_) {
      return null;
    }
  }

  int get _upcomingCount {
    final now = DateTime.now();
    return _allBookings.where((b) {
      if (_normalizedStatus(b) == 'cancelled') return false;
      return _getTravelDate(b)?.isAfter(now) ?? false;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      body: CustomScrollView(
        slivers: [
          _buildGoldAppBar(),
          _buildFilterTabs(),
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _gold),
                  const SizedBox(height: 16),
                  Text('Loading your bookings...',
                      style: TravelloTheme.paragraph
                          .copyWith(color: Colors.grey.shade600)),
                ],
              )),
            )
          else if (_filteredBookings.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildBookingCard(_filteredBookings[index]),
                  ),
                  childCount: _filteredBookings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoldAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _gold,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _historyMode ? 'Booking History' : 'My Bookings',
                              style: TravelloTheme.title.copyWith(
                                  color: Colors.white,
                                  fontSize: R.sp(context, 26),
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: spacingUnit(0.4)),
                          Text(
                              _historyMode
                                  ? '${_filteredBookings.length} Past Bookings'
                                  : '${_allBookings.length} Total  •  $_upcomingCount Upcoming',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.confirmation_number_outlined,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              _buildTypeChip('All', Icons.list_alt),
              const SizedBox(width: 8),
              _buildTypeChip('Train', Icons.train),
              const SizedBox(width: 8),
              _buildTypeChip('Flight', Icons.flight),
              const SizedBox(width: 8),
              _buildTypeChip('Hotel', Icons.hotel),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('Past'),
                const SizedBox(width: 8),
                _buildFilterChip('Canceled'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    final isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedType = label;
          _applyFilters();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _gold : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? _gold : Colors.grey.shade300, width: 1.5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: _gold.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade600),
              SizedBox(height: spacingUnit(0.3)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = label;
        _applyFilters();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            EdgeInsets.symmetric(horizontal: 16, vertical: spacingUnit(0.75)),
        decoration: BoxDecoration(
          color: isSelected ? _goldLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _gold : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? _goldDark : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13)),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bookingType = booking['bookingType'] ?? 'flight';
    Color headerBg;
    Color accentColor;
    IconData typeIcon;
    String typeLabel;
    switch (bookingType) {
      case 'train':
        headerBg = const Color(0xFFF0FDF4);
        accentColor = const Color(0xFF059669);
        typeIcon = Icons.train;
        typeLabel = 'TRAIN';
        break;
      case 'hotel':
        headerBg = const Color(0xFFFFFBEB);
        accentColor = _gold;
        typeIcon = Icons.hotel;
        typeLabel = 'HOTEL';
        break;
      default:
        headerBg = const Color(0xFFEFF6FF);
        accentColor = const Color(0xFF3B82F6);
        typeIcon = Icons.flight;
        typeLabel = 'FLIGHT';
    }
    return GestureDetector(
      onTap: () => Get.toNamed(AppLink.ticketDetail, arguments: booking),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: spacingUnit(1.75), vertical: spacingUnit(1.25)),
            decoration: BoxDecoration(
                color: headerBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Icon(typeIcon, size: 13, color: Colors.white),
                      SizedBox(width: spacingUnit(0.4)),
                      Text(typeLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bookingType == 'hotel'
                        ? 'Ref: ${booking['pnr'] ?? 'N/A'}'
                        : 'PNR: ${booking['pnr'] ?? 'N/A'}',
                    style: TravelloTheme.caption
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ]),
                _buildStatusBadge(booking['status'] ?? 'confirmed'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (bookingType == 'train')
                _buildTrainJourneyDetails(booking)
              else if (bookingType == 'hotel')
                _buildHotelDetails(booking)
              else
                _buildFlightJourneyDetails(booking),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade100, height: 1),
              SizedBox(height: spacingUnit(1.25)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.people_outline,
                        size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${booking['passengerCount'] ?? 1} ${bookingType == 'hotel' ? (((booking['passengerCount'] ?? 1) > 1) ? 'Guests' : 'Guest') : (((booking['passengerCount'] ?? 1) > 1) ? 'Passengers' : 'Passenger')}',
                      style: TravelloTheme.caption
                          .copyWith(color: Colors.grey.shade500),
                    ),
                  ]),
                  Text('PKR ${(booking['total'] ?? 0.0).toStringAsFixed(0)}',
                      style: TravelloTheme.subtitle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _gold,
                          fontSize: 16)),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHotelDetails(Map<String, dynamic> booking) {
    final h = booking['hotelDetails'] as Map<String, dynamic>?;
    if (h == null) return const SizedBox();
    final stars = (h['rating'] ?? 0) as num;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _goldLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.hotel, color: _gold, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h['hotelName'] ?? 'Hotel',
                  style: TravelloTheme.subtitle
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if ((h['city'] ?? '').toString().isNotEmpty)
                Text(h['city'].toString(),
                    style: TravelloTheme.caption
                        .copyWith(color: Colors.grey.shade500)),
              if (stars > 0)
                Row(
                    children: List.generate(stars.toInt(),
                        (i) => const Icon(Icons.star, size: 12, color: _gold))),
            ],
          )),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: _goldLight, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
                child: Column(children: [
              const Text('CHECK-IN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _goldDark,
                      letterSpacing: 0.8)),
              SizedBox(height: spacingUnit(0.3)),
              Text(h['checkIn'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${h['nights'] ?? 1}N',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _goldDark)),
            ),
            Expanded(
                child: Column(children: [
              const Text('CHECK-OUT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _goldDark,
                      letterSpacing: 0.8)),
              SizedBox(height: spacingUnit(0.3)),
              Text(h['checkOut'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.bed_outlined, size: 14, color: _goldDark),
          const SizedBox(width: 4),
          Text(h['roomType'] ?? 'Standard Room',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ]),
      ],
    );
  }

  Widget _buildTrainJourneyDetails(Map<String, dynamic> booking) {
    final train = booking['trainDetails'] as Map<String, dynamic>?;
    if (train == null) return const SizedBox();
    const accent = Color(0xFF059669);
    return Row(children: [
      Expanded(
          flex: 2,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(train['departure'] ?? 'N/A',
                style: TravelloTheme.title2
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
            SizedBox(height: spacingUnit(0.3)),
            Text(train['fromCode'] ?? 'N/A',
                style: TravelloTheme.headline.copyWith(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            Text(train['from'] ?? 'N/A',
                style:
                    TravelloTheme.caption.copyWith(color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])),
      Expanded(
          flex: 1,
          child: Column(children: [
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 6.4, vertical: spacingUnit(0.3)),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(train['duration'] ?? 'N/A',
                  style: TravelloTheme.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: accent, shape: BoxShape.circle)),
              Expanded(child: Container(height: 2, color: accent)),
              const Icon(Icons.train, size: 16, color: accent),
              Expanded(child: Container(height: 2, color: accent)),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: accent, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(train['class'] ?? 'Economy',
                style: TravelloTheme.caption.copyWith(
                    fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
          ])),
      Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(train['arrival'] ?? 'N/A',
                style: TravelloTheme.title2
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
            SizedBox(height: spacingUnit(0.3)),
            Text(train['toCode'] ?? 'N/A',
                style: TravelloTheme.headline.copyWith(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            Text(train['to'] ?? 'N/A',
                style:
                    TravelloTheme.caption.copyWith(color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end),
          ])),
    ]);
  }

  Widget _buildFlightJourneyDetails(Map<String, dynamic> booking) {
    final flight = booking['flightDetails'] as Map<String, dynamic>?;
    if (flight == null) return const SizedBox();
    const accent = Color(0xFF3B82F6);
    final fromStr = flight['from'] ?? 'N/A';
    final toStr = flight['to'] ?? 'N/A';
    final fromCode =
        RegExp(r'\(([A-Z]{3})\)').firstMatch(fromStr)?.group(1) ?? 'N/A';
    final toCode =
        RegExp(r'\(([A-Z]{3})\)').firstMatch(toStr)?.group(1) ?? 'N/A';
    return Row(children: [
      Expanded(
          flex: 2,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(flight['departure'] ?? 'N/A',
                style: TravelloTheme.title2
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
            SizedBox(height: spacingUnit(0.3)),
            Text(fromCode,
                style: TravelloTheme.headline.copyWith(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            Text(fromStr.replaceAll(RegExp(r'\s*\([A-Z]{3}\)'), ''),
                style:
                    TravelloTheme.caption.copyWith(color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])),
      Expanded(
          flex: 1,
          child: Column(children: [
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 6.4, vertical: spacingUnit(0.3)),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(flight['duration'] ?? 'N/A',
                  style: TravelloTheme.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: accent, shape: BoxShape.circle)),
              Expanded(child: Container(height: 2, color: accent)),
              const Icon(Icons.flight, size: 16, color: accent),
              Expanded(child: Container(height: 2, color: accent)),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: accent, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(flight['class'] ?? 'Economy',
                style: TravelloTheme.caption.copyWith(
                    fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
          ])),
      Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(flight['arrival'] ?? 'N/A',
                style: TravelloTheme.title2
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
            SizedBox(height: spacingUnit(0.3)),
            Text(toCode,
                style: TravelloTheme.headline.copyWith(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            Text(toStr.replaceAll(RegExp(r'\s*\([A-Z]{3}\)'), ''),
                style:
                    TravelloTheme.caption.copyWith(color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end),
          ])),
    ]);
  }

  Widget _buildStatusBadge(String status) {
    final normalized =
        status.toLowerCase() == 'canceled' ? 'cancelled' : status.toLowerCase();
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;
    switch (normalized) {
      case 'confirmed':
      case 'paid':
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
        textColor = const Color(0xFF10B981);
        label = 'CONFIRMED';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
        textColor = const Color(0xFFEF4444);
        label = 'CANCELLED';
        icon = Icons.cancel;
        break;
      case 'completed':
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = 'COMPLETED';
        icon = Icons.check_circle_outline;
        break;
      default:
        bgColor = _goldLight;
        textColor = _goldDark;
        label = 'PENDING';
        icon = Icons.access_time;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, size: 12, color: textColor),
        SizedBox(width: spacingUnit(0.3)),
        Text(label,
            style: TravelloTheme.caption.copyWith(
                color: textColor, fontWeight: FontWeight.w700, fontSize: 10)),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: _goldLight, shape: BoxShape.circle),
              child: Icon(
                _selectedType == 'Hotel'
                    ? Icons.hotel_outlined
                    : _selectedType == 'Train'
                        ? Icons.train_outlined
                        : Icons.airplane_ticket_outlined,
                size: 64,
                color: _gold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (_selectedFilter != 'All' || _selectedType != 'All')
                  ? 'No ${_selectedFilter != 'All' ? '${_selectedFilter.toLowerCase()} ' : ''}${_selectedType != 'All' ? '${_selectedType.toLowerCase()} ' : ''}bookings'
                  : 'No bookings yet',
              style: TravelloTheme.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Start exploring and book your next trip!',
                style: TravelloTheme.paragraph
                    .copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
              child: FilledButton(
                onPressed: () => Get.toNamed(AppLink.home),
                style:
                    ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
                child: const Text('BOOK NOW'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
