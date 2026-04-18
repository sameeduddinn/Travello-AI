import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/format_utils.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:intl/intl.dart';

// Flight model for results
class FlightResult {
  final String id;
  final String airlineName;
  final String airlineCode;
  final String airlineLogo;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final int stops;
  final List<String> stopCities;
  final double price;
  final String badge; // 'Cheapest', 'Fastest', 'Recommended'
  final bool isRefundable;
  final String cabinClass;
  // Fields populated from real API (null for dummy data)
  final int? seatsAvailable;
  final String? baggage;
  final String? flightNumber;

  FlightResult({
    required this.id,
    required this.airlineName,
    required this.airlineCode,
    required this.airlineLogo,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.stops,
    required this.stopCities,
    required this.price,
    this.badge = '',
    required this.isRefundable,
    required this.cabinClass,
    this.seatsAvailable,
    this.baggage,
    this.flightNumber,
  });
}

class FlightResultsScreen extends StatefulWidget {
  const FlightResultsScreen({super.key});

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  // Get search parameters
  late Map<String, dynamic> searchParams;

  // Round-trip handling
  late bool _isRoundTrip;
  late int _currentJourneyIndex; // 0 = outbound, 1 = return
  FlightResult? _selectedOutboundFlight;
  late DateTime? _selectedReturnDate;

  // Date selection
  late DateTime _selectedDate;

  // Filters
  final bool _directFlightsOnly = false;
  final int _maxStops = 3; // 0 = direct, 1 = 1 stop, 2 = 2+ stops, 3 = any
  RangeValues _priceRange = const RangeValues(0, 100000);
  RangeValues _departureTimeRange = const RangeValues(0, 24);
  bool _refundableOnly = false;
  String _sortBy = 'Recommended'; // Recommended, Cheapest, Fastest
  late String _selectedCabinClass;

  // Passenger counts
  late int _adults;
  late int _children;
  late int _infants;

  List<FlightResult> _allFlights = [];
  List<FlightResult> _filteredFlights = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    searchParams = Get.arguments ?? {};

    // Check if round-trip
    _isRoundTrip = searchParams['tripType'] == 'Round-trip';
    _currentJourneyIndex = 0; // Start with outbound

    // Get selected cabin class
    _selectedCabinClass = searchParams['cabinClass'] ?? 'Economy';

    // Get passenger counts
    _adults = searchParams['adults'] ?? 1;
    _children = searchParams['children'] ?? 0;
    _infants = searchParams['infants'] ?? 0;

    // Initialize date
    _selectedDate = searchParams['departureDate'] ?? DateTime.now();

    // Initialize return date if round-trip
    if (_isRoundTrip) {
      _selectedReturnDate = searchParams['returnDate'];
    } else {
      _selectedReturnDate = null;
    }

    _fetchFlights();
  }

  // ── Backend fetch with dummy-data fallback ────────────────────────────────
  Future<void> _fetchFlights() async {
    setState(() => _isLoading = true);
    try {
      final fromAirport = searchParams['fromAirport'] as Airport?;
      final toAirport = searchParams['toAirport'] as Airport?;

      if (fromAirport == null || toAirport == null) {
        _loadDummyFlights();
      } else {
        // For round-trip return leg, swap origin ↔ destination
        final bool isReturnLeg = _isRoundTrip && _currentJourneyIndex == 1;
        final raw = await ApiClient.searchFlights(
          origin: isReturnLeg ? toAirport.code : fromAirport.code,
          destination: isReturnLeg ? fromAirport.code : toAirport.code,
          date: _selectedDate,
          returnDate: null, // return_date only needed on the outbound search
          adults: _adults,
          cabinClass: _selectedCabinClass,
        );

        // Sort by price so we can assign badges correctly
        raw.sort((a, b) {
          final pa = (a['total_price_pkr'] as num?)?.toDouble() ?? 0;
          final pb = (b['total_price_pkr'] as num?)?.toDouble() ?? 0;
          return pa.compareTo(pb);
        });

        _allFlights = raw.asMap().entries.map((entry) {
          final m = ApiClient.flightResultFromJson(entry.value, entry.key);
          return FlightResult(
            id: m['id'],
            airlineName: m['airlineName'],
            airlineCode: m['airlineCode'],
            airlineLogo: '',
            departureTime: m['departureTime'],
            arrivalTime: m['arrivalTime'],
            duration: m['duration'],
            stops: m['stops'],
            stopCities: List<String>.from(m['stopCities'] ?? []),
            price: m['price'],
            badge:
                entry.key == 0 ? 'Cheapest' : (entry.key == 1 ? 'Fastest' : ''),
            isRefundable: m['isRefundable'],
            cabinClass: m['cabinClass'],
            seatsAvailable: m['seatsAvailable'] as int?,
            baggage: m['baggage'] as String?,
            flightNumber: m['flightNumber'] as String?,
          );
        }).toList();

        if (_allFlights.isEmpty) _loadDummyFlights();
      }
    } catch (e, st) {
      // Keep fallback behavior, but log enough context to debug connectivity.
      debugPrint(
          '[FlightResults] API fetch failed. Base URL: ${ApiClient.resolvedBaseUrl}');
      debugPrint('[FlightResults] Error: $e');
      debugPrint('[FlightResults] Stack: $st');
      _loadDummyFlights();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _applyFilters();
      }
    }
  }

  void _loadDummyFlights() {
    // Generate price variation based on selected date
    final dayOffset = _selectedDate.difference(DateTime.now()).inDays;
    final priceMultiplier = 1.0 + (dayOffset * 0.02); // Price changes by day

    // Cabin class price multipliers
    double cabinMultiplier;
    switch (_selectedCabinClass) {
      case 'Economy':
        cabinMultiplier = 1.0;
        break;
      case 'Premium Economy':
        cabinMultiplier = 1.5;
        break;
      case 'Business':
        cabinMultiplier = 2.5;
        break;
      case 'First Class':
        cabinMultiplier = 4.0;
        break;
      default:
        cabinMultiplier = 1.0;
    }

    // Dummy flight data
    _allFlights = [
      FlightResult(
        id: '1',
        airlineName: 'Pakistan International Airlines',
        airlineCode: 'PK',
        airlineLogo: '',
        departureTime: '08:00',
        arrivalTime: '10:30',
        duration: '2h 30m',
        stops: 0,
        stopCities: [],
        price: (15000 * priceMultiplier * cabinMultiplier).roundToDouble(),
        badge: 'Fastest',
        isRefundable: true,
        cabinClass: _selectedCabinClass,
      ),
      FlightResult(
        id: '2',
        airlineName: 'Airblue',
        airlineCode: 'PA',
        airlineLogo: '',
        departureTime: '10:15',
        arrivalTime: '13:00',
        duration: '2h 45m',
        stops: 0,
        stopCities: [],
        price: (12500 * priceMultiplier * cabinMultiplier).roundToDouble(),
        badge: 'Cheapest',
        isRefundable: false,
        cabinClass: _selectedCabinClass,
      ),
      FlightResult(
        id: '3',
        airlineName: 'SereneAir',
        airlineCode: 'ER',
        airlineLogo: '',
        departureTime: '14:30',
        arrivalTime: '17:15',
        duration: '2h 45m',
        stops: 0,
        stopCities: [],
        price: (14000 * priceMultiplier * cabinMultiplier).roundToDouble(),
        badge: 'Recommended',
        isRefundable: true,
        cabinClass: _selectedCabinClass,
      ),
      FlightResult(
        id: '4',
        airlineName: 'PIA',
        airlineCode: 'PK',
        airlineLogo: '',
        departureTime: '06:00',
        arrivalTime: '07:30',
        duration: '1h 30m',
        stops: 0,
        stopCities: [],
        price: (11000 * priceMultiplier * cabinMultiplier).roundToDouble(),
        isRefundable: false,
        cabinClass: _selectedCabinClass,
      ),
      FlightResult(
        id: '5',
        airlineName: 'Airblue',
        airlineCode: 'PA',
        airlineLogo: '',
        departureTime: '18:00',
        arrivalTime: '20:45',
        duration: '2h 45m',
        stops: 0,
        stopCities: [],
        price: (16500 * priceMultiplier * cabinMultiplier).roundToDouble(),
        isRefundable: true,
        cabinClass: _selectedCabinClass,
      ),
      FlightResult(
        id: '6',
        airlineName: 'SereneAir',
        airlineCode: 'ER',
        airlineLogo: '',
        departureTime: '22:00',
        arrivalTime: '23:25',
        duration: '1h 25m',
        stops: 0,
        stopCities: [],
        price: (10500 * priceMultiplier * cabinMultiplier).roundToDouble(),
        isRefundable: false,
        cabinClass: _selectedCabinClass,
      ),
    ];

    // Set price range based on available flights
    final prices = _allFlights.map((f) => f.price).toList();
    _priceRange = RangeValues(
      prices.reduce((a, b) => a < b ? a : b),
      prices.reduce((a, b) => a > b ? a : b),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredFlights = _allFlights.where((flight) {
        // Cabin class filter - only show flights matching selected cabin class
        if (flight.cabinClass != _selectedCabinClass) return false;

        // Direct flights filter
        if (_directFlightsOnly && flight.stops > 0) return false;

        // Max stops filter
        if (_maxStops < 3 && flight.stops > _maxStops) return false;

        // Price range filter
        if (flight.price < _priceRange.start ||
            flight.price > _priceRange.end) {
          return false;
        }

        // Departure time filter
        final hour = int.parse(flight.departureTime.split(':')[0]);
        if (hour < _departureTimeRange.start ||
            hour > _departureTimeRange.end) {
          return false;
        }

        // Refundable filter
        if (_refundableOnly && !flight.isRefundable) return false;

        return true;
      }).toList();

      // Sort
      if (_sortBy == 'Cheapest') {
        _filteredFlights.sort((a, b) => a.price.compareTo(b.price));
      } else if (_sortBy == 'Fastest') {
        _filteredFlights.sort((a, b) {
          final aDuration = _parseDuration(a.duration);
          final bDuration = _parseDuration(b.duration);
          return aDuration.compareTo(bDuration);
        });
      } else {
        // Recommended: badge flights first, then by price
        _filteredFlights.sort((a, b) {
          if (a.badge.isNotEmpty && b.badge.isEmpty) return -1;
          if (a.badge.isEmpty && b.badge.isNotEmpty) return 1;
          return a.price.compareTo(b.price);
        });
      }
    });
  }

  int _parseDuration(String duration) {
    final parts = duration.split(' ');
    int minutes = 0;
    for (var part in parts) {
      if (part.contains('h')) {
        minutes += int.parse(part.replaceAll('h', '')) * 60;
      } else if (part.contains('m')) {
        minutes += int.parse(part.replaceAll('m', ''));
      }
    }
    return minutes;
  }

  void _showFiltersBottomSheet() {
    if (_allFlights.isEmpty) return;

    // Local temp copies — only committed to parent state on Apply
    RangeValues tempPrice = _priceRange;
    RangeValues tempTime = _departureTimeRange;
    bool tempRefundable = _refundableOnly;

    final double minPrice =
        _allFlights.map((f) => f.price).reduce((a, b) => a < b ? a : b);
    final double maxPrice =
        _allFlights.map((f) => f.price).reduce((a, b) => a > b ? a : b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: EdgeInsets.all(24.r),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),

                      // ── Header ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filters', style: TravelloTheme.title2),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempPrice = RangeValues(minPrice, maxPrice);
                                tempTime = const RangeValues(0, 24);
                                tempRefundable = false;
                              });
                            },
                            child: const Text(
                              'Reset',
                              style:
                                  TextStyle(color: TravelloTheme.primaryMain),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),

                      // ── Price Range ─────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Price Range',
                              style: TravelloTheme.subtitle),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme(context)
                                  .primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '${formatPKR(tempPrice.start)} – ${formatPKR(tempPrice.end)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: TravelloTheme.primaryMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      RangeSlider(
                        values: tempPrice,
                        min: minPrice,
                        max: maxPrice,
                        divisions: 20,
                        activeColor: TravelloTheme.primaryMain,
                        inactiveColor: colorScheme(context)
                            .primary
                            .withValues(alpha: 0.15),
                        labels: RangeLabels(
                          formatPKR(tempPrice.start),
                          formatPKR(tempPrice.end),
                        ),
                        onChanged: (values) {
                          setModalState(() => tempPrice = values);
                        },
                      ),

                      SizedBox(height: 20.h),

                      // ── Departure Time ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Departure Time',
                              style: TravelloTheme.subtitle),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme(context)
                                  .primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '${tempTime.start.round().toString().padLeft(2, '0')}:00'
                              ' – '
                              '${tempTime.end.round() == 24 ? '24:00' : '${tempTime.end.round().toString().padLeft(2, '0')}:00'}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: TravelloTheme.primaryMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      RangeSlider(
                        values: tempTime,
                        min: 0,
                        max: 24,
                        divisions: 24,
                        activeColor: TravelloTheme.primaryMain,
                        inactiveColor: colorScheme(context)
                            .primary
                            .withValues(alpha: 0.15),
                        labels: RangeLabels(
                          '${tempTime.start.round().toString().padLeft(2, '0')}:00',
                          tempTime.end.round() == 24
                              ? '24:00'
                              : '${tempTime.end.round().toString().padLeft(2, '0')}:00',
                        ),
                        onChanged: (values) {
                          setModalState(() => tempTime = values);
                        },
                      ),

                      SizedBox(height: 20.h),

                      // ── Refundable Toggle ───────────────────────────────────
                      GestureDetector(
                        onTap: () => setModalState(
                            () => tempRefundable = !tempRefundable),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: tempRefundable
                                ? colorScheme(context)
                                    .primary
                                    .withValues(alpha: 0.06)
                                : TravelloTheme.paperLightContainerHighest,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: tempRefundable
                                  ? colorScheme(context)
                                      .primary
                                      .withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_shield_fill,
                                    color: tempRefundable
                                        ? TravelloTheme.primaryMain
                                        : Colors.grey.shade400,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 12.w),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Refundable flights only',
                                          style: TravelloTheme.subtitle),
                                      Text(
                                        'Show only cancellable tickets',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: tempRefundable,
                                onChanged: (value) {
                                  setModalState(() => tempRefundable = value);
                                },
                                activeThumbColor: TravelloTheme.primaryMain,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32.h),

                      // ── Apply Button ────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: R.rh(context, 52),
                        child: ElevatedButton(
                          onPressed: () {
                            // Commit temp values to parent state & run filter
                            setState(() {
                              _priceRange = tempPrice;
                              _departureTimeRange = tempTime;
                              _refundableOnly = tempRefundable;
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          child: Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: R.sp(context, 16),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromAirport = searchParams['fromAirport'] as Airport?;
    final toAirport = searchParams['toAirport'] as Airport?;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: TravelloTheme.primaryMain),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRoundTrip
                  ? _currentJourneyIndex == 0
                      ? '${fromAirport?.code ?? 'DEP'} → ${toAirport?.code ?? 'ARR'}'
                      : '${toAirport?.code ?? 'ARR'} → ${fromAirport?.code ?? 'DEP'}'
                  : '${fromAirport?.code ?? 'DEP'} → ${toAirport?.code ?? 'ARR'}',
              style: TextStyle(
                  fontSize: R.sp(context, 18), fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_filteredFlights.length} flights found',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_isRoundTrip && _currentJourneyIndex == 1) {
              // Go back to outbound selection
              setState(() {
                _currentJourneyIndex = 0;
                _selectedDate = searchParams['departureDate'] ?? DateTime.now();
                _selectedOutboundFlight = null;
              });
              _loadDummyFlights();
              _applyFilters();
            } else {
              Get.back();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            onPressed: _showFiltersBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Journey selector for round-trip
          if (_isRoundTrip)
            Container(
              color: TravelloTheme.paperLight,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: _currentJourneyIndex == 0
                            ? TravelloTheme.primaryMain
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: _selectedOutboundFlight != null
                              ? TravelloTheme.primaryMain
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedOutboundFlight != null)
                            Icon(
                              Icons.check_circle,
                              color: _currentJourneyIndex == 0
                                  ? Colors.white
                                  : TravelloTheme.primaryMain,
                              size: 18.sp,
                            ),
                          if (_selectedOutboundFlight != null)
                            SizedBox(width: 4.w),
                          Text(
                            'Outbound',
                            style: TextStyle(
                              color: _currentJourneyIndex == 0
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    CupertinoIcons.arrow_right,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: _currentJourneyIndex == 1
                            ? TravelloTheme.primaryMain
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: _currentJourneyIndex == 1
                              ? TravelloTheme.primaryMain
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Return',
                        style: TextStyle(
                          color: _currentJourneyIndex == 1
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Always-visible Search Modification Form
          _buildAlwaysVisibleSearchForm(),

          // Sort options
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12.0 : 16.0,
                  vertical: isMobile ? 6.0 : 8.0,
                ),
                color: TravelloTheme.backgroundLight,
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sort by:',
                                  style: TravelloTheme.caption
                                      .copyWith(fontSize: 11.sp)),
                              Text(
                                DateFormat('d MMM, E').format(_selectedDate),
                                style: TravelloTheme.subtitle2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: TravelloTheme.primaryMain,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSortChip('Recommended'),
                                SizedBox(width: 8.w),
                                _buildSortChip('Cheapest'),
                                SizedBox(width: 8.w),
                                _buildSortChip('Fastest'),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Text('Sort by:', style: TravelloTheme.caption),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSortChip('Recommended'),
                                  SizedBox(width: 8.w),
                                  _buildSortChip('Cheapest'),
                                  SizedBox(width: 8.w),
                                  _buildSortChip('Fastest'),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              DateFormat('d MMM, E').format(_selectedDate),
                              style: TravelloTheme.subtitle2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: TravelloTheme.primaryMain,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          // Flight list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFD4AF37)),
                        SizedBox(height: 16),
                        Text('Searching flights...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _filteredFlights.isEmpty
                    ? NoData(
                        image: ImgApi.emptyNotFound,
                        title: 'No Flights Found',
                        desc:
                            'No flights matched your search. Try different dates, routes, or adjust your filters.',
                        primaryTxtBtn: 'CHANGE SEARCH',
                        primaryAction: () => Get.back(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.r),
                        itemCount: _filteredFlights.length,
                        itemBuilder: (context, index) {
                          final flight = _filteredFlights[index];
                          return _buildFlightCard(flight);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlwaysVisibleSearchForm() {
    final fromAirport = searchParams['fromAirport'] as Airport?;
    final toAirport = searchParams['toAirport'] as Airport?;
    final departureDate = searchParams['departureDate'] as DateTime?;
    final returnDate = searchParams['returnDate'] as DateTime?;
    final tripType = searchParams['tripType'] as String? ?? 'One-way';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Calculate total passengers

    // Build passenger display text
    String passengerText = '';
    if (_adults > 0) {
      passengerText += '$_adults Adult${_adults > 1 ? "s" : ""}';
    }
    if (_children > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$_children Child${_children > 1 ? "ren" : ""}';
    }
    if (_infants > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$_infants Infant${_infants > 1 ? "s" : ""}';
    }

    return Container(
      color: TravelloTheme.primaryMain,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.0 : 16.0,
        vertical: isMobile ? 8.0 : 12.0,
      ),
      child: Column(
        children: [
          // Top row: Trip type tabs and passenger/economy info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Trip type tabs
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTripTypeTab(
                      'Round Trip', tripType == 'Round-trip', isMobile),
                  SizedBox(width: spacingUnit(isMobile ? 0.5 : 1)),
                  _buildTripTypeTab('One Way', tripType == 'One-way', isMobile),
                ],
              ),

              // Passenger and Class info
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.person,
                        color: Colors.white, size: isMobile ? 14 : 16),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        passengerText.isNotEmpty ? passengerText : '1 Adult',
                        style: TextStyle(
                            color: Colors.white, fontSize: isMobile ? 11 : 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacingUnit(isMobile ? 0.5 : 1)),
                    Text(
                      _selectedCabinClass,
                      style: TextStyle(
                          color: Colors.white, fontSize: isMobile ? 11 : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 6.0 : 12.0),

          // Bottom row: From/To, Dates, and Modify Search button
          Row(
            children: [
              // FROM - TO with swap button
              isMobile
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TravelloTheme.primaryMain.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_takeoff,
                              color: Colors.white70, size: 12.sp),
                          SizedBox(width: spacingUnit(0.25)),
                          Text(
                            fromAirport?.code ?? 'FROM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2.w),
                            child: Icon(Icons.swap_horiz,
                                color: Colors.white70, size: 14.sp),
                          ),
                          Icon(Icons.flight_land,
                              color: Colors.white70, size: 12.sp),
                          SizedBox(width: spacingUnit(0.25)),
                          Text(
                            toAirport?.code ?? 'TO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_takeoff,
                                color: Colors.white70, size: 16.sp),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                fromAirport?.code ?? 'FROM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: Icon(Icons.swap_horiz,
                                  color: Colors.white70, size: 18.sp),
                            ),
                            Icon(Icons.flight_land,
                                color: Colors.white70, size: 16.sp),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                toAirport?.code ?? 'TO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              SizedBox(width: spacingUnit(isMobile ? 0.5 : 1)),

              // Dates
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6.0 : 12.0,
                    vertical: isMobile ? 4.0 : 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.calendar,
                          color: Colors.white70, size: isMobile ? 12 : 16),
                      SizedBox(width: isMobile ? 2.0 : 4.0),
                      Flexible(
                        child: Text(
                          departureDate != null
                              ? (tripType == 'Round-trip' && returnDate != null
                                  ? '${DateFormat(isMobile ? 'd MMM' : 'd MMM').format(departureDate)} - ${DateFormat(isMobile ? 'd MMM' : 'd MMM').format(returnDate)}'
                                  : DateFormat(isMobile
                                          ? 'd MMM yyyy'
                                          : 'd MMM yyyy')
                                      .format(departureDate))
                              : 'Date',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: spacingUnit(isMobile ? 0.5 : 1)),

              // Modify Search Button
              ElevatedButton.icon(
                onPressed: () => _showSearchModificationModal(),
                icon: Icon(Icons.search, size: isMobile ? 14 : 16),
                label: Text(
                  'Modify',
                  style: TextStyle(fontSize: isMobile ? 11 : 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: TravelloTheme.primaryMain,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6.0 : 12.0,
                    vertical: isMobile ? 4.0 : 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                  ),
                ),
              ),
            ],
          ),

          // Different Airlines toggle (if round trip)
          if (tripType == 'Round-trip') ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    'Different Airlines for Round Trip',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(Icons.info_outline, color: Colors.white70, size: 14.sp),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripTypeTab(String label, bool isSelected, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10.0 : 12.0,
        vertical: isMobile ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? TravelloTheme.primaryMain : Colors.white70,
          fontSize: isMobile ? 11 : 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _showSearchModificationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSearchModificationSheet(),
    );
  }

  Widget _buildSearchModificationSheet() {
    // Local editable copies
    Airport? selectedFrom = searchParams['fromAirport'] as Airport?;
    Airport? selectedTo = searchParams['toAirport'] as Airport?;
    DateTime selectedDepartureDate =
        searchParams['departureDate'] ?? DateTime.now();
    DateTime? selectedReturnDate = searchParams['returnDate'];
    int selectedAdults = _adults;
    int selectedChildren = _children;
    int selectedInfants = _infants;
    String selectedClass = _selectedCabinClass;
    String tripType = searchParams['tripType'] ?? 'One-way';

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modify Search',
                      style: TextStyle(
                        fontSize: R.sp(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip Type Toggle
                      Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setFormState(() {
                                    tripType = 'One-way';
                                    selectedReturnDate = null;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: spacingUnit(1.25),
                                  ),
                                  decoration: BoxDecoration(
                                    color: tripType == 'One-way'
                                        ? TravelloTheme.primaryMain
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    'One-way',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tripType == 'One-way'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setFormState(() {
                                    tripType = 'Round-trip';
                                    selectedReturnDate = selectedDepartureDate
                                        .add(const Duration(days: 7));
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: spacingUnit(1.25),
                                  ),
                                  decoration: BoxDecoration(
                                    color: tripType == 'Round-trip'
                                        ? TravelloTheme.primaryMain
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    'Round-trip',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tripType == 'Round-trip'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // FROM Dropdown
                      _buildInlineAirportDropdown(
                        label: 'FROM',
                        icon: Icons.flight_takeoff,
                        selectedAirport: selectedFrom,
                        onChanged: (Airport? airport) {
                          setFormState(() {
                            selectedFrom = airport;
                          });
                        },
                      ),

                      SizedBox(height: 12.h),

                      // Swap Button
                      Center(
                        child: InkWell(
                          onTap: () {
                            setFormState(() {
                              final temp = selectedFrom;
                              selectedFrom = selectedTo;
                              selectedTo = temp;
                            });
                          },
                          borderRadius: BorderRadius.circular(30.r),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: TravelloTheme.primaryMain,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme(context)
                                      .primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.swap_vert,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // TO Dropdown
                      _buildInlineAirportDropdown(
                        label: 'TO',
                        icon: Icons.flight_land,
                        selectedAirport: selectedTo,
                        onChanged: (Airport? airport) {
                          setFormState(() {
                            selectedTo = airport;
                          });
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineDatePicker(
                              label: 'DEPARTURE',
                              date: selectedDepartureDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDepartureDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: TravelloTheme.primaryMain,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setFormState(() {
                                    selectedDepartureDate = picked;
                                    if (selectedReturnDate != null &&
                                        selectedReturnDate!.isBefore(picked)) {
                                      selectedReturnDate =
                                          picked.add(const Duration(days: 1));
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          if (tripType == 'Round-trip') ...[
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildInlineDatePicker(
                                label: 'RETURN',
                                date: selectedReturnDate ??
                                    selectedDepartureDate
                                        .add(const Duration(days: 7)),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedReturnDate ??
                                        selectedDepartureDate
                                            .add(const Duration(days: 7)),
                                    firstDate: selectedDepartureDate,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: TravelloTheme.primaryMain,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setFormState(() {
                                      selectedReturnDate = picked;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 16.h),

                      // Passengers
                      _buildInlinePassengerSelector(
                        adults: selectedAdults,
                        children: selectedChildren,
                        infants: selectedInfants,
                        onChanged: (Map<String, int> counts) {
                          setFormState(() {
                            selectedAdults = counts['adults']!;
                            selectedChildren = counts['children']!;
                            selectedInfants = counts['infants']!;
                          });
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Cabin Class
                      _buildInlineClassSelector(
                        selectedClass: selectedClass,
                        onChanged: (String? newClass) {
                          if (newClass != null) {
                            setFormState(() {
                              selectedClass = newClass;
                            });
                          }
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Update Button
                      SizedBox(
                        width: double.infinity,
                        height: R.rh(context, 50),
                        child: ElevatedButton(
                          onPressed: () {
                            // Validate
                            if (selectedFrom == null || selectedTo == null) {
                              Get.snackbar(
                                'Missing Information',
                                'Please select both origin and destination',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: TravelloTheme.primaryMain,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            if (selectedFrom?.code == selectedTo?.code) {
                              Get.snackbar(
                                'Same Located Selected',
                                'Origin and destination cannot be the same',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: TravelloTheme.primaryMain,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            // Update
                            setState(() {
                              searchParams['fromAirport'] = selectedFrom;
                              searchParams['toAirport'] = selectedTo;
                              searchParams['departureDate'] =
                                  selectedDepartureDate;
                              searchParams['returnDate'] = selectedReturnDate;
                              searchParams['adults'] = selectedAdults;
                              searchParams['children'] = selectedChildren;
                              searchParams['infants'] = selectedInfants;
                              searchParams['tripType'] = tripType;
                              searchParams['cabinClass'] = selectedClass;

                              _adults = selectedAdults;
                              _children = selectedChildren;
                              _infants = selectedInfants;
                              _selectedCabinClass = selectedClass;
                              _selectedDate = selectedDepartureDate;

                              if (tripType == 'Round-trip') {
                                _isRoundTrip = true;
                                _currentJourneyIndex = 0;
                                _selectedOutboundFlight = null;
                                _selectedReturnDate = selectedReturnDate;
                              } else {
                                _isRoundTrip = false;
                                _currentJourneyIndex = 0;
                              }
                            });

                            // Reload
                            _loadDummyFlights();
                            _applyFilters();

                            // Close modal
                            Navigator.pop(context);

                            // Success
                            Get.snackbar(
                              'Search Updated',
                              'Search updated: ${selectedFrom?.code} → ${selectedTo?.code}',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: TravelloTheme.primaryMain,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: R.r(context, 20)),
                              SizedBox(width: 8.w),
                              Text(
                                'Update Search',
                                style: TextStyle(
                                  fontSize: R.sp(context, 16),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineAirportDropdown({
    required String label,
    required IconData icon,
    required Airport? selectedAirport,
    required Function(Airport?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final result = await _showAirportSelectionModal(
          context: context,
          title: label,
          currentAirport: selectedAirport,
        );
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16.sp, color: TravelloTheme.primaryMain),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingUnit(0.75)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedAirport != null
                      ? '${selectedAirport.code} - ${selectedAirport.location}'
                      : 'Select Airport',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: selectedAirport != null
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down,
                    color: TravelloTheme.primaryMain, size: 20.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.calendar,
                    size: 14.sp, color: TravelloTheme.primaryMain),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingUnit(0.75)),
            Text(
              DateFormat('d MMM yyyy').format(date),
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('EEEE').format(date),
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePassengerSelector({
    required int adults,
    required int children,
    required int infants,
    required Function(Map<String, int>) onChanged,
  }) {
    // Build display text
    String passengerText = '';
    if (adults > 0) {
      passengerText += '$adults Adult${adults > 1 ? "s" : ""}';
    }
    if (children > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$children Child${children > 1 ? "ren" : ""}';
    }
    if (infants > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$infants Infant${infants > 1 ? "s" : ""}';
    }

    return InkWell(
      onTap: () async {
        final result = await _showPassengerSelectionModal(
          context,
          adults,
          children,
          infants,
        );
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.person_2_fill,
                    size: 16.sp, color: TravelloTheme.primaryMain),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  'PASSENGERS',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  passengerText.isNotEmpty ? passengerText : '1 Adult',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: spacingUnit(0.75)),
                const Icon(Icons.keyboard_arrow_down,
                    color: TravelloTheme.primaryMain),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineClassSelector({
    required String selectedClass,
    required Function(String?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final result = await _showClassSelectionModal(context, selectedClass);
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.airline_seat_recline_extra,
                    size: 16.sp, color: TravelloTheme.primaryMain),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  'CABIN CLASS',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  selectedClass,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: spacingUnit(0.75)),
                const Icon(Icons.keyboard_arrow_down,
                    color: TravelloTheme.primaryMain),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label) {
    final selected = _sortBy == label;
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setChipState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setChipState(() => isHovered = true),
          onExit: (_) => setChipState(() => isHovered = false),
          child: GestureDetector(
            onTap: () {
              setState(() => _sortBy = label);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? TravelloTheme.primaryMain
                    : isHovered
                        ? TravelloTheme.primaryMain.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: selected
                      ? TravelloTheme.primaryMain
                      : isHovered
                          ? TravelloTheme.primaryMain
                          : Colors.grey.withValues(alpha: 0.3),
                  width: selected || isHovered ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? colorScheme(context).onPrimary
                      : colorScheme(context).onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Passenger selection modal (like image 1)
  Future<Map<String, int>?> _showPassengerSelectionModal(BuildContext context,
      int currentAdults, int currentChildren, int currentInfants) async {
    int adults = currentAdults;
    int children = currentChildren;
    int infants = currentInfants;

    return await showDialog<Map<String, int>>(
      context: context,
      barrierColor: Colors.grey.shade800.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              child: Container(
                constraints: BoxConstraints(maxWidth: R.r(context, 400)),
                padding: EdgeInsets.all(R.r(context, 24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    Text(
                      'Passengers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: R.sp(context, 22),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Adult
                    _buildPassengerRow(
                      label: 'Adults',
                      subtitle: '12+ years',
                      count: adults,
                      onDecrement: adults > 1
                          ? () => setModalState(() {
                                adults--;
                                // Clamp infants to new adult count
                                if (infants > adults) infants = adults;
                              })
                          : null,
                      onIncrement:
                          adults < 9 && (adults + children + infants) < 9
                              ? () => setModalState(() => adults++)
                              : null,
                    ),

                    SizedBox(height: 20.h),

                    // Child
                    _buildPassengerRow(
                      label: 'Children',
                      subtitle: '2-11 years',
                      count: children,
                      onDecrement: children > 0
                          ? () => setModalState(() => children--)
                          : null,
                      onIncrement:
                          children < 9 && (adults + children + infants) < 9
                              ? () => setModalState(() => children++)
                              : null,
                    ),

                    SizedBox(height: 20.h),

                    // Infant (cannot exceed adults; total must stay ≤ 9)
                    _buildPassengerRow(
                      label: 'Infants',
                      subtitle: 'Under 2 years',
                      count: infants,
                      onDecrement: infants > 0
                          ? () => setModalState(() => infants--)
                          : null,
                      onIncrement:
                          infants < adults && (adults + children + infants) < 9
                              ? () => setModalState(() => infants++)
                              : null,
                    ),

                    SizedBox(height: 24.h),

                    // Done button
                    SizedBox(
                      width: double.infinity,
                      height: R.rh(context, 50),
                      child: ElevatedButton(
                        onPressed: () {
                          int total = adults + children + infants;
                          if (total < 1) total = 1;
                          Navigator.pop(context, {
                            'adults': adults > 0 ? adults : 1,
                            'children': children,
                            'infants': infants,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: R.sp(context, 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPassengerRow({
    required String label,
    required String subtitle,
    required int count,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: R.sp(context, 16),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2.0.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: R.sp(context, 13),
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Minus button
            InkWell(
              onTap: onDecrement,
              borderRadius: BorderRadius.circular(50.r),
              child: Container(
                width: R.r(context, 36),
                height: R.r(context, 36),
                decoration: BoxDecoration(
                  color: onDecrement != null
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.remove,
                  size: R.r(context, 20),
                  color:
                      onDecrement != null ? Colors.black : Colors.grey.shade500,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            // Count
            Container(
              width: R.r(context, 40),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: R.sp(context, 20),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            // Plus button
            InkWell(
              onTap: onIncrement,
              borderRadius: BorderRadius.circular(50.r),
              child: Container(
                width: R.r(context, 36),
                height: R.r(context, 36),
                decoration: BoxDecoration(
                  color: onIncrement != null
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: R.r(context, 20),
                  color:
                      onIncrement != null ? Colors.black : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Class selection modal (like image 2)
  Future<String?> _showClassSelectionModal(
      BuildContext context, String currentClass) async {
    String? selectedClass = currentClass;

    return await showDialog<String>(
      context: context,
      barrierColor: Colors.grey.shade800.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r)),
              child: Container(
                constraints: BoxConstraints(maxWidth: R.r(context, 450)),
                padding: EdgeInsets.all(R.r(context, 24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    Text(
                      'Cabin Class',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: R.sp(context, 22),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Economy
                    _buildClassOption(
                      label: 'Economy',
                      icon: Icons.airline_seat_recline_normal,
                      iconColor: const Color(0xFF3B82F6),
                      isSelected: selectedClass == 'Economy',
                      onTap: () =>
                          setModalState(() => selectedClass = 'Economy'),
                    ),

                    SizedBox(height: 12.h),

                    // Premium Economy
                    _buildClassOption(
                      label: 'Premium Economy',
                      icon: Icons.airline_seat_recline_extra,
                      iconColor: const Color(0xFFD946EF),
                      isSelected: selectedClass == 'Premium Economy',
                      onTap: () => setModalState(
                          () => selectedClass = 'Premium Economy'),
                    ),

                    SizedBox(height: 12.h),

                    // Business
                    _buildClassOption(
                      label: 'Business',
                      icon: Icons.airline_seat_flat,
                      iconColor: const Color(0xFFF97316),
                      isSelected: selectedClass == 'Business',
                      onTap: () =>
                          setModalState(() => selectedClass = 'Business'),
                    ),

                    SizedBox(height: 12.h),

                    // First Class
                    _buildClassOption(
                      label: 'First Class',
                      icon: Icons.airline_seat_flat_angled,
                      iconColor: const Color(0xFFD4AF37),
                      isSelected: selectedClass == 'First Class',
                      onTap: () =>
                          setModalState(() => selectedClass = 'First Class'),
                    ),

                    SizedBox(height: 24.h),

                    // Done button
                    SizedBox(
                      width: double.infinity,
                      height: R.rh(context, 50),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, selectedClass);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: R.sp(context, 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClassOption({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14.0,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: R.r(context, 28),
              color: iconColor,
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                fontSize: R.sp(context, 16),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              width: R.r(context, 24),
              height: R.r(context, 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<Airport?> _showAirportSelectionModal({
    required BuildContext context,
    required String title,
    Airport? currentAirport,
  }) async {
    return await showModalBottomSheet<Airport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        String searchQuery = '';
        final TextEditingController searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter airports based on search query
            final filteredAirports = airportList.where((airport) {
              final query = searchQuery.toLowerCase();
              return airport.location.toLowerCase().contains(query) ||
                  airport.name.toLowerCase().contains(query) ||
                  airport.code.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
              ),
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),

                  const Text('Select Airport', style: TravelloTheme.title2),
                  SizedBox(height: 16.h),

                  // Search field
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by city, airport or code',
                      prefixIcon: const Icon(CupertinoIcons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                  CupertinoIcons.clear_circled_solid),
                              onPressed: () {
                                setModalState(() {
                                  searchController.clear();
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Airport list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredAirports.length,
                      itemBuilder: (context, index) {
                        final airport = filteredAirports[index];

                        return ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: const Icon(
                              CupertinoIcons.airplane,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          title: Text(
                            airport.location,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            airport.name,
                            style: TextStyle(
                              fontSize: 12.sp,
                            ),
                          ),
                          trailing: Text(
                            airport.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, airport);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFlightCard(FlightResult flight) {
    final fromAirport = searchParams['fromAirport'] as Airport?;
    final toAirport = searchParams['toAirport'] as Airport?;

    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform:
                Matrix4.translationValues(0.0, isHovered ? -4.0 : 0.0, 0.0),
            child: Card(
              margin: EdgeInsets.only(bottom: 16.h),
              elevation: isHovered ? 8 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: InkWell(
                onTap: () {
                  // Handle round-trip selection
                  if (_isRoundTrip && _currentJourneyIndex == 0) {
                    // Outbound selected, move to return
                    setState(() {
                      _selectedOutboundFlight = flight;
                      _currentJourneyIndex = 1;
                      _selectedDate = _selectedReturnDate ?? _selectedDate;
                    });
                    _fetchFlights();

                    // Show message
                    Get.snackbar(
                      'Outbound Selected',
                      'Outbound flight selected. Now select return flight.',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: TravelloTheme.primaryMain,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  } else {
                    // One-way or return journey selected, go directly to passenger form
                    Get.toNamed(
                      AppLink.bookingStep1,
                      arguments: {
                        'flight': flight,
                        'searchParams': searchParams,
                        'isRoundTrip': _isRoundTrip,
                        'outboundFlight': _selectedOutboundFlight,
                        'returnFlight': _isRoundTrip ? flight : null,
                      },
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      // Badge
                      if (flight.badge.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: flight.badge == 'Cheapest'
                                      ? [Colors.green, Colors.greenAccent]
                                      : flight.badge == 'Fastest'
                                          ? [Colors.blue, Colors.blueAccent]
                                          : [
                                              Colors.orange,
                                              Colors.orangeAccent
                                            ],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    flight.badge == 'Cheapest'
                                        ? CupertinoIcons.money_dollar_circle
                                        : flight.badge == 'Fastest'
                                            ? CupertinoIcons.bolt_fill
                                            : CupertinoIcons.star_fill,
                                    size: 14.sp,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    flight.badge,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      if (flight.badge.isNotEmpty) SizedBox(height: 12.h),

                      Row(
                        children: [
                          // Airline logo
                          Container(
                            width: R.r(context, 50),
                            height: R.r(context, 50),
                            decoration: BoxDecoration(
                              color: TravelloTheme.primaryMainContainer,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: (flight.airlineLogo.isNotEmpty &&
                                      flight.airlineLogo
                                          .toLowerCase()
                                          .startsWith('http'))
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10.r),
                                      child: Image.network(
                                        flight.airlineLogo,
                                        width: 34,
                                        height: 34,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.flight_takeoff,
                                          size: 24.sp,
                                          color: TravelloTheme.primaryMain,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.flight_takeoff,
                                      size: 24.sp,
                                      color: TravelloTheme.primaryMain,
                                    ),
                            ),
                          ),

                          SizedBox(width: 16.w),

                          // Flight info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Departure
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          flight.departureTime,
                                          style: TravelloTheme.title2,
                                        ),
                                        Text(
                                          fromAirport?.code ?? 'DEP',
                                          style: TravelloTheme.caption,
                                        ),
                                      ],
                                    ),

                                    // Duration and stops
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            flight.duration,
                                            style: TravelloTheme.caption,
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // Left departure dot (hollow)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: colorScheme(context)
                                                        .primary,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                              // Line segment (left half if stop, full if non-stop)
                                              Expanded(
                                                child: Container(
                                                  height: 2,
                                                  color: colorScheme(context)
                                                      .primary,
                                                ),
                                              ),
                                              // Stop dot in exact center (only if stop exists)
                                              if (flight.stops > 0) ...[
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: colorScheme(context)
                                                        .primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                // Line segment right half
                                                Expanded(
                                                  child: Container(
                                                    height: 2,
                                                    color: colorScheme(context)
                                                        .primary,
                                                  ),
                                                ),
                                              ],
                                              // Right arrival dot (filled)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: colorScheme(context)
                                                      .primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            flight.stops == 0
                                                ? 'Non-stop'
                                                : '${flight.stops} ${flight.stops == 1 ? 'stop' : 'stops'}',
                                            style: TravelloTheme.caption,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrival
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          flight.arrivalTime,
                                          style: TravelloTheme.title2,
                                        ),
                                        Text(
                                          toAirport?.code ?? 'ARR',
                                          style: TravelloTheme.caption,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                SizedBox(height: 8.h),

                                // Airline name and flight info
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${flight.airlineName} • ${flight.airlineCode}',
                                        style: TravelloTheme.caption,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      flight.cabinClass,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: TravelloTheme.primaryMain,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 6.h),

                                // Flight number, baggage, seats
                                Row(
                                  children: [
                                    if (flight.flightNumber != null) ...[
                                      Icon(Icons.confirmation_number_outlined,
                                          size: 12.sp,
                                          color: Colors.grey.shade500),
                                      SizedBox(width: 3.w),
                                      Text(
                                        flight.flightNumber!,
                                        style: TextStyle(
                                            fontSize: 11.sp,
                                            color: Colors.grey.shade600),
                                      ),
                                      SizedBox(width: 10.w),
                                    ],
                                    if (flight.baggage != null) ...[
                                      Icon(Icons.luggage_outlined,
                                          size: 12.sp,
                                          color: Colors.grey.shade500),
                                      SizedBox(width: 3.w),
                                      Text(
                                        flight.baggage!,
                                        style: TextStyle(
                                            fontSize: 11.sp,
                                            color: Colors.grey.shade600),
                                      ),
                                      SizedBox(width: 10.w),
                                    ],
                                    if (flight.seatsAvailable != null) ...[
                                      Icon(Icons.event_seat_outlined,
                                          size: 12.sp,
                                          color: flight.seatsAvailable! <= 5
                                              ? Colors.orange
                                              : Colors.grey.shade500),
                                      SizedBox(width: 3.w),
                                      Text(
                                        '${flight.seatsAvailable} left',
                                        style: TextStyle(
                                            fontSize: 11.sp,
                                            color: flight.seatsAvailable! <= 5
                                                ? Colors.orange
                                                : Colors.grey.shade600,
                                            fontWeight:
                                                flight.seatsAvailable! <= 5
                                                    ? FontWeight.w600
                                                    : FontWeight.normal),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      Divider(
                          height: 1, color: Colors.grey.withValues(alpha: 0.2)),

                      SizedBox(height: 12.h),

                      // Price and select button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatPKR(flight.price),
                                style: TravelloTheme.title2.copyWith(
                                  color: TravelloTheme.primaryMain,
                                ),
                              ),
                              Text(
                                flight.isRefundable
                                    ? 'Refundable'
                                    : 'Non-refundable',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: flight.isRefundable
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              // Auth gate at Select — industry standard (browsing was free)
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final isGuest = await AuthService.isGuestMode();
                              if (isGuest && mounted) {
                                AuthGateSheet.show(nav.context,
                                    action: 'to book this flight');
                                return;
                              }
                              // Handle round-trip selection
                              if (_isRoundTrip && _currentJourneyIndex == 0) {
                                // Outbound selected, move to return
                                setState(() {
                                  _selectedOutboundFlight = flight;
                                  _currentJourneyIndex = 1;
                                  _selectedDate =
                                      _selectedReturnDate ?? _selectedDate;
                                });
                                _fetchFlights();

                                // Show message
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Outbound flight selected. Now select return flight.'),
                                    backgroundColor: TravelloTheme.primaryMain,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                // One-way or return journey selected, go directly to passenger form
                                Get.toNamed(
                                  AppLink.bookingStep1,
                                  arguments: {
                                    'flight': flight,
                                    'searchParams': searchParams,
                                    'isRoundTrip': _isRoundTrip,
                                    'outboundFlight': _selectedOutboundFlight,
                                    'returnFlight':
                                        _isRoundTrip ? flight : null,
                                  },
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TravelloTheme.primaryMain,
                              foregroundColor: colorScheme(context).onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: const Text(
                              'Select',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
      },
    );
  }
}
