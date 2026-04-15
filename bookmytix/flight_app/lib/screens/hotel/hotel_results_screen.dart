import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class HotelResultsScreen extends StatefulWidget {
  const HotelResultsScreen({super.key});

  @override
  State<HotelResultsScreen> createState() => _HotelResultsScreenState();
}

class _HotelResultsScreenState extends State<HotelResultsScreen> {
  late String city;
  late DateTime checkInDate;
  late DateTime checkOutDate;
  late int rooms;
  late int guests;

  List<Hotel> hotels = [];
  List<Hotel> filteredHotels = [];

  String searchQuery = '';

  // Filters
  String? selectedCategory;
  double minPrice = 3000;
  double maxPrice = 160000;
  double minRating = 0.0;
  bool? filterPool;
  bool? filterBreakfast;
  bool? filterWifi;
  bool? filterParking;
  bool? filterGym;
  bool? filterSpa;
  bool? filterAirportShuttle;
  bool? filterPetFriendly;
  String propertyType = 'Hotel';
  String sortBy = 'recommended';

  // Active filter count
  int get _activeFilters {
    int c = 0;
    if (selectedCategory != null) c++;
    if (minPrice > 3000 || maxPrice < 160000) c++;
    if (minRating > 0) c++;
    if (filterWifi == true) c++;
    if (filterParking == true) c++;
    if (filterBreakfast == true) c++;
    if (filterPool == true) c++;
    if (filterSpa == true) c++;
    if (filterGym == true) c++;
    if (filterAirportShuttle == true) c++;
    if (filterPetFriendly == true) c++;
    return c;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments ?? {};
    city = args['city'] ?? 'Karachi';
    checkInDate = args['checkInDate'] ?? DateTime.now();
    checkOutDate =
        args['checkOutDate'] ?? DateTime.now().add(const Duration(days: 1));
    rooms = args['rooms'] ?? 1;
    guests = args['guests'] ?? 2;
    _loadHotels();
  }

  void _loadHotels() {
    hotels = PakistanHotels.getHotels(city);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      filteredHotels = PakistanHotels.searchHotels(
        city: city,
        category: selectedCategory,
        maxPrice: maxPrice > 0 ? maxPrice : null,
        minRating: minRating > 0 ? minRating : null,
        hasPool: filterPool,
        hasBreakfast: filterBreakfast,
      );
      if (minPrice > 3000) {
        filteredHotels =
            filteredHotels.where((h) => h.pricePerNight >= minPrice).toList();
      }
      if (filterWifi == true) {
        filteredHotels = filteredHotels.where((h) => h.hasFreeWifi).toList();
      }
      if (filterParking == true) {
        filteredHotels = filteredHotels.where((h) => h.hasParking).toList();
      }
      if (filterGym == true) {
        filteredHotels = filteredHotels
            .where((h) => h.amenities.any((a) =>
                a.toLowerCase().contains('gym') ||
                a.toLowerCase().contains('fitness')))
            .toList();
      }
      if (filterSpa == true) {
        filteredHotels = filteredHotels
            .where(
                (h) => h.amenities.any((a) => a.toLowerCase().contains('spa')))
            .toList();
      }
      if (searchQuery.isNotEmpty) {
        filteredHotels = filteredHotels
            .where((h) =>
                h.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                h.address.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();
      }
      if (sortBy == 'price_low') {
        filteredHotels
            .sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
      } else if (sortBy == 'price_high') {
        filteredHotels
            .sort((a, b) => b.pricePerNight.compareTo(a.pricePerNight));
      } else if (sortBy == 'rating') {
        filteredHotels.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (sortBy == 'free') {
        filteredHotels.sort((a, b) =>
            (b.isRefundable ? 1 : 0).compareTo(a.isRefundable ? 1 : 0));
      }
    });
  }

  int get numberOfNights => checkOutDate.difference(checkInDate).inDays;

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Text('Filter results',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModal(() {
                              selectedCategory = null;
                              minPrice = 3000;
                              maxPrice = 160000;
                              minRating = 0;
                              filterPool = null;
                              filterBreakfast = null;
                              filterWifi = null;
                              filterParking = null;
                              filterGym = null;
                              filterSpa = null;
                              filterAirportShuttle = null;
                              filterPetFriendly = null;
                            });
                          },
                          child: const Text('Reset all',
                              style: TextStyle(
                                  color: TravelloTheme.primaryMain,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Price Range
                        const Text('PRICE PER NIGHT (PKR)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: RangeValues(minPrice, maxPrice),
                          min: 3000,
                          max: 160000,
                          divisions: 53,
                          activeColor: TravelloTheme.primaryMain,
                          labels: RangeLabels(
                              'PKR ${(minPrice / 1000).toStringAsFixed(0)}K',
                              'PKR ${(maxPrice / 1000).toStringAsFixed(0)}K'),
                          onChanged: (v) => setModal(() {
                            minPrice = v.start;
                            maxPrice = v.end;
                          }),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'PKR ${NumberFormat('#,##0').format(minPrice.round())}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                                'PKR ${NumberFormat('#,##0').format(maxPrice.round())}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Star Rating
                        const Text('STAR RATING',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [1, 2, 3, 4, 5].map((stars) {
                            final cat = '$stars-Star';
                            final sel = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setModal(
                                    () => selectedCategory = sel ? null : cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? colorScheme(context)
                                            .primary
                                            .withValues(alpha: 0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: sel
                                            ? TravelloTheme.primaryMain
                                            : Colors.grey.shade300,
                                        width: sel ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star,
                                          size: 14,
                                          color: sel
                                              ? TravelloTheme.primaryMain
                                              : const Color(0xFFD4AF37)),
                                      const SizedBox(width: 3),
                                      Text('$stars',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: sel
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: sel
                                                  ? TravelloTheme.primaryMain
                                                  : Colors.black87)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Guest Review Score
                        const Text('GUEST REVIEW SCORE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            {'label': 'Wonderful 9+', 'val': 4.7},
                            {'label': 'Very Good 8+', 'val': 4.2},
                            {'label': 'Good 7+', 'val': 3.5},
                            {'label': 'All scores', 'val': 0.0},
                          ].map((item) {
                            final sel = minRating == (item['val'] as double);
                            return GestureDetector(
                              onTap: () => setModal(
                                  () => minRating = item['val'] as double),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? TravelloTheme.primaryMain
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sel
                                          ? TravelloTheme.primaryMain
                                          : Colors.grey.shade300),
                                ),
                                child: Text(item['label'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            sel ? Colors.white : Colors.black87,
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Facilities
                        const Text('FACILITIES',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        ...[
                          {
                            'label': 'Free WiFi',
                            'icon': Icons.wifi,
                            'count': 21,
                            'val': filterWifi,
                            'key': 'wifi'
                          },
                          {
                            'label': 'Free parking',
                            'icon': Icons.local_parking,
                            'count': 17,
                            'val': filterParking,
                            'key': 'parking'
                          },
                          {
                            'label': 'Breakfast included',
                            'icon': Icons.free_breakfast,
                            'count': 14,
                            'val': filterBreakfast,
                            'key': 'breakfast'
                          },
                          {
                            'label': 'Swimming pool',
                            'icon': Icons.pool,
                            'count': 9,
                            'val': filterPool,
                            'key': 'pool'
                          },
                          {
                            'label': 'Pet-friendly',
                            'icon': Icons.pets,
                            'count': 5,
                            'val': filterPetFriendly,
                            'key': 'pet'
                          },
                          {
                            'label': 'Airport shuttle',
                            'icon': Icons.airport_shuttle,
                            'count': 8,
                            'val': filterAirportShuttle,
                            'key': 'shuttle'
                          },
                          {
                            'label': 'Spa & wellness',
                            'icon': Icons.spa,
                            'count': 6,
                            'val': filterSpa,
                            'key': 'spa'
                          },
                        ].map((f) {
                          final checked = (f['val'] as bool?) == true;
                          return InkWell(
                            onTap: () => setModal(() {
                              final newVal = !checked;
                              if (f['key'] == 'wifi') {
                                filterWifi = newVal;
                              } else if (f['key'] == 'parking') {
                                filterParking = newVal;
                              } else if (f['key'] == 'breakfast') {
                                filterBreakfast = newVal;
                              } else if (f['key'] == 'pool') {
                                filterPool = newVal;
                              } else if (f['key'] == 'pet') {
                                filterPetFriendly = newVal;
                              } else if (f['key'] == 'shuttle') {
                                filterAirportShuttle = newVal;
                              } else if (f['key'] == 'spa') {
                                filterSpa = newVal;
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? TravelloTheme.primaryMain
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: checked
                                              ? TravelloTheme.primaryMain
                                              : Colors.grey.shade400,
                                          width: 1.5),
                                    ),
                                    child: checked
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 15)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(f['icon'] as IconData,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(f['label'] as String,
                                          style:
                                              const TextStyle(fontSize: 14))),
                                  Text('${f['count']}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Property Type
                        const Text('PROPERTY TYPE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        ...[
                          {'label': 'Hotel', 'count': 18},
                          {'label': 'Guest house', 'count': 12},
                          {'label': 'Serviced apartment', 'count': 7},
                          {'label': 'Resort', 'count': 4},
                        ].map((t) {
                          final sel = propertyType == t['label'];
                          return InkWell(
                            onTap: () => setModal(
                                () => propertyType = t['label'] as String),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? TravelloTheme.primaryMain
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: sel
                                              ? TravelloTheme.primaryMain
                                              : Colors.grey.shade400,
                                          width: 1.5),
                                    ),
                                    child: sel
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 15)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(t['label'] as String,
                                          style:
                                              const TextStyle(fontSize: 14))),
                                  Text('${t['count']}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Bottom Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            top: BorderSide(color: Colors.grey.shade200))),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModal(() {
                                  selectedCategory = null;
                                  minPrice = 3000;
                                  maxPrice = 160000;
                                  minRating = 0;
                                  filterPool = null;
                                  filterBreakfast = null;
                                  filterWifi = null;
                                  filterParking = null;
                                  filterGym = null;
                                  filterSpa = null;
                                  filterAirportShuttle = null;
                                  filterPetFriendly = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: spacingUnit(1.75)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(
                                    color: TravelloTheme.primaryMain),
                              ),
                              child: const Text('Clear',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {});
                                _applyFilters();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TravelloTheme.primaryMain,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    vertical: spacingUnit(1.75)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                  'Show ${filteredHotels.length} results',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: TravelloTheme.primaryMain,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
            '$city · ${DateFormat('d MMM').format(checkInDate)}–${DateFormat('d MMM').format(checkOutDate)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.tune), onPressed: _showFilters),
              if (_activeFilters > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Center(
                        child: Text('$_activeFilters',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Info bar ───────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                    '$guests ${guests == 1 ? 'adult' : 'adults'} · $numberOfNights nights',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                Text('${filteredHotels.length} properties',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // ── Sort Pills ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: spacingUnit(0.75)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SortPill(
                      label: 'Recommended',
                      active: sortBy == 'recommended',
                      onTap: () => setState(() {
                            sortBy = 'recommended';
                            _applyFilters();
                          })),
                  _SortPill(
                      label: 'Price ↑',
                      active: sortBy == 'price_low',
                      onTap: () => setState(() {
                            sortBy = 'price_low';
                            _applyFilters();
                          })),
                  _SortPill(
                      label: 'Stars ★★★',
                      active: sortBy == 'rating',
                      onTap: () => setState(() {
                            sortBy = 'rating';
                            _applyFilters();
                          })),
                  _SortPill(
                      label: 'Free cancel',
                      active: sortBy == 'free',
                      onTap: () => setState(() {
                            sortBy = 'free';
                            _applyFilters();
                          })),
                ],
              ),
            ),
          ),
          // ── Hotel List ─────────────────────────────────────────────────────
          Expanded(
            child: filteredHotels.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hotel_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No hotels found',
                              style: TravelloTheme.subtitle
                                  .copyWith(color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          const Text('Try adjusting your filters',
                              style: TravelloTheme.caption),
                        ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredHotels.length,
                    itemBuilder: (context, index) =>
                        _buildHotelCard(filteredHotels[index], index, fmt),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(Hotel hotel, int index, NumberFormat fmt) {
    final ratingLabel = hotel.rating >= 4.7
        ? 'Exceptional'
        : hotel.rating >= 4.5
            ? 'Wonderful'
            : hotel.rating >= 4.2
                ? 'Excellent'
                : hotel.rating >= 4.0
                    ? 'Very Good'
                    : 'Good';
    final ratingColor = hotel.rating >= 4.5
        ? const Color(0xFF1B4332)
        : hotel.rating >= 4.0
            ? const Color(0xFF1565C0)
            : Colors.grey.shade700;
    final bool isEcoCertified =
        hotel.description.toLowerCase().contains('eco') || index == 2;
    final int roomsLeft = (index % 4) + 1; // 1–4 rooms left
    final bool isLastRoom = roomsLeft == 1;

    return GestureDetector(
      onTap: () => Get.toNamed('/hotel-detail', arguments: {
        'hotel': hotel,
        'checkInDate': checkInDate,
        'checkOutDate': checkOutDate,
        'rooms': rooms,
        'guests': guests,
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    hotel.images.first,
                    height: R.rh(context, 180),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: R.rh(context, 180),
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.hotel,
                            size: 64, color: Colors.grey)),
                  ),
                ),
                // Eco Certified
                if (isEcoCertified)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Eco Certified',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                // Last room / Rooms left
                if (isLastRoom)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Last room!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: EdgeInsets.all(spacingUnit(1.75)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category row
                  Row(
                    children: [
                      ...List.generate(
                          int.tryParse(hotel.category.split('-').first) ?? 0,
                          (_) => const Icon(Icons.star,
                              size: 12, color: Color(0xFFD4AF37))),
                      const SizedBox(width: 4),
                      Text(hotel.category,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Hotel name
                  Text(hotel.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                          '${hotel.distanceFromCenter.toStringAsFixed(1)} km from city centre',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Amenities
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hotel.hasFreeWifi) _amenityChip('Free WiFi'),
                      if (hotel.hasParking) _amenityChip('Free parking'),
                      if (hotel.hasPool) _amenityChip('Pool'),
                      if (hotel.amenities
                          .any((a) => a.toLowerCase().contains('spa')))
                        _amenityChip('Spa'),
                      if (hotel.amenities.any((a) =>
                          a.toLowerCase().contains('gym') ||
                          a.toLowerCase().contains('fitness')))
                        _amenityChip('Gym'),
                    ].take(3).toList(),
                  ),
                  if (hotel.hasBreakfast) ...[
                    const SizedBox(height: 4),
                    const Text('Breakfast incl.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 8),

                  // Rating + Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                            color: ratingColor,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(hotel.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ratingLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${fmt.format(hotel.totalReviews)} reviews',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('PKR ${fmt.format(hotel.pricePerNight.round())}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: TravelloTheme.primaryMain)),
                          Text(
                              'PKR ${fmt.format((hotel.pricePerNight * numberOfNights).round())} total · $numberOfNights nights',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),

                  // Urgency + free cancel row
                  SizedBox(height: spacingUnit(0.75)),
                  Row(
                    children: [
                      if (!isLastRoom && roomsLeft <= 3)
                        Text('Only $roomsLeft left!',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      if (hotel.isRefundable) ...[
                        if (!isLastRoom && roomsLeft <= 3)
                          const SizedBox(width: 10),
                        Text('Free cancel',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300)),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortPill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? TravelloTheme.primaryMain : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  active ? TravelloTheme.primaryMain : Colors.grey.shade400),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.white : Colors.black87)),
      ),
    );
  }
}
