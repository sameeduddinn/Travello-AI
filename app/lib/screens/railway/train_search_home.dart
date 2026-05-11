import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/widgets/range_date_picker.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class TrainSearchHome extends StatefulWidget {
  const TrainSearchHome({super.key});

  @override
  State<TrainSearchHome> createState() => _TrainSearchHomeState();
}

class _TrainSearchHomeState extends State<TrainSearchHome>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Trip type
  String _tripType = 'One-way';
  final List<String> _tripTypes = ['One-way', 'Round-trip'];

  // Selected stations
  RailwayStation? _fromStation;
  RailwayStation? _toStation;

  // Date
  DateTime? _travelDate;
  DateTime? _returnDate;

  // Passengers
  int _adults = 1;
  int _children = 0;
  int _infants = 0;

  // Class / Seat type
  String _trainClass = 'Economy (Seat)';
  String? _selectedRank;

  // Seat types with prices
  static const Map<String, double> _seatTypePrices = {
    'Economy (Seat)': 3550.0,
    'Economy (Berth)': 3650.0,
    'AC Lower / Standard (Berth)': 6900.0,
    'AC Business': 9950.0,
  };

  final List<String> _trainClasses = [
    'Economy (Seat)',
    'Economy (Berth)',
    'AC Lower / Standard (Berth)',
    'AC Business',
  ];

  final List<String> _rankOptions = ['01', '02', '03', '04'];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();

    // Pre-fill destination station if coming from Top Destinations card
    final args = Get.arguments;
    if (args is Map && args['toCode'] != null) {
      final code = args['toCode'] as String;
      final toCity = args['toCity'] as String? ?? '';
      final stations = PakistanRailwayStations.getAllStations();
      try {
        // Try exact code match first
        _toStation = stations.firstWhere((s) => s.code == code);
      } catch (_) {
        try {
          // Fallback: match by city name (case-insensitive)
          _toStation = stations.firstWhere(
            (s) => s.city.toLowerCase() == toCity.toLowerCase(),
          );
        } catch (_) {
          // No match found — user picks manually
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const Map<String, List<String>> _rankToClasses = {
    '01': ['Economy (Seat)', 'Economy (Berth)'],
    '02': ['Economy (Seat)', 'Economy (Berth)', 'AC Lower / Standard (Berth)'],
    '03': ['AC Lower / Standard (Berth)', 'AC Business'],
    '04': ['AC Business'],
  };

  void _showSeatTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String tempClass = _trainClass;
        String? tempRank = _selectedRank;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredClasses = tempRank != null
                ? (_rankToClasses[tempRank] ?? _trainClasses)
                : _trainClasses;
            return Container(
              decoration: const BoxDecoration(
                color: TravelloTheme.paperLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grabber
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const Text('Select Seat Type', style: TravelloTheme.title2),
                  const SizedBox(height: 16),

                  // Rank dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.person,
                              size: 15, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Rank:',
                            style: TravelloTheme.caption
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tempRank,
                            isExpanded: true,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Please choose'),
                            ),
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.keyboard_arrow_down),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            items: _rankOptions
                                .map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (val) {
                              final newClasses =
                                  _rankToClasses[val] ?? _trainClasses;
                              setSheetState(() {
                                tempRank = val;
                                if (!newClasses.contains(tempClass)) {
                                  tempClass = newClasses.first;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Seat type options
                  ...filteredClasses.map((seatType) {
                    final isSelected = tempClass == seatType;

                    IconData seatIcon;
                    Color seatColor;
                    switch (seatType) {
                      case 'Economy (Seat)':
                        seatIcon = Icons.airline_seat_recline_normal;
                        seatColor = Colors.blue;
                        break;
                      case 'Economy (Berth)':
                        seatIcon = Icons.airline_seat_flat;
                        seatColor = Colors.teal;
                        break;
                      case 'AC Lower / Standard (Berth)':
                        seatIcon = Icons.hotel;
                        seatColor = Colors.indigo;
                        break;
                      case 'AC Business':
                        seatIcon = Icons.business_center;
                        seatColor = Colors.purple;
                        break;
                      default:
                        seatIcon = Icons.train;
                        seatColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD4AF37)
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: InkWell(
                        onTap: () => setSheetState(() => tempClass = seatType),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              RadioGroup<String>(
                                groupValue: tempClass,
                                onChanged: (v) =>
                                    setSheetState(() => tempClass = seatType),
                                child: Radio<String>(
                                  value: seatType,
                                  activeColor: const Color(0xFFD4AF37),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: seatColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    Icon(seatIcon, color: seatColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  seatType,
                                  style: TravelloTheme.subtitle.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text(
                                'Rs.${(_seatTypePrices[seatType] ?? 0).toStringAsFixed(0)}',
                                style: TravelloTheme.subtitle.copyWith(
                                  color: const Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Confirm button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _trainClass = tempClass;
                        _selectedRank = tempRank;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _swapStations() {
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
    });
  }

  Future<void> _selectTravelDate() async {
    if (_tripType == 'Round-trip') {
      // Open range picker for both dates together
      final range = await RangeDatePickerSheet.show(
        context,
        startLabel: 'Departure',
        endLabel: 'Return',
        initialStart: _travelDate,
        initialEnd: _returnDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        singleDate: false,
      );
      if (range != null) {
        setState(() {
          _travelDate = range.start;
          _returnDate = range.end != range.start ? range.end : null;
        });
      }
    } else {
      final range = await RangeDatePickerSheet.show(
        context,
        startLabel: 'Departure',
        initialStart: _travelDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        singleDate: true,
      );
      if (range != null) {
        setState(() {
          _travelDate = range.start;
          if (_returnDate != null && _returnDate!.isBefore(_travelDate!)) {
            _returnDate = null;
          }
        });
      }
    }
  }

  Future<void> _selectReturnDate() async {
    if (_tripType != 'Round-trip') return;
    final range = await RangeDatePickerSheet.show(
      context,
      startLabel: 'Departure',
      endLabel: 'Return',
      initialStart: _travelDate,
      initialEnd: _returnDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      singleDate: false,
    );
    if (range != null) {
      setState(() {
        _travelDate = range.start;
        _returnDate = range.end != range.start ? range.end : null;
      });
    }
  }

  void _showPassengerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const Text('Passengers', style: TravelloTheme.title2),
                  const SizedBox(height: 24),

                  // Adults
                  _buildPassengerRow(
                    context,
                    setModalState,
                    'Adults',
                    '12+ years',
                    _adults,
                    (val) {
                      if (val >= 1 && val <= 9) {
                        setModalState(() => _adults = val);
                        setState(() => _adults = val);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Children
                  _buildPassengerRow(
                    context,
                    setModalState,
                    'Children',
                    '3-11 years',
                    _children,
                    (val) {
                      if (val >= 0 && val <= 9) {
                        setModalState(() => _children = val);
                        setState(() => _children = val);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Infants
                  _buildPassengerRow(
                    context,
                    setModalState,
                    'Infants',
                    'Under 3 years',
                    _infants,
                    (val) {
                      if (val >= 0 && val <= 9 && val <= _adults) {
                        setModalState(() => _infants = val);
                        setState(() => _infants = val);
                      }
                    },
                  ),

                  if (_infants > _adults)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Each infant must be accompanied by an adult',
                        style:
                            TravelloTheme.caption.copyWith(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done'),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPassengerRow(
    BuildContext context,
    StateSetter setModalState,
    String title,
    String subtitle,
    int count,
    Function(int) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TravelloTheme.subtitle),
            Text(subtitle, style: TravelloTheme.caption),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
              icon: Icon(
                CupertinoIcons.minus_circle_fill,
                color: count > 0 ? const Color(0xFFD4AF37) : Colors.grey,
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                '$count',
                style: TravelloTheme.subtitle,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: () => onChanged(count + 1),
              icon: const Icon(
                CupertinoIcons.plus_circle_fill,
                color: Color(0xFFD4AF37),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectStation(bool isFrom) async {
    final RailwayStation? selected = await showModalBottomSheet<RailwayStation>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StationSearchBottomSheet(
        excludeStation: isFrom ? _toStation : _fromStation,
      ),
    );

    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromStation = selected;
        } else {
          _toStation = selected;
        }
      });
    }
  }

  Future<void> _searchTrains() async {
    if (_fromStation == null || _toStation == null) {
      _showValidationError('Please select departure and arrival stations');
      return;
    }

    if (_travelDate == null) {
      _showValidationError('Please select travel date');
      return;
    }

    if (_tripType == 'Round-trip' && _returnDate == null) {
      _showValidationError('Please select return date');
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      _showValidationError('No internet connection. Please reconnect and try again.');
      return;
    }

    // Navigate to train results
    Get.toNamed(
      '/train-results',
      arguments: {
        'tripType': _tripType,
        'fromStation': _fromStation,
        'toStation': _toStation,
        'travelDate': _travelDate,
        'departureDate': _travelDate,
        'returnDate': _returnDate,
        'adults': _adults,
        'children': _children,
        'infants': _infants,
        'trainClass': _trainClass,
        'seatRank': _selectedRank,
      },
    );
  }

  void _showValidationError(String message) {
    Get.snackbar(
      'Validation Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFD32F2F),
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Premium Fintech Header ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFFD4AF37), size: 18),
                onPressed: () => Get.back(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFDAB853),
                      Color(0xFFE8C76A),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: constraints.maxHeight > 120 ? 24 : 16,
                          bottom: 8,
                        ),
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.train_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Train Booking',
                                            style: TextStyle(
                                              fontSize: R.sp(context, 28),
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.8,
                                              height: 1.1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Travel smart, arrive refreshed',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              letterSpacing: 0.2,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Trip type selector
                  Container(
                    color: TravelloTheme.paperLight,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: _tripTypes.map((type) {
                        final isSelected = _tripType == type;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _tripType = type;
                                  if (type != 'Round-trip') {
                                    _returnDate = null;
                                  }
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD4AF37)
                                      : colorScheme(context)
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD4AF37)
                                        : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : colorScheme(context).onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // From and To stations
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TravelloTheme.paperLight,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // From
                        InkWell(
                          onTap: () => _selectStation(true),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.train_style_one,
                                  color: Color(0xFFD4AF37),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('From',
                                          style: TravelloTheme.caption),
                                      const SizedBox(height: 4),
                                      Text(
                                        _fromStation?.name ??
                                            'Select departure station',
                                        style: TravelloTheme.subtitle,
                                      ),
                                      if (_fromStation != null)
                                        Text(
                                          _fromStation!.city,
                                          style: TravelloTheme.caption,
                                        ),
                                    ],
                                  ),
                                ),
                                if (_fromStation != null)
                                  Text(
                                    _fromStation!.code,
                                    style: TravelloTheme.title2.copyWith(
                                      color: const Color(0xFFD4AF37),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Swap button
                        Divider(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.2)),
                        Container(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: _swapStations,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4AF37),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.arrow_up_arrow_down,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.2)),

                        // To
                        InkWell(
                          onTap: () => _selectStation(false),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.train_style_one,
                                  color: Color(0xFFD4AF37),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('To',
                                          style: TravelloTheme.caption),
                                      const SizedBox(height: 4),
                                      Text(
                                        _toStation?.name ??
                                            'Select arrival station',
                                        style: TravelloTheme.subtitle,
                                      ),
                                      if (_toStation != null)
                                        Text(
                                          _toStation!.city,
                                          style: TravelloTheme.caption,
                                        ),
                                    ],
                                  ),
                                ),
                                if (_toStation != null)
                                  Text(
                                    _toStation!.code,
                                    style: TravelloTheme.title2.copyWith(
                                      color: const Color(0xFFD4AF37),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Travel date and return date
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _tripType == 'Round-trip'
                        ? Row(
                            children: [
                              // Departure date
                              Expanded(
                                child: InkWell(
                                  onTap: _selectTravelDate,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: TravelloTheme.paperLight,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.calendar,
                                              color: Color(0xFFD4AF37),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Departure',
                                                style: TravelloTheme.caption),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _travelDate != null
                                              ? '${_travelDate!.day} ${_getMonthName(_travelDate!.month).substring(0, 3)}'
                                              : 'Select date',
                                          style: TravelloTheme.subtitle,
                                        ),
                                        if (_travelDate != null)
                                          Text(
                                            _getDayName(_travelDate!.weekday),
                                            style: TravelloTheme.caption,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Return date
                              Expanded(
                                child: InkWell(
                                  onTap: _selectReturnDate,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: TravelloTheme.paperLight,
                                      borderRadius: BorderRadius.circular(16),
                                      border: _returnDate == null
                                          ? Border.all(
                                              color: const Color(0xFFD4AF37)
                                                  .withValues(alpha: 0.3),
                                              width: 1.5,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.calendar,
                                              color: Color(0xFFD4AF37),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Return',
                                                style: TravelloTheme.caption),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _returnDate != null
                                              ? '${_returnDate!.day} ${_getMonthName(_returnDate!.month).substring(0, 3)}'
                                              : 'Select date',
                                          style: TravelloTheme.subtitle,
                                        ),
                                        if (_returnDate != null)
                                          Text(
                                            _getDayName(_returnDate!.weekday),
                                            style: TravelloTheme.caption,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: _selectTravelDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: TravelloTheme.paperLight,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.calendar,
                                    color: Color(0xFFD4AF37),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Travel Date',
                                            style: TravelloTheme.caption),
                                        const SizedBox(height: 4),
                                        Text(
                                          _travelDate != null
                                              ? '${_travelDate!.day} ${_getMonthName(_travelDate!.month)} ${_travelDate!.year}'
                                              : 'Select travel date',
                                          style: TravelloTheme.subtitle,
                                        ),
                                        if (_travelDate != null)
                                          Text(
                                            _getDayName(_travelDate!.weekday),
                                            style: TravelloTheme.caption,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Passengers and Class
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Passengers
                        Expanded(
                          child: InkWell(
                            onTap: _showPassengerPicker,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: TravelloTheme.paperLight,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.person_2,
                                        size: 20,
                                        color: Color(0xFFD4AF37),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Passengers',
                                          style: TravelloTheme.caption),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_adults + _children + _infants} ${(_adults + _children + _infants) == 1 ? "Passenger" : "Passengers"}',
                                    style: TravelloTheme.subtitle,
                                  ),
                                  Text(
                                    'A: $_adults, C: $_children, I: $_infants',
                                    style: TravelloTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Train class
                        Expanded(
                          child: InkWell(
                            onTap: _showSeatTypeDialog,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: TravelloTheme.paperLight,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_seal,
                                        size: 20,
                                        color: Color(0xFFD4AF37),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Class',
                                          style: TravelloTheme.caption),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _trainClass,
                                    style: TravelloTheme.subtitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedRank != null)
                                    Text(
                                      'Rank: $_selectedRank',
                                      style: TravelloTheme.caption.copyWith(
                                        color: const Color(0xFFD4AF37),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // Sticky bottom button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _searchTrains,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, R.rh(context, 56)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.search),
                SizedBox(width: 8),
                Text(
                  'Search Trains',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  String _getDayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }
}

// Station Search Bottom Sheet
class _StationSearchBottomSheet extends StatefulWidget {
  final RailwayStation? excludeStation;

  const _StationSearchBottomSheet({this.excludeStation});

  @override
  State<_StationSearchBottomSheet> createState() =>
      _StationSearchBottomSheetState();
}

class _StationSearchBottomSheetState extends State<_StationSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<RailwayStation> _filteredStations =
      PakistanRailwayStations.getAllStations();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStations);
  }

  void _filterStations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStations =
          PakistanRailwayStations.getAllStations().where((station) {
        return station.name.toLowerCase().contains(query) ||
            station.city.toLowerCase().contains(query) ||
            station.code.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Text('Select Station', style: TravelloTheme.title2),
              const SizedBox(height: 16),

              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by station, city or code',
                  prefixIcon: const Icon(CupertinoIcons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Station list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredStations.length,
                  itemBuilder: (context, index) {
                    final station = _filteredStations[index];
                    final isExcluded =
                        widget.excludeStation?.code == station.code;

                    return ListTile(
                      enabled: !isExcluded,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isExcluded
                              ? Colors.grey.withValues(alpha: 0.2)
                              : const Color(0xFFD4AF37).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.train_style_one,
                          color: isExcluded
                              ? Colors.grey
                              : const Color(0xFFD4AF37),
                        ),
                      ),
                      title: Text(
                        station.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExcluded ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        station.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: isExcluded ? Colors.grey : null,
                        ),
                      ),
                      trailing: Text(
                        station.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExcluded
                              ? Colors.grey
                              : const Color(0xFFD4AF37),
                        ),
                      ),
                      onTap: isExcluded
                          ? null
                          : () {
                              Navigator.pop(context, station);
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
  }
}
