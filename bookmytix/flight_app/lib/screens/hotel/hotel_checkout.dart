import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/models/room_type.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// Hotel Checkout — Step 4 in hotel booking flow.
/// Review page shown between Guest Details and Payment.
/// Shows hotel summary, stay details, guest info, price breakdown, and
/// Pakistan-standard Rules & Policy section before proceeding to payment.
class HotelCheckout extends StatefulWidget {
  const HotelCheckout({super.key});

  @override
  State<HotelCheckout> createState() => _HotelCheckoutState();
}

class _HotelCheckoutState extends State<HotelCheckout> {
  late Map<String, dynamic> _args;

  // Data
  late Hotel _hotel;
  RoomType? _roomType;
  late DateTime _checkIn;
  late DateTime _checkOut;
  late int _nights;
  late int _rooms;
  late int _guests;
  late double _basePrice;
  late double _extrasTotal;
  late double _totalPrice;
  bool _breakfastAdded = false;
  bool _airportTransferAdded = false;
  bool _lateCheckoutAdded = false;
  List<Map<String, dynamic>> _guestsData = [];
  List<String> _extrasIncluded = [];

  // Policy
  bool _agreeToTerms = false;
  bool _showTermsError = false;

  final fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _args = (Get.arguments as Map<String, dynamic>?) ?? {};
    _hotel = _args['hotel'] as Hotel;
    _roomType = _args['roomType'] as RoomType?;
    _checkIn = (_args['checkInDate'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 1));
    _checkOut = (_args['checkOutDate'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 2));
    _nights = (_args['nights'] as int?) ?? 1;
    _rooms = (_args['rooms'] as int?) ?? 1;
    _guests = (_args['guests'] as int?) ?? 1;
    _basePrice = (_args['basePrice'] as num?)?.toDouble() ?? 0.0;
    _extrasTotal = (_args['extrasTotal'] as num?)?.toDouble() ?? 0.0;
    _totalPrice = (_args['totalPrice'] as num?)?.toDouble() ?? 0.0;
    _breakfastAdded = (_args['breakfastAdded'] as bool?) ?? false;
    _airportTransferAdded = (_args['airportTransferAdded'] as bool?) ?? false;
    _lateCheckoutAdded = (_args['lateCheckoutAdded'] as bool?) ?? false;
    final raw = _args['guestsData'] as List?;
    if (raw != null) {
      _guestsData =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    _extrasIncluded = (_args['extrasIncluded'] as List?)?.cast<String>() ?? [];
  }

  // ── Taxes ─────────────────────────────────────────────────────────────────
  double get _serviceCharge => _basePrice * 0.05;
  double get _tourismTax => _basePrice * 0.03;
  double get _gst => _basePrice * 0.16;
  double get _totalWithTax =>
      _basePrice + _serviceCharge + _tourismTax + _gst + _extrasTotal;

  String _fmtDate(DateTime d) => DateFormat('EEE, MMM d, yyyy').format(d);

  void _proceedToPayment() {
    if (!_agreeToTerms) {
      setState(() => _showTermsError = true);
      Get.snackbar(
        'Terms Required',
        'Please accept Terms & Conditions and Privacy Policy to continue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
      );
      return;
    }
    Get.toNamed('/payment-professional', arguments: {
      ..._args,
      'totalPrice': _totalWithTax,
    });
  }

  @override
  Widget build(BuildContext context) {
    const primary = TravelloTheme.primaryMain;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Review & Checkout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => Get.toNamed('/faq'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress Bar ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                _HStep(num: 1, label: 'Hotel', done: true),
                _HStepLine(done: true),
                _HStep(num: 2, label: 'Rooms', done: true),
                _HStepLine(done: true),
                _HStep(num: 3, label: 'Guests', done: true),
                _HStepLine(done: true),
                _HStep(num: 4, label: 'Checkout', done: false, active: true),
                _HStepLine(done: false),
                _HStep(num: 5, label: 'Payment', done: false),
                _HStepLine(done: false),
                _HStep(num: 6, label: 'Done', done: false),
              ],
            ),
          ),

          // ── Scrollable Body ─────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Hotel Details
                _buildSectionHeader(Icons.hotel, 'Hotel Details', primary),
                const SizedBox(height: 8),
                _buildHotelDetails(primary),
                const SizedBox(height: 16),

                // 2. Stay Details
                _buildSectionHeader(
                    Icons.calendar_month, 'Stay Details', primary),
                const SizedBox(height: 8),
                _buildStayDetails(primary),
                const SizedBox(height: 16),

                // 3. Price Breakdown
                _buildSectionHeader(
                    Icons.receipt_long_outlined, 'Price Breakdown', primary),
                const SizedBox(height: 8),
                _buildPriceBreakdown(primary),
                const SizedBox(height: 16),

                // 4. Guest Details
                if (_guestsData.isNotEmpty) ...[
                  _buildSectionHeader(
                      Icons.people_outline, 'Guest Details', primary),
                  const SizedBox(height: 8),
                  _buildGuestDetails(primary),
                  const SizedBox(height: 16),
                ],

                // 5. Rules & Policy
                _buildRulesAndPolicy(primary),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Bottom Button ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12,
                16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: DSButton(
                  label:
                      'Confirm Payment • PKR ${fmt.format(_totalWithTax.round())}',
                  onTap: _proceedToPayment,
                  disabled: !_agreeToTerms,
                  height: 56,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(IconData icon, String title, Color primary) {
    return Row(children: [
      Icon(icon, color: primary, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }

  // ── 1. Hotel Details ──────────────────────────────────────────────────────
  Widget _buildHotelDetails(Color primary) {
    final hasImage = _hotel.images.isNotEmpty && _hotel.images[0].isNotEmpty;
    return Container(
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Hero image ──────────────────────────────────────────────────
        Stack(children: [
          if (hasImage)
            Image.network(
              _hotel.images[0],
              width: double.infinity,
              height: 170,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildImageFallback(primary),
            )
          else
            _buildImageFallback(primary),
          // Gradient overlay
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.65)
              ],
                          stops: const [
                0.45,
                1.0
              ])))),
          // Hotel name + meta over image
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                  padding: EdgeInsets.all(spacingUnit(1.75)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_hotel.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(_hotel.category,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(_hotel.city,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text('${_hotel.rating}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ]))),
        ]),

        // ── Room type section ────────────────────────────────────────────
        if (_roomType != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 12, 16, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Divider(color: Colors.grey.shade200),
              SizedBox(height: spacingUnit(0.75)),
              Row(children: [
                Icon(Icons.bed, color: primary, size: 16),
                const SizedBox(width: 6),
                Text('Room Type',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withValues(alpha: 0.15))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_roomType!.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(_roomType!.description,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 16, runSpacing: 4, children: [
                        _chip(Icons.people_outline,
                            '${_roomType!.maxOccupancy} guests'),
                        _chip(Icons.aspect_ratio,
                            '${_roomType!.sizeInSqFt} sq ft'),
                        _chip(Icons.bed, _roomType!.bedType),
                      ]),
                    ]),
              ),
            ]), // close Padding > Column
          ), // close Padding
        ],

        // Refundable badge
        if (_hotel.isRefundable) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200)),
                child: Row(children: [
                  Icon(Icons.check_circle,
                      size: 15, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Refundable',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700)),
                          Text(
                              'Free cancellation up to 24 hours before check-in',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green.shade600)),
                        ]),
                  ),
                ]),
              ),
            ]),
          ),
        ],

        // Amenities
        if (_hotel.amenities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12,
                16, 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children:
                  _hotel.amenities.take(4).map((a) => _amenityItem(a)).toList(),
            ),
          ),
        ] else
          const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildImageFallback(Color primary) {
    return Container(
      width: double.infinity,
      height: 170,
      color: primary.withValues(alpha: 0.15),
      child: Center(
        child:
            Icon(Icons.hotel, size: 48, color: primary.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      );

  Widget _amenityItem(String name) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_amenityIcon(name), size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(name,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      );

  IconData _amenityIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('wifi')) return Icons.wifi;
    if (n.contains('pool')) return Icons.pool;
    if (n.contains('gym') || n.contains('fitness')) return Icons.fitness_center;
    if (n.contains('spa')) return Icons.spa;
    if (n.contains('park')) return Icons.local_parking;
    if (n.contains('breakfast') || n.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (n.contains('bar')) return Icons.local_bar;
    return Icons.check_circle_outline;
  }

  Widget _placeholder() => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.hotel, size: 32, color: Colors.grey),
      );

  // ── 2. Stay Details ───────────────────────────────────────────────────────
  Widget _buildStayDetails(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(children: [
        // Check-in / Check-out
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.login, size: 14, color: primary),
                const SizedBox(width: 4),
                Text('CHECK-IN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: primary,
                        letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 4),
              Text(_fmtDate(_checkIn),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text('2:00 PM',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
          Column(children: [
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$_nights Night${_nights > 1 ? "s" : ""}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primary)),
            ),
          ]),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('CHECK-OUT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: primary,
                        letterSpacing: 0.5)),
                const SizedBox(width: 4),
                Icon(Icons.logout, size: 14, color: primary),
              ]),
              const SizedBox(height: 4),
              Text(_fmtDate(_checkOut),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text('12:00 PM',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Nights · Rooms · Guests strip
        Container(
          padding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statItem(Icons.nights_stay, '$_nights Nights', primary),
            _vDiv(primary),
            _statItem(Icons.meeting_room, '$_rooms Rooms', primary),
            _vDiv(primary),
            _statItem(Icons.people, '$_guests Guests', primary),
          ]),
        ),
      ]),
    );
  }

  Widget _statItem(IconData icon, String label, Color primary) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _vDiv(Color primary) =>
      Container(width: 1, height: 30, color: primary.withValues(alpha: 0.3));

  // ── 3. Guest Details ──────────────────────────────────────────────────────
  Widget _buildGuestDetails(Color primary) {
    return Container(
      decoration: _card(),
      child: Column(
        children: [
          // Primary guest always shows
          ..._guestsData.asMap().entries.map((entry) {
            final i = entry.key;
            final g = entry.value;
            final isPrimary = i == 0;
            final name = g['firstName'] != null
                ? '${g['firstName']} ${g['lastName'] ?? ''}'.trim()
                : (g['fullName'] ?? 'Guest ${i + 1}');
            return Column(children: [
              if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.person, color: primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          if (g['cnic'] != null &&
                              g['cnic'].toString().isNotEmpty)
                            Text('CNIC: ${g['cnic']}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                        ]),
                  ),
                  if (isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Primary',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primary)),
                    ),
                ]),
              ),
            ]);
          }),

          // Extras included
          if (_extrasIncluded.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Extras',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    ..._extrasIncluded.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF10B981), size: 15),
                            const SizedBox(width: 6),
                            Text(e, style: const TextStyle(fontSize: 13)),
                          ]),
                        )),
                  ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── 4. Price Breakdown ────────────────────────────────────────────────────
  Widget _buildPriceBreakdown(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.hotel, color: primary, size: 18),
          const SizedBox(width: 8),
          const Text('Fare Breakdown',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        _priceRow(
            'Room Rate',
            'PKR ${fmt.format((_roomType?.pricePerNight ?? _hotel.pricePerNight).round())}/night × $_nights nights × $_rooms rooms',
            'PKR ${fmt.format(_basePrice.round())}'),
        _divider(),
        _priceRow('Service Charge (5%)', '',
            'PKR ${fmt.format(_serviceCharge.round())}'),
        _divider(),
        _priceRow(
            'Tourism Tax (3%)', '', 'PKR ${fmt.format(_tourismTax.round())}'),
        _divider(),
        _priceRow('GST (16%)', '', 'PKR ${fmt.format(_gst.round())}'),
        if (_breakfastAdded) ...[
          _divider(),
          _priceRow(
            'Breakfast',
            'PKR 1,400/night × $_nights nights × $_rooms rooms',
            'PKR ${fmt.format((1400 * _nights * _rooms).round())}',
          ),
        ],
        if (_airportTransferAdded) ...[
          _divider(),
          _priceRow(
            'Airport Transfer',
            'PKR 2,500 × $_rooms rooms',
            'PKR ${fmt.format((2500 * _rooms).round())}',
          ),
        ],
        if (_lateCheckoutAdded) ...[
          _divider(),
          _priceRow(
            'Late Check-Out',
            'Until 3:00 PM × $_rooms rooms',
            'PKR ${fmt.format((800 * _rooms).round())}',
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Amount',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('PKR ${fmt.format(_totalWithTax.round())}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
          ]),
        ),
      ]),
    );
  }

  Widget _priceRow(String label, String sub, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.8),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
              if (sub.isNotEmpty)
                Text(sub,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade300);

  // ── 5. Rules and Policy ───────────────────────────────────────────────────
  Widget _buildRulesAndPolicy(Color primary) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rules and Policy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _showTermsError ? Colors.red.shade200 : Colors.grey.shade200,
            width: _showTermsError ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _showTermsError
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.policy_rounded,
                      color: TravelloTheme.primaryMain, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Review Policies',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3)),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade100),

            // Policy rows
            _policyRow('Refund Policy', Icons.account_balance_wallet_rounded,
                _showRefundPolicy),
            Divider(height: 1, color: Colors.grey.shade100, indent: 68),
            _policyRow('Cancellation Policy', Icons.event_busy_rounded,
                _showCancellationPolicy),
            Divider(height: 1, color: Colors.grey.shade100, indent: 68),
            _policyRow('Hotel Booking Rules', Icons.receipt_long_rounded,
                _showHotelRules),

            Divider(height: 1, color: Colors.grey.shade200),

            // T&C checkbox
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16,
                  20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        _agreeToTerms = !_agreeToTerms;
                        _showTermsError = false;
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _agreeToTerms
                                      ? TravelloTheme.primaryMain
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _showTermsError
                                        ? Colors.red.shade400
                                        : _agreeToTerms
                                            ? TravelloTheme.primaryMain
                                            : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: _agreeToTerms
                                    ? const Icon(Icons.check_rounded,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                          height: 1.5),
                                      children: [
                                        const TextSpan(text: 'I accept the '),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: _showTermsPage,
                                            child: Text('Terms & Conditions',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: ThemePalette
                                                        .primaryMain,
                                                    decoration: TextDecoration
                                                        .underline)),
                                          ),
                                        ),
                                        const TextSpan(text: ' and '),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: _showPrivacyPolicy,
                                            child: Text('Privacy Policy',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: ThemePalette
                                                        .primaryMain,
                                                    decoration: TextDecoration
                                                        .underline)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                      ),
                    ),
                    if (_showTermsError) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.error_outline_rounded,
                            size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 5.6),
                        Text('Please accept Terms & Conditions to continue',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ]),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _policyRow(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: const Color(0xFFB3B3B3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      letterSpacing: -0.2)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 24),
          ]),
        ),
      ),
    );
  }

  // ── Policy Modals ─────────────────────────────────────────────────────────

  void _showRefundPolicy() => _showPolicySheet('Refund Policy', [
        const _PolicyItem('Refund Eligibility',
            'For hotel bookings, refunds are subject to the property\'s cancellation policy. Requests must be made before the free cancellation deadline.'),
        const _PolicyItem('Pakistan SECP Standards',
            'In accordance with SECP consumer protection guidelines, refunds for eligible cancellations will be processed within 7-10 business days.'),
        const _PolicyItem('Non-Refundable Bookings',
            'Promotional or discounted hotel rates marked as "Non-Refundable" are not eligible for refunds under any circumstances.'),
        const _PolicyItem('No-Show Policy',
            'Guests who do not check in without prior cancellation will be charged the full booking amount as per the property\'s no-show policy.'),
      ]);

  void _showCancellationPolicy() => _showPolicySheet('Cancellation Policy', [
        const _PolicyItem('Free Cancellation',
            'Bookings may be cancelled free of charge up to 24 hours before the check-in date. Cancellation after this period will incur charges.'),
        const _PolicyItem('Cancellation Charges',
            'Cancellation within 24 hours of check-in: 1 night room rate.\nCancellation after check-in: No refund.\nEarly departure: Charged for booked nights.'),
        const _PolicyItem('How to Cancel',
            'Log in to your Travello account, navigate to "My Bookings", select your hotel booking, and tap "Cancel Booking". Confirmation is sent via SMS and email.'),
        const _PolicyItem('Special Occasions',
            'Bookings during Eid, public holidays, or special events may have stricter cancellation terms as set by the property.'),
      ]);

  void _showHotelRules() => _showPolicySheet('Hotel Booking Rules', [
        const _PolicyItem('Check-in Requirements',
            'Valid original CNIC or Passport must be presented at check-in. Per Pakistan Hotel Association rules, married couples must present original Nikah Nama.'),
        const _PolicyItem('Age Restrictions',
            'Guests must be 18 years or older to make a booking. Minors must be accompanied by a parent or legal guardian.'),
        const _PolicyItem('Check-in / Check-out Times',
            'Standard check-in is at 2:00 PM. Standard check-out is at 12:00 PM (noon). Late check-out is subject to hotel availability and may incur additional charges.'),
        const _PolicyItem('Conduct & Damage',
            'Guests are responsible for any damage caused to hotel property. The hotel reserves the right to charge for damages. Disruptive behavior may result in eviction without refund.'),
      ]);

  void _showPrivacyPolicy() => _showPolicySheet('Privacy Policy', [
        const _PolicyItem('Data Collection',
            'We collect personal information necessary for hotel booking including name, CNIC number, contact details, and payment information for verification purposes.'),
        const _PolicyItem('Pakistan PECA Compliance',
            'We comply with Pakistan\'s Prevention of Electronic Crimes Act (PECA) 2016 and do not share your personal data with third parties without your consent, except for booking fulfillment.'),
        const _PolicyItem('Data Security',
            'All personal data is encrypted and stored securely. We implement industry-standard SSL/TLS encryption for all transactions.'),
        const _PolicyItem('Data Retention',
            'Booking records are retained for 5 years as required by Pakistani tax and commercial laws. You may request deletion of non-mandatory data at any time.'),
      ]);

  void _showPolicySheet(String title, List<_PolicyItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8,
                  8, 16),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5)),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFFB3B3B3)),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items
                        .map((item) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 20),
                              child: _policySection(item.title, item.body),
                            ))
                        .toList()),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _policySection(String title, String content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.6,
                  letterSpacing: -0.1)),
        ],
      );

  void _showTermsPage() => _showPolicySheet('Terms & Conditions', [
        const _PolicyItem('1. Acceptance of Terms',
            'By completing this hotel booking through Travello AI, you agree to be bound by these Terms and Conditions. These terms are governed by the laws of the Islamic Republic of Pakistan.'),
        const _PolicyItem('2. Booking & Payment',
            'All hotel bookings are subject to availability and confirmation by the property. Payment must be completed in full at the time of booking. We accept credit/debit cards and approved mobile wallets.'),
        const _PolicyItem('3. Cancellation & Refunds',
            'Cancellation terms vary by property and rate type. Refundable bookings may be cancelled up to 24 hours before check-in. Non-refundable bookings cannot be cancelled or modified.'),
        const _PolicyItem('4. Guest Responsibilities',
            'Guests must provide valid CNIC/Passport at check-in. Per Pakistani law, unmarried guests sharing a room may be required to show legal documentation. Guests must comply with all hotel rules and property regulations.'),
        const _PolicyItem('5. Liability',
            'Travello AI acts as an intermediary between guests and hotel properties. We are not liable for hotel service quality issues, property changes, or force majeure events.'),
        const _PolicyItem('6. Privacy & PECA Compliance',
            'We handle your personal data in accordance with Pakistani privacy laws including PECA 2016. Your data is used solely for booking fulfillment and service improvement.'),
        const _PolicyItem('7. Dispute Resolution',
            'Any disputes arising from hotel bookings will be resolved through the Consumer Protection Courts of Pakistan or as mutually agreed upon.'),
      ]);

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      );
}

// ── Policy data holder ────────────────────────────────────────────────────────
class _PolicyItem {
  final String title;
  final String body;
  const _PolicyItem(this.title, this.body);
}

// ── Progress Step Widgets (same design as hotel_guest_form_screen) ────────────
class _HStep extends StatelessWidget {
  final int num;
  final String label;
  final bool done;
  final bool active;
  const _HStep(
      {required this.num,
      required this.label,
      required this.done,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    const gold = TravelloTheme.primaryMain;
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: done || active ? gold : const Color(0xFFE0E0E0),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text('$num',
                  style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
        ),
      ),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              fontSize: 9,
              color: done || active ? gold : Colors.grey.shade500,
              fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }
}

class _HStepLine extends StatelessWidget {
  final bool done;
  const _HStepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 18),
          color: done ? TravelloTheme.primaryMain : const Color(0xFFE0E0E0)),
    );
  }
}
