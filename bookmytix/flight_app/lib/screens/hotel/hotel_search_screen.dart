import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/widgets/range_date_picker.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HotelSearchScreen extends StatefulWidget {
  const HotelSearchScreen({super.key});

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCity;

  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  int _adults = 2;
  int _children = 0;
  int _rooms = 1;

  final List<Map<String, dynamic>> _recentSearches = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

    // Pre-fill city if coming from Top Destinations card
    final args = Get.arguments;
    if (args is Map && args['cityName'] != null) {
      final cityName = args['cityName'] as String;
      if (_cityProvinceMap.containsKey(cityName)) {
        setState(() {
          _selectedCity = cityName;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // BUG 6 FIX: removed dead _guestsLabel getter (was never used)
  // BUG 7 FIX: removed tourism cities that have no hotel data
  // (Murree, Swat, Gilgit, Hunza, Skardu removed — empty results with no feedback)
  final Map<String, String> _cityProvinceMap = const {
    'Karachi': 'Sindh',
    'Lahore': 'Punjab',
    'Islamabad': 'Islamabad Capital Territory',
    'Rawalpindi': 'Punjab',
    'Peshawar': 'KPK',
    'Quetta': 'Balochistan',
    'Multan': 'Punjab',
    'Faisalabad': 'Punjab',
    'Sialkot': 'Punjab',
    'Gujranwala': 'Punjab',
    'Hyderabad': 'Sindh',
    'Abbottabad': 'KPK',
    'Bahawalpur': 'Punjab',
    'Skardu': 'Gilgit-Baltistan',
    'Hunza': 'Gilgit-Baltistan',
    'Gilgit': 'Gilgit-Baltistan',
    'Swat': 'KPK',
    'Murree': 'Punjab',
  };

  int get _nights {
    if (_checkInDate == null || _checkOutDate == null) return 1;
    return _checkOutDate!.difference(_checkInDate!).inDays;
  }

  String _monthName(int m) => [
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
      ][m - 1];

  String _dayName(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  void _selectCheckIn() async {
    // Open range picker covering both check-in and check-out at once
    final range = await RangeDatePickerSheet.show(
      context,
      startLabel: 'Check-in',
      endLabel: 'Check-out',
      initialStart: _checkInDate,
      initialEnd: _checkOutDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      singleDate: false,
    );
    if (range != null) {
      setState(() {
        _checkInDate = range.start;
        _checkOutDate = range.end != range.start
            ? range.end
            : range.start.add(const Duration(days: 1));
      });
    }
  }

  void _selectCheckOut() async {
    // Also open the range picker so user can adjust both dates
    final range = await RangeDatePickerSheet.show(
      context,
      startLabel: 'Check-in',
      endLabel: 'Check-out',
      initialStart: _checkInDate,
      initialEnd: _checkOutDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      singleDate: false,
    );
    if (range != null) {
      setState(() {
        _checkInDate = range.start;
        _checkOutDate = range.end != range.start
            ? range.end
            : range.start.add(const Duration(days: 1));
      });
    }
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: TravelloTheme.paperLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.search, color: TravelloTheme.primaryMain),
                    SizedBox(width: 8),
                    Text('Select Destination',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: _cityProvinceMap.entries.map((e) {
                    final isSel = _selectedCity == e.key;
                    return ListTile(
                      leading: Icon(Icons.location_on,
                          color: isSel
                              ? TravelloTheme.primaryMain
                              : const Color(0xFFD4AF37)),
                      title: Text(e.key,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSel ? TravelloTheme.primaryMain : null)),
                      subtitle: Text(e.value),
                      trailing: isSel
                          ? const Icon(Icons.check_circle,
                              color: TravelloTheme.primaryMain)
                          : null,
                      onTap: () {
                        setState(() => _selectedCity = e.key);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestsRooms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuestsRoomsSheet(
        adults: _adults,
        children: _children,
        rooms: _rooms,
        onChanged: (a, c, r) => setState(() {
          _adults = a;
          _children = c;
          _rooms = r;
        }),
      ),
    );
  }

  void _saveRecentSearch() {
    if (_selectedCity == null) return;
    final label = '$_nights ${_nights == 1 ? 'night' : 'nights'}';
    // Remove duplicate city entry if exists
    _recentSearches.removeWhere((s) => s['city'] == _selectedCity);
    _recentSearches.insert(0, {'city': _selectedCity!, 'info': label});
    // Keep max 5
    if (_recentSearches.length > 5) _recentSearches.removeLast();
  }

  void _search() {
    if (_selectedCity == null) {
      _showValidationError('Please select a destination');
      return;
    }
    if (_checkInDate == null || _checkOutDate == null) {
      _showValidationError('Please select check-in and check-out dates');
      return;
    }
    _saveRecentSearch();
    Get.toNamed('/hotel-results', arguments: {
      'city': _selectedCity,
      'checkInDate': _checkInDate,
      'checkOutDate': _checkOutDate,
      'rooms': _rooms,
      'guests': _adults + _children,
    });
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('Search Hotels',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: TravelloTheme.primaryMain,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Premium Fintech Header ──────────────────────────────────────────
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
                                        Icons.hotel_rounded,
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
                                          const Text(
                                            'Hotel Booking',
                                            style: TextStyle(
                                              fontSize: 28,
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
                                            'Find your perfect stay',
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

          // ── Content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Destination card
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
                  child: InkWell(
                    onTap: _showCityPicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFD4AF37)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Destination',
                                    style: TravelloTheme.caption),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedCity != null
                                      ? '$_selectedCity, ${_cityProvinceMap[_selectedCity]}'
                                      : 'Select destination',
                                  style: TravelloTheme.subtitle,
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

                // Check-in card
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
                  child: InkWell(
                    onTap: _selectCheckIn,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Color(0xFFD4AF37), size: 20),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Check-in Date',
                                  style: TravelloTheme.caption),
                              const SizedBox(height: 4),
                              Text(
                                _checkInDate == null
                                    ? 'Select date'
                                    : '${_checkInDate!.day} ${_monthName(_checkInDate!.month)} ${_checkInDate!.year}',
                                style: TravelloTheme.subtitle,
                              ),
                              if (_checkInDate != null)
                                Text(_dayName(_checkInDate!.weekday),
                                    style: TravelloTheme.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Check-out card
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
                  child: InkWell(
                    onTap: _selectCheckOut,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Color(0xFFD4AF37), size: 20),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Check-out Date',
                                  style: TravelloTheme.caption),
                              const SizedBox(height: 4),
                              Text(
                                _checkOutDate == null
                                    ? 'Select date'
                                    : '${_checkOutDate!.day} ${_monthName(_checkOutDate!.month)} ${_checkOutDate!.year}',
                                style: TravelloTheme.subtitle,
                              ),
                              if (_checkOutDate != null)
                                Text(
                                    '$_nights ${_nights == 1 ? 'night' : 'nights'}',
                                    style: TravelloTheme.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Guests & Rooms — two side-by-side cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Passengers card
                      Expanded(
                        child: InkWell(
                          onTap: _showGuestsRooms,
                          borderRadius: BorderRadius.circular(16),
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
                                Row(
                                  children: [
                                    Icon(Icons.people_outline,
                                        color: colorScheme(context)
                                            .primary
                                            .withValues(alpha: 0.7),
                                        size: 18),
                                    const SizedBox(width: 4),
                                    const Text('Guests',
                                        style: TravelloTheme.caption),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_adults ${_adults == 1 ? 'Guest' : 'Guests'}',
                                  style: TravelloTheme.subtitle,
                                ),
                                Text('A: $_adults, C: $_children, R: $_rooms',
                                    style: TravelloTheme.caption),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Rooms card
                      Expanded(
                        child: InkWell(
                          onTap: _showGuestsRooms,
                          borderRadius: BorderRadius.circular(16),
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
                                Row(
                                  children: [
                                    Icon(Icons.bed_outlined,
                                        color: colorScheme(context)
                                            .primary
                                            .withValues(alpha: 0.7),
                                        size: 18),
                                    const SizedBox(width: 4),
                                    const Text('Rooms',
                                        style: TravelloTheme.caption),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_rooms ${_rooms == 1 ? 'Room' : 'Rooms'}',
                                  style: TravelloTheme.subtitle,
                                ),
                                const Text('Tap to change',
                                    style: TravelloTheme.caption),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Recent Searches ──────────────────────────────────
                if (_recentSearches.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent searches',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () =>
                              setState(() => _recentSearches.clear()),
                          child: const Text('Clear all',
                              style: TextStyle(
                                  color: TravelloTheme.primaryMain,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacingUnit(0.75)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: spacingUnit(0.75),
                      alignment: WrapAlignment.start,
                      children: _recentSearches.map((s) {
                        return InkWell(
                          onTap: () => setState(() {
                            _selectedCity = s['city'] as String;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: TravelloTheme.paperLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history,
                                    size: 15, color: TravelloTheme.primaryMain),
                                const SizedBox(width: 5),
                                Text(
                                  s['info'] != null
                                      ? '${s['city']} · ${s['info']}'
                                      : s['city'] as String,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guests & Rooms Sheet ───────────────────────────────────────────────────────

class _GuestsRoomsSheet extends StatefulWidget {
  final int adults;
  final int children;
  final int rooms;
  final void Function(int adults, int children, int rooms) onChanged;

  const _GuestsRoomsSheet({
    required this.adults,
    required this.children,
    required this.rooms,
    required this.onChanged,
  });

  @override
  State<_GuestsRoomsSheet> createState() => _GuestsRoomsSheetState();
}

class _GuestsRoomsSheetState extends State<_GuestsRoomsSheet> {
  late int _adults;
  late int _children;
  late int _rooms;

  @override
  void initState() {
    super.initState();
    _adults = widget.adults;
    _children = widget.children;
    _rooms = widget.rooms;
  }

  Widget _row(
      String label, String sub, int val, VoidCallback dec, VoidCallback inc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              _Btn(icon: Icons.remove, onTap: dec),
              SizedBox(
                width: 36,
                child: Center(
                  child: Text('$val',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              _Btn(icon: Icons.add, onTap: inc),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Guests & Rooms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _row('Adults', 'Age 18+', _adults, () {
            if (_adults > 1) setState(() => _adults--);
          }, () {
            if (_adults < 10) setState(() => _adults++);
          }),
          const Divider(height: 1),
          _row('Children', 'Age 0-17', _children, () {
            if (_children > 0) setState(() => _children--);
          }, () {
            if (_children < 6) setState(() => _children++);
          }),
          const Divider(height: 1),
          _row('Rooms', '', _rooms, () {
            if (_rooms > 1) setState(() => _rooms--);
          }, () {
            if (_rooms < 5) setState(() => _rooms++);
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onChanged(_adults, _children, _rooms);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TravelloTheme.primaryMain,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: spacingUnit(1.75)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TravelloTheme.primaryMain),
        ),
        child: Icon(icon, size: 16, color: TravelloTheme.primaryMain),
      ),
    );
  }
}
