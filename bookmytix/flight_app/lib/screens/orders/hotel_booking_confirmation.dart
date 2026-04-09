import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' show pi;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/column_row_utils.dart';
import 'package:flight_app/ui/themes/theme_button.dart';
import 'package:flight_app/services/notification_service.dart';
import 'package:flight_app/utils/booking_service.dart';

class HotelBookingConfirmation extends StatefulWidget {
  const HotelBookingConfirmation({super.key});

  @override
  State<HotelBookingConfirmation> createState() =>
      _HotelBookingConfirmationState();
}

class _HotelBookingConfirmationState extends State<HotelBookingConfirmation>
    with TickerProviderStateMixin {
  Map<String, dynamic> bookingData = {};
  String bookingReference = '';
  bool _copyingRef = false;
  bool _generatingPdf = false;

  late AnimationController _animController;
  late AnimationController _checkController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _checkScale;
  late Animation<double> _checkRotation;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _confetti.play();
    });
  }

  void _initAnimations() {
    _animController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));

    _checkController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _checkScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
    ]).animate(_checkController);
    _checkRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _checkController,
            curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)));

    _animController.forward();
    Future.delayed(
        const Duration(milliseconds: 400), () => _checkController.forward());
  }

  void _loadData() {
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    // Normalize "saved booking" format (from My Bookings) into the flat format
    // that this screen expects. When saved via _saveBooking, hotel data is
    // stored under 'hotelDetails'. When coming directly from payment flow the
    // hotel object and raw fields are already present.
    Map<String, dynamic> data = Map<String, dynamic>.from(args);
    if (data.containsKey('hotelDetails') && data['hotel'] == null) {
      final h = data['hotelDetails'] as Map<String, dynamic>? ?? {};
      data['_hotelName'] = h['hotelName'] ?? 'Hotel';
      data['_city'] = h['city'] ?? '';
      data['_roomType'] = h['roomType'] ?? 'Room';
      data['_rating'] = (h['rating'] as num?)?.toDouble() ?? 0.0;
      data['_checkInStr'] = h['checkIn'] ?? 'N/A';
      data['_checkOutStr'] = h['checkOut'] ?? 'N/A';
      data['nights'] ??= h['nights'] ?? 1;
      data['totalPrice'] ??= data['total'] ?? 0.0;
      data['guests'] ??= data['passengerCount'] ?? 1;
      data['_isFromList'] = true;
    }
    setState(() {
      bookingData = data;
      bookingReference = data['bookingReference'] ??
          data['pnr'] ??
          'HTL${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    });
    // Only save/notify when coming from the payment flow (not from bookings list)
    if (data['_isFromList'] != true) {
      _saveBooking(data);
      _sendNotification(data);
    }
  }

  void _saveBooking(Map<String, dynamic> args) {
    try {
      final hotel = args['hotel'];
      final roomType = args['roomType'];

      // Calculate price breakdown
      final basePrice = (args['basePrice'] as num?)?.toDouble() ?? 0.0;
      final extrasTotal = (args['extrasTotal'] as num?)?.toDouble() ?? 0.0;
      final serviceCharge = basePrice * 0.05;
      final tourismTax = basePrice * 0.03;
      final gst = basePrice * 0.16;
      final totalTax = serviceCharge + tourismTax + gst;

      BookingService.saveBooking({
        'bookingType': 'hotel',
        'pnr': bookingReference,
        'bookingReference': bookingReference,
        'status': 'confirmed',
        'passengerCount': args['guests'] ?? 1,
        'amount': basePrice, // Base accommodation fare
        'tax': totalTax, // Total taxes (service + tourism + GST)
        'serviceFee': extrasTotal, // Extras as service fee
        'total': args['totalPrice'] ?? 0.0,
        'allPassengers': args['guestsData'] ?? [],
        'hotelDetails': {
          'hotelName': hotel?.name ?? 'Hotel',
          'city': hotel?.city ?? '',
          'address': hotel?.address ?? '',
          'roomType': roomType?.name ?? 'Room',
          'checkIn': args['checkInDate'] is DateTime
              ? DateFormat('d MMM yyyy').format(args['checkInDate'] as DateTime)
              : 'N/A',
          'checkOut': args['checkOutDate'] is DateTime
              ? DateFormat('d MMM yyyy')
                  .format(args['checkOutDate'] as DateTime)
              : 'N/A',
          'nights': args['nights'] ?? 1,
          'rating': hotel?.rating ?? 0,
        },
      });
    } catch (_) {}
  }

  void _sendNotification(Map<String, dynamic> args) {
    try {
      final hotel = args['hotel'];
      final roomType = args['roomType'];
      NotificationService.instance.hotelBooked(
        hotelName: hotel?.name ?? 'Hotel',
        city: hotel?.city ?? '',
        roomType: roomType?.name ?? 'Room',
        checkIn: args['checkInDate'] is DateTime
            ? DateFormat('d MMM yyyy').format(args['checkInDate'] as DateTime)
            : 'N/A',
        checkOut: args['checkOutDate'] is DateTime
            ? DateFormat('d MMM yyyy').format(args['checkOutDate'] as DateTime)
            : 'N/A',
        bookingRef: bookingReference,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _checkController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  String _fmt(double? amount) {
    if (amount == null || amount == 0) return 'PKR 0';
    return 'PKR ${NumberFormat('#,##,###', 'en_PK').format(amount.round())}';
  }

  String _fmtDate(DateTime? d) =>
      d != null ? DateFormat('EEE, MMM d, yyyy').format(d) : 'N/A';

  @override
  Widget build(BuildContext context) {
    final primary = colorScheme(context).primary;
    final isFromList = bookingData['_isFromList'] == true;

    final checkIn = bookingData['checkInDate'] as DateTime?;
    final checkOut = bookingData['checkOutDate'] as DateTime?;
    final basePrice = (bookingData['basePrice'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = (bookingData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final serviceCharge = basePrice * 0.05;
    final tourismTax = basePrice * 0.03;
    final gstVal = basePrice * 0.16;
    final extrasTotal = (bookingData['extrasTotal'] as num?)?.toDouble() ?? 0.0;
    final extrasIncluded =
        (bookingData['extrasIncluded'] as List?)?.cast<String>() ?? [];
    final transactionId = bookingData['transactionId'] as String? ??
        'TXN${DateTime.now().millisecondsSinceEpoch}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(isFromList ? 'Booking Details' : 'Done',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => Get.toNamed('/faq'),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Share Booking',
            onPressed: _shareHotelBooking,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildProgressBar(context, primary),
                Padding(
                  padding: EdgeInsets.all(spacingUnit(2)),
                  child: Column(
                    children: [
                      _buildSuccessHeader(context, totalPrice),
                      SizedBox(height: spacingUnit(2)),
                      _buildBookingReference(context, primary),
                      SizedBox(height: spacingUnit(2)),
                      _buildDetailTransaction(
                          context,
                          basePrice,
                          serviceCharge,
                          tourismTax,
                          gstVal,
                          extrasTotal,
                          totalPrice,
                          transactionId),
                      SizedBox(height: spacingUnit(2)),
                      _buildPaymentSummary(context, primary, totalPrice,
                          transactionId, extrasIncluded),
                      SizedBox(height: spacingUnit(2)),
                      _buildPreStayChecklist(context, primary),
                      SizedBox(height: spacingUnit(2)),
                      _buildActionButtons(context, primary),
                      SizedBox(height: spacingUnit(3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.06,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              shouldLoop: false,
              maximumSize: const Size(10, 10),
              minimumSize: const Size(5, 5),
              colors: const [
                Color(0xFF10B981),
                Color(0xFF3B82F6),
                Color(0xFFEC4899),
                Color(0xFFF59E0B),
                Color(0xFF8B5CF6),
                Color(0xFFFBBF24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Color primary) {
    const goldColor = Color(0xFFD4AF37);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: spacingUnit(1.5), vertical: spacingUnit(1.5)),
      child: const Row(
        children: [
          _ProgStep(num: 1, label: 'Hotel', done: true, primary: goldColor),
          _ProgLine(done: true, primary: goldColor),
          _ProgStep(num: 2, label: 'Rooms', done: true, primary: goldColor),
          _ProgLine(done: true, primary: goldColor),
          _ProgStep(num: 3, label: 'Guests', done: true, primary: goldColor),
          _ProgLine(done: true, primary: goldColor),
          _ProgStep(num: 4, label: 'Checkout', done: true, primary: goldColor),
          _ProgLine(done: true, primary: goldColor),
          _ProgStep(num: 5, label: 'Payment', done: true, primary: goldColor),
          _ProgLine(done: true, primary: goldColor),
          _ProgStep(num: 6, label: 'Done', done: true, primary: goldColor),
        ],
      ),
    );
  }

  Widget _buildSuccessHeader(BuildContext context, double total) {
    const green = Color(0xFF10B981);
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          padding: EdgeInsets.all(spacingUnit(3)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF0DA872)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: green.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _checkController,
                builder: (context, child) => Transform.scale(
                  scale: _checkScale.value,
                  child: Transform.rotate(
                    angle: _checkRotation.value * 2 * pi,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 20 * _checkScale.value,
                              spreadRadius: 5 * _checkScale.value),
                        ],
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacingUnit(2)),
              const Text('Payment Success',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              SizedBox(height: spacingUnit(1)),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: spacingUnit(3), vertical: spacingUnit(1.5)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Text(_fmt(total),
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: spacingUnit(1)),
              Text('Your hotel reservation is confirmed!',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingReference(BuildContext context, Color primary) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.confirmation_number_outlined, color: primary, size: 20),
            SizedBox(width: spacingUnit(1)),
            const Text('Booking Reference',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          Container(
            padding: EdgeInsets.all(spacingUnit(1.5)),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PNR / Booking Code',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(bookingReference,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.black87)),
                ]),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: bookingReference));
                    setState(() => _copyingRef = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) setState(() => _copyingRef = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _copyingRef ? const Color(0xFF10B981) : primary,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(_copyingRef ? Icons.check : Icons.copy,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDetailTransaction(
      BuildContext context,
      double base,
      double service,
      double tourism,
      double gstVal,
      double extras,
      double total,
      String txnId) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETAIL TRANSACTION',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black87)),
          SizedBox(height: spacingUnit(2)),
          _row('Date:', DateFormat('dd MMM yyyy').format(DateTime.now())),
          _div(),
          _row('Transaction Number:', txnId),
          _div(),
          _row('Base Fare:', _fmt(base)),
          _div(),
          _row('Service Charge (5%):', _fmt(service)),
          _div(),
          _row('Tourism Tax (3%):', _fmt(tourism)),
          _div(),
          _row('GST (16%):', _fmt(gstVal)),
          if (extras > 0) ...[
            _div(),
            _row('Extras:', _fmt(extras)),
          ],
          _div(),
          _row('Total Amount:', _fmt(total), bold: true),
        ]),
      ),
    );
  }

  // ── Hotel Details Card (image 1 style) ─────────────────────────────────
  Widget _buildHotelDetailsCard(
      BuildContext context, Color primary, dynamic hotel) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bed, color: primary, size: 20),
            SizedBox(width: spacingUnit(1)),
            const Text('Hotel Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hotel?.images != null && (hotel.images as List).isNotEmpty
                  ? Image.network(
                      hotel.images[0],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _hotelPlaceholder(),
                    )
                  : _hotelPlaceholder(),
            ),
            SizedBox(width: spacingUnit(1.5)),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hotel?.name ?? 'Hotel',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(hotel?.category ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primary)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      Text(' ${hotel?.rating ?? ''}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(hotel?.address ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ]),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Room Type Card (image 1 style) ───────────────────────────────────────
  Widget _buildRoomTypeCard(
      BuildContext context, Color primary, dynamic roomType) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bed, color: primary, size: 20),
            SizedBox(width: spacingUnit(1)),
            const Text('Room Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(spacingUnit(1.5)),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(roomType.name ?? 'Room',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(roomType.description ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              SizedBox(height: spacingUnit(1)),
              Row(children: [
                Icon(Icons.people_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${roomType.maxOccupancy ?? 2} guests',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 16),
                Icon(Icons.aspect_ratio, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${roomType.sizeInSqFt ?? ''} sq ft',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.bed, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(roomType.bedType ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Stay Details Card (image 1 style) ────────────────────────────────────
  Widget _buildStayDetailsCard(
      BuildContext context,
      Color primary,
      DateTime? checkIn,
      DateTime? checkOut,
      int nights,
      int rooms,
      int guests) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.calendar_month, color: primary, size: 20),
            SizedBox(width: spacingUnit(1)),
            const Text('Stay Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: spacingUnit(2)),
          // Check-in / Check-out row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(_fmtDate(checkIn),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('2:00 PM',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
            ),
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
                Text(_fmtDate(checkOut),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text('12:00 PM',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          // Nights / Rooms / Guests strip
          Container(
            padding: EdgeInsets.symmetric(
                vertical: spacingUnit(1.5), horizontal: spacingUnit(1)),
            decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.nights_stay, '$nights Nights', primary),
                  _vDivider(primary),
                  _statItem(Icons.meeting_room, '$rooms Rooms', primary),
                  _vDivider(primary),
                  _statItem(Icons.people, '$guests Guests', primary),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _hotelPlaceholder() => Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: const Icon(Icons.hotel, size: 36, color: Colors.grey),
      );

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

  Widget _vDivider(Color primary) =>
      Container(width: 1, height: 30, color: primary.withValues(alpha: 0.3));

  Widget _roomStat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      );

  Widget _buildGuestInfo(BuildContext context, Color primary, List guestsData) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.people_outline, color: primary, size: 20),
            SizedBox(width: spacingUnit(1)),
            const Text('Guest Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          ...guestsData.asMap().entries.map((e) {
            final g = e.value as Map;
            final name = g['firstName'] != null
                ? '${g['firstName']} ${g['lastName'] ?? ''}'.trim()
                : (g['fullName'] ?? 'Guest ${e.key + 1}');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(spacingUnit(1.5)),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.person, color: primary, size: 18),
                ),
                SizedBox(width: spacingUnit(1.5)),
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
                        if (g['phone'] != null &&
                            g['phone'].toString().isNotEmpty)
                          Text('Phone: ${g['phone']}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildPaymentSummary(BuildContext context, Color primary, double total,
      String txnId, List<String> extras) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.receipt_long_outlined, color: primary, size: 20),
              SizedBox(width: spacingUnit(1)),
              const Text('Payment Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            GestureDetector(
              onTap: _showInvoiceModal,
              child: Text('View Invoice',
                  style: TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          SizedBox(height: spacingUnit(1.5)),
          _row('Payment Method', 'Card'),
          _div(),
          _row('Transaction ID', txnId),
          _div(),
          _row('Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
          SizedBox(height: spacingUnit(1.5)),
          Container(
            padding: EdgeInsets.all(spacingUnit(1.5)),
            decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Payment verified and processed securely',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          if (extras.isNotEmpty) ...[
            SizedBox(height: spacingUnit(1.5)),
            Divider(color: Colors.grey.shade200),
            SizedBox(height: spacingUnit(1)),
            Text('Extras Included',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            ...extras.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Text(e, style: const TextStyle(fontSize: 13)),
                  ]),
                )),
          ],
        ]),
      ),
    );
  }

  Widget _buildPreStayChecklist(BuildContext context, Color primary) {
    final items = [
      const _Item(Icons.person_outlined, 'Check-in',
          'Present booking ref at front desk', '2PM'),
      const _Item(Icons.access_time, 'Early Arrival',
          'Arrive 15 min before check-in', 'EARLY'),
      const _Item(Icons.badge_outlined, 'ID Document',
          'Valid CNIC / Passport required', 'ID'),
      const _Item(
          Icons.luggage, 'Checkout', 'By 12:00 PM on checkout date', '12PM'),
    ];
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E8EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.checklist_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PRE-STAY CHECKLIST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} ITEMS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Checklist Items
            ...items.map((item) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary.withValues(alpha: 0.1),
                              primary.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, size: 20, color: primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          item.tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primary) {
    return Column(
      children: [
        _buildSmartAddons(context),
        SizedBox(height: spacingUnit(2)),
        FadeTransition(
          opacity: _fadeAnim,
          child: ColRow(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            switched: ThemeBreakpoints.smUp(context),
            children: [
              SizedBox(
                width: ThemeBreakpoints.smUp(context) ? 250 : double.infinity,
                child: FilledButton(
                  onPressed: () => Get.toNamed(AppLink.myTicket),
                  style: ThemeButton.btnBig
                      .merge(ThemeButton.tonalPrimary(context)),
                  child: const Text('VIEW MY BOOKINGS'),
                ),
              ),
              SizedBox(
                height: ThemeBreakpoints.smUp(context) ? 0 : spacingUnit(2),
                width: ThemeBreakpoints.smUp(context) ? spacingUnit(2) : 0,
              ),
              SizedBox(
                width: ThemeBreakpoints.smUp(context) ? 250 : double.infinity,
                child: OutlinedButton(
                  onPressed: () => Get.toNamed(AppLink.home),
                  style: ThemeButton.btnBig
                      .merge(ThemeButton.outlinedPrimary(context)),
                  child: const Text('BOOK ANOTHER TRIP'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacingUnit(1.5)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generatingPdf ? null : _downloadHotelInvoicePdf,
            icon: _generatingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              _generatingPdf
                  ? 'Generating PDF...'
                  : 'DOWNLOAD HOTEL TAX INVOICE',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartAddons(BuildContext context) {
    final extras = [
      _HotelTravelExtra(
        icon: Icons.wb_sunny_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFFFF8EB),
        tag: 'LIVE',
        tagColor: const Color(0xFFF59E0B),
        title: 'Destination Weather',
        subtitle: '28°C · Sunny',
        action: 'View Forecast',
        onTap: () => Get.toNamed(AppLink.weather),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Text(
                  'ENHANCE YOUR JOURNEY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  'Powered by Travello',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueGrey.shade300,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
              height: 1,
              color: const Color(0xFFF0F2F5),
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 4),
          ...extras.map((ex) => _HotelExtraCardTile(ex: ex)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: EdgeInsets.all(spacingUnit(1.5)),
        decoration: BoxDecoration(
          color: Colors.white,
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _quickActionButton(
              icon: Icons.history,
              label: 'Order History',
              color: ThemePalette.tertiaryDark,
              bgColor: ThemePalette.tertiaryLight,
              onTap: () => Get.toNamed(AppLink.orderHistory),
            ),
            _quickActionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              color: ThemePalette.primaryDark,
              bgColor: ThemePalette.primaryLight,
              onTap: _shareHotelBooking,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacingUnit(1.5),
          vertical: spacingUnit(1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareHotelBooking() async {
    final hotel = bookingData['hotelName'] as String? ??
        bookingData['_hotelName'] as String? ??
        'Hotel';
    final ref = bookingData['bookingRef'] as String? ??
        bookingData['bookingReference'] as String? ??
        bookingReference;
    final checkIn = bookingData['_checkInStr'] as String? ??
        (bookingData['checkInDate'] is DateTime
            ? DateFormat('d MMM yyyy')
                .format(bookingData['checkInDate'] as DateTime)
            : 'N/A');
    final checkOut = bookingData['_checkOutStr'] as String? ??
        (bookingData['checkOutDate'] is DateTime
            ? DateFormat('d MMM yyyy')
                .format(bookingData['checkOutDate'] as DateTime)
            : 'N/A');
    final city = bookingData['_city'] as String? ??
        bookingData['city'] as String? ??
        bookingData['destination'] as String? ??
        'N/A';
    final summary = 'Travello AI - Hotel Booking\n'
        'Hotel: $hotel\n'
        'City: $city\n'
        'Booking Ref: $ref\n'
        'Check-in: $checkIn  |  Check-out: $checkOut\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Booked via Travello AI';
    await Clipboard.setData(ClipboardData(text: summary));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Booking details copied to clipboard'),
        ]),
        backgroundColor: Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════════
  // INVOICE MODAL — matches PDF invoice layout exactly (same sections/design)
  // ══════════════════════════════════════════════════════════════════════════
  void _showInvoiceModal() {
    const gold = Color(0xFFD4AF37);
    const green = Color(0xFF10B981);

    final hotel = bookingData['hotel'];
    final roomType = bookingData['roomType'];
    // Flat-field fallbacks for bookings-list view
    final hotelName =
        hotel?.name ?? bookingData['_hotelName'] as String? ?? 'Hotel';
    final hotelCity = hotel?.city ?? bookingData['_city'] as String? ?? '';
    final roomTypeName =
        roomType?.name ?? bookingData['_roomType'] as String? ?? 'Room';
    final hotelRatingN = (hotel?.rating as num?)?.toDouble() ??
        (bookingData['_rating'] as num?)?.toDouble() ??
        0.0;

    final checkIn = bookingData['checkInDate'] as DateTime?;
    final checkOut = bookingData['checkOutDate'] as DateTime?;
    final checkInStr = checkIn != null
        ? DateFormat('EEE, MMM d, yyyy').format(checkIn)
        : bookingData['_checkInStr'] as String? ?? 'N/A';
    final checkOutStr = checkOut != null
        ? DateFormat('EEE, MMM d, yyyy').format(checkOut)
        : bookingData['_checkOutStr'] as String? ?? 'N/A';

    final nights = (bookingData['nights'] as num?)?.toInt() ?? 1;
    final rooms = (bookingData['rooms'] as num?)?.toInt() ?? 1;
    final guests = (bookingData['guests'] as num?)?.toInt() ??
        (bookingData['passengerCount'] as num?)?.toInt() ??
        1;
    final guestsData = bookingData['guestsData'] as List? ?? [];
    final basePrice = (bookingData['basePrice'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = (bookingData['totalPrice'] as num?)?.toDouble() ??
        (bookingData['total'] as num?)?.toDouble() ??
        0.0;
    final extrasTotal = (bookingData['extrasTotal'] as num?)?.toDouble() ?? 0.0;
    final breakfastAdded = bookingData['breakfastAdded'] as bool? ?? false;
    final airportTransferAdded =
        bookingData['airportTransferAdded'] as bool? ?? false;
    final lateCheckoutAdded =
        bookingData['lateCheckoutAdded'] as bool? ?? false;
    final bookingType = bookingData['bookingType']?.toString() ?? 'standard';
    final firstGuest =
        guestsData.isNotEmpty ? guestsData[0] as Map : <dynamic, dynamic>{};
    final guestName = firstGuest['firstName'] != null
        ? '${firstGuest['firstName']} ${firstGuest['lastName'] ?? ''}'.trim()
        : (firstGuest['fullName']?.toString() ?? 'Guest');
    final guestCnic = firstGuest['cnic']?.toString() ?? '—';
    final guestPhone = firstGuest['phone']?.toString() ?? '—';
    final guestEmail = firstGuest['email']?.toString() ?? '—';
    final guestGender = firstGuest['gender']?.toString() ?? '—';
    final issuedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final transactionId = bookingData['transactionId'] as String? ??
        'TXN${DateTime.now().millisecondsSinceEpoch}';
    final isRefundable = bookingType != 'non-refundable';
    final fmtN = NumberFormat('#,##,###');
    final serviceCharge = basePrice * 0.05;
    final tourismTax = basePrice * 0.03;
    final gstVal = basePrice * 0.16;
    final roomsBase = basePrice - extrasTotal;
    final roomRatePerNight =
        (nights > 0 && rooms > 0) ? roomsBase / (nights * rooms) : roomsBase;
    final starLabel = hotel?.category ??
        (hotelRatingN > 0 ? '${hotelRatingN.toInt()}-Star' : '');

    Widget secHdr(String title) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: gold, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Container(width: 3, height: 14, color: Colors.white),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6)),
          ]),
        );

    Widget kvLight(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(v,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                bold ? FontWeight.bold : FontWeight.w600,
                            color: Colors.black87))),
              ]),
        );

    Widget divLight() =>
        Divider(color: Colors.grey.shade200, thickness: 1, height: 10);

    Widget tHead(String t, {TextAlign align = TextAlign.left}) => Container(
          color: gold,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(t,
              textAlign: align,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.4)),
        );

    Widget statCol(String label, String value, {bool golden = false}) =>
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: golden ? Colors.black87 : Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9, color: Colors.white70, letterSpacing: 0.4)),
          ]),
        );

    Widget goldDiv() => Container(
        width: 1, height: 32, color: Colors.white.withValues(alpha: 0.5));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool dl = false;
        return StatefulBuilder(builder: (ctx, setSt) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.93,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),

              // ── INVOICE HEADER (dark bg)
              Container(
                color: gold,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                            child: Text('H',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Travello AI',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Hotel Tax Invoice & Stay Receipt',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10)),
                              SizedBox(height: 3),
                              Text('NTN: 1234567-8  |  STRN: SC-01234-56789',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      letterSpacing: 0.3)),
                            ]),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(bookingReference,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(height: 4),
                            Text(issuedAt,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: green,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('CONFIRMED',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                    ]),
              ),

              // ── GOLDEN DOWNLOAD BAR
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFE6C68E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax Invoice Preview',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Row(children: [
                        GestureDetector(
                          onTap: dl
                              ? null
                              : () async {
                                  setSt(() => dl = true);
                                  await _downloadHotelInvoicePdf();
                                  setSt(() => dl = false);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ],
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              dl
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.download_rounded,
                                      color: Colors.white, size: 15),
                              const SizedBox(width: 6),
                              Text(dl ? 'Generating...' : 'Download PDF',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: Colors.white12, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white70),
                          ),
                        ),
                      ]),
                    ]),
              ),

              // ── SCROLLABLE INVOICE BODY
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ISSUED BY / BILL TO two columns
                          IntrinsicHeight(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('ISSUED BY',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: gold,
                                                    letterSpacing: 0.5)),
                                            const SizedBox(height: 6),
                                            const Text(
                                                'Travello AI (Pvt.) Ltd.',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 3),
                                            Text(
                                                '15-B, Clifton Block 5,\nKarachi, Pakistan',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            Text('support@travelloai.com',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            Text('+92 300 1234567',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            Text('www.travelloai.com',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                          ]),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('BILL TO (GUEST)',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: gold,
                                                    letterSpacing: 0.5)),
                                            const SizedBox(height: 6),
                                            Text(guestName.toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 3),
                                            if (guestCnic != '—')
                                              Text('CNIC: $guestCnic',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .grey.shade600)),
                                            if (guestPhone != '—')
                                              Text('Phone: $guestPhone',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .grey.shade600)),
                                            if (guestEmail != '—')
                                              Text('Email: $guestEmail',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .grey.shade600)),
                                            if (guestGender != '—')
                                              Text('Gender: $guestGender',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .grey.shade600)),
                                            Text('Total Guests: $guests',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                          ]),
                                    ),
                                  ),
                                ]),
                          ),
                          const SizedBox(height: 12),

                          // HOTEL INFORMATION
                          secHdr('HOTEL INFORMATION'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(hotelName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  if (starLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: gold,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Text(starLabel,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(height: 6),
                                  if (hotel?.address != null &&
                                      (hotel?.address ?? '').isNotEmpty)
                                    Text(hotel!.address,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                  if (hotelCity.isNotEmpty)
                                    Text('$hotelCity, Pakistan',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                ]),
                          ),
                          const SizedBox(height: 12),

                          // STAY STRIP
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  statCol('NIGHTS', '$nights'),
                                  goldDiv(),
                                  statCol('ROOM TYPE', roomTypeName,
                                      golden: true),
                                  goldDiv(),
                                  statCol('ROOMS', '$rooms'),
                                  goldDiv(),
                                  statCol('GUESTS', '$guests'),
                                ]),
                          ),
                          const SizedBox(height: 12),

                          // SERVICES & CHARGES TABLE
                          secHdr('SERVICES & CHARGES  (FBR Tax Invoice)'),
                          const SizedBox(height: 8),
                          Table(
                            border: TableBorder.all(
                                color: Colors.grey.shade200, width: 0.5),
                            columnWidths: const {
                              0: FixedColumnWidth(24),
                              1: FlexColumnWidth(3.6),
                              2: FlexColumnWidth(1.8),
                              3: FixedColumnWidth(60),
                              4: FlexColumnWidth(1.8),
                            },
                            children: [
                              TableRow(children: [
                                tHead('#'),
                                tHead('DESCRIPTION'),
                                tHead('UNIT RATE', align: TextAlign.right),
                                tHead('QTY', align: TextAlign.center),
                                tHead('AMOUNT', align: TextAlign.right),
                              ]),
                              TableRow(children: [
                                Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(8),
                                    child: Text('1',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500))),
                                Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${roomType?.name ?? 'Room'} — Hotel Accommodation',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                          Text('Check-In: $checkInStr',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey.shade500)),
                                          Text('Check-Out: $checkOutStr',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey.shade500)),
                                          if ((roomType?.bedType ?? '')
                                              .isNotEmpty)
                                            Text('Bed: ${roomType!.bedType}',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color:
                                                        Colors.grey.shade500)),
                                        ])),
                                Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 7),
                                    child: Text(
                                        'PKR ${fmtN.format(roomRatePerNight.round())}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 10))),
                                Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 7),
                                    child: Text('${nights}N x ${rooms}Rm',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade500))),
                                Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 7),
                                    child: Text(
                                        'PKR ${fmtN.format(roomsBase.round())}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))),
                              ]),
                              if (breakfastAdded)
                                _extraTableRow(
                                    2, 'Breakfast (for Guests)', 1500, fmtN),
                              if (airportTransferAdded)
                                _extraTableRow(breakfastAdded ? 3 : 2,
                                    'Airport Transfer', 2500, fmtN),
                              if (lateCheckoutAdded)
                                _extraTableRow(
                                    (breakfastAdded ? 1 : 0) +
                                        (airportTransferAdded ? 1 : 0) +
                                        2,
                                    'Late Check-Out',
                                    1000,
                                    fmtN),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // FARE BREAKDOWN
                          secHdr('FARE BREAKDOWN'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6)),
                            child: Column(children: [
                              kvLight('Base Accommodation',
                                  'PKR ${fmtN.format(roomsBase.round())}'),
                              if (breakfastAdded)
                                kvLight(
                                    'Breakfast', 'PKR ${fmtN.format(1500)}'),
                              if (airportTransferAdded)
                                kvLight('Airport Transfer',
                                    'PKR ${fmtN.format(2500)}'),
                              if (lateCheckoutAdded)
                                kvLight('Late Check-Out',
                                    'PKR ${fmtN.format(1000)}'),
                              divLight(),
                              kvLight('Service Charge (5%)',
                                  'PKR ${fmtN.format(serviceCharge.round())}'),
                              kvLight('Tourism / FED Tax (3%)',
                                  'PKR ${fmtN.format(tourismTax.round())}'),
                              kvLight('GST @ 16% (FBR)',
                                  'PKR ${fmtN.format(gstVal.round())}'),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL PAYABLE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          letterSpacing: 0.6)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        'PKR ${fmtN.format(totalPrice.round())}',
                                        style: const TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                ]),
                          ),
                          const SizedBox(height: 12),

                          // PAYMENT INFORMATION
                          secHdr('PAYMENT INFORMATION'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(6)),
                            child: Column(children: [
                              kvLight('Payment Method', 'Card'),
                              kvLight('Transaction ID', transactionId),
                              kvLight('Booking Reference', bookingReference),
                              kvLight('Date Issued', issuedAt),
                              divLight(),
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Status',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600)),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: green,
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: const Text('CONFIRMED',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ])),
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Cancellation',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: isRefundable
                                                  ? green
                                                  : Colors.red.shade400,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Text(
                                              isRefundable
                                                  ? 'Refundable'
                                                  : 'Non-Refundable',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ])),
                            ]),
                          ),
                          const SizedBox(height: 12),

                          // Important Notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border:
                                    Border.all(color: Colors.amber.shade200),
                                borderRadius: BorderRadius.circular(6)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Important Notice',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                  const SizedBox(height: 5),
                                  Text(
                                      'Please check with hotel for restrictions. This invoice is FBR-compliant.\nFor support: support@travelloai.com  |  +92 300 1234567',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade700)),
                                ]),
                          ),
                        ]),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  // Extra row helper for services table in modal
  TableRow _extraTableRow(int idx, String desc, int price, NumberFormat fmt) {
    return TableRow(children: [
      Container(
          color: const Color(0xFFF8F8F8),
          padding: const EdgeInsets.all(8),
          child: Text('$idx',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
      Container(
          color: const Color(0xFFF8F8F8),
          padding: const EdgeInsets.all(8),
          child: Text(desc,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w500))),
      Container(
          color: const Color(0xFFF8F8F8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text('PKR ${fmt.format(price)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10))),
      Container(
          color: const Color(0xFFF8F8F8),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Text('1 x 1',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500))),
      Container(
          color: const Color(0xFFF8F8F8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text('PKR ${fmt.format(price)}',
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
    ]);
  }

  // PDF GENERATION — Pakistan FBR-Compliant Hotel Tax Invoice
  // Theme: Travello AI Gold + Dark (ThemePalette consistent)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _downloadHotelInvoicePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final hotel = bookingData['hotel'];
      final roomType = bookingData['roomType'];
      final checkIn = bookingData['checkInDate'] as DateTime?;
      final checkOut = bookingData['checkOutDate'] as DateTime?;
      final nights = (bookingData['nights'] as num?)?.toInt() ?? 1;
      final rooms = (bookingData['rooms'] as num?)?.toInt() ?? 1;
      final guests = (bookingData['guests'] as num?)?.toInt() ?? 1;
      final guestsData = bookingData['guestsData'] as List? ?? [];
      final basePrice = (bookingData['basePrice'] as num?)?.toDouble() ?? 0.0;
      final totalPrice = (bookingData['totalPrice'] as num?)?.toDouble() ?? 0.0;
      final extrasTotal =
          (bookingData['extrasTotal'] as num?)?.toDouble() ?? 0.0;
      final extrasIncluded =
          (bookingData['extrasIncluded'] as List?)?.cast<String>() ?? [];
      final breakfastAdded = bookingData['breakfastAdded'] as bool? ?? false;
      final airportTransferAdded =
          bookingData['airportTransferAdded'] as bool? ?? false;
      final lateCheckoutAdded =
          bookingData['lateCheckoutAdded'] as bool? ?? false;

      // Per-item prices (matching hotel_guest_form_screen.dart)
      final breakfastPrice = breakfastAdded ? 1500.0 : 0.0;
      final transferPrice = airportTransferAdded ? 2500.0 : 0.0;
      final lateCheckoutPrice = lateCheckoutAdded ? 1000.0 : 0.0;

      final serviceCharge = basePrice * 0.05;
      final tourismTax = basePrice * 0.03;
      final gstVal = basePrice * 0.16;
      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
      final issuedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
      final isRefundable = hotel?.isRefundable == true;

      // Guest details from booking form
      final firstGuest =
          guestsData.isNotEmpty ? guestsData[0] as Map : <dynamic, dynamic>{};
      final guestName = firstGuest['firstName'] != null
          ? '${firstGuest['firstName']} ${firstGuest['lastName'] ?? ''}'.trim()
          : (firstGuest['fullName']?.toString() ?? 'Guest');
      final guestCnic = firstGuest['cnic']?.toString() ?? '';
      final guestPhone = firstGuest['phone']?.toString() ?? '';
      final guestEmail = firstGuest['email']?.toString() ?? '';
      final guestGender = firstGuest['gender']?.toString() ?? '';

      final fontRegular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Regular.ttf'));
      final fontBold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Bold.ttf'));
      final fontMedium =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Medium.ttf'));

      final fmtPkr = NumberFormat('#,##,###', 'en_PK');
      String pkr(double? v) => 'PKR ${fmtPkr.format((v ?? 0).round())}';
      String fmtDate(DateTime? d) =>
          d != null ? DateFormat('EEE, dd MMM yyyy').format(d) : 'N/A';

      // Per-room-per-night rate (accommodation only)
      final roomsBase = basePrice - extrasTotal;
      final roomRatePerNight =
          (nights > 0 && rooms > 0) ? roomsBase / (nights * rooms) : roomsBase;

      // ── Travello AI Gold PDF Palette (all dark→gold) ──
      // Gold accent  #D4AF37
      const pdfGold = PdfColor(0.831, 0.686, 0.216);
      const pdfDark = PdfColor(0.831, 0.686, 0.216);
      const pdfDarker = PdfColor(0.831, 0.686, 0.216);
      // Success green
      const pdfGreen = PdfColor(0.063, 0.725, 0.506);
      const pdfRed = PdfColor(0.937, 0.267, 0.267);
      const pdfSurface = PdfColor(0.98, 0.98, 0.98);
      // Light border for table lines
      const pdfBorderLight = PdfColor(0.878, 0.878, 0.878);
      // Text dark (on light background)
      const pdfTxtPri = PdfColor(0.1, 0.1, 0.1);
      const pdfTxtSec = PdfColor(0.35, 0.35, 0.35);
      // Muted grey
      const pdfTxtMuted = PdfColor(0.5, 0.5, 0.5);

      // ── Label for section headers ──────────────────────────────
      pw.Widget secHeader(String title) => pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
                color: pdfGold,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
            child: pw.Row(children: [
              pw.Container(width: 3, height: 12, color: PdfColors.white),
              pw.SizedBox(width: 8),
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      font: fontBold,
                      letterSpacing: 0.6)),
            ]),
          );

      // ── Key-value row (on light background) ───────────────────
      pw.Widget kvRow(String k, String v,
              {PdfColor? vColor, bool bold = false}) =>
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k,
                      style: pw.TextStyle(
                          fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                  pw.Flexible(
                    child: pw.Text(v,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: bold ? pw.FontWeight.bold : null,
                            color: vColor ?? pdfTxtPri,
                            font: bold ? fontBold : fontMedium)),
                  ),
                ]),
          );

      pw.Widget thinDiv() => pw.Divider(color: pdfBorderLight, thickness: 0.5);

      final doc = pw.Document(
          title: 'Hotel Tax Invoice — $bookingReference',
          author: 'Travello AI',
          subject: 'Pakistan FBR-Compliant Hotel Stay Receipt');

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 38, vertical: 30),
        build: (pw.Context ctx) => [
          // ══════════════════════════════════════════════════
          // HEADER — Dark bg, Gold accent
          // ══════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: const pw.BoxDecoration(
                color: pdfDarker,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo box (gold)
                  pw.Container(
                    width: 52,
                    height: 52,
                    decoration: const pw.BoxDecoration(
                        color: pdfGold,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(8))),
                    child: pw.Center(
                        child: pw.Text('H',
                            style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: fontBold))),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Travello AI',
                              style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold)),
                          pw.Text('Hotel Tax Invoice & Stay Receipt',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColors.white,
                                  font: fontMedium)),
                          pw.SizedBox(height: 4),
                          pw.Text('NTN: 1234567-8  |  STRN: SC-01234-56789',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.white,
                                  font: fontRegular)),
                        ]),
                  ),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  color: PdfColors.white, width: 2),
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4))),
                          child: pw.Text(bookingReference,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold,
                                  letterSpacing: 2)),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(issuedAt,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.white,
                                font: fontRegular)),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: const pw.BoxDecoration(
                              color: pdfGreen,
                              borderRadius:
                                  pw.BorderRadius.all(pw.Radius.circular(4))),
                          child: pw.Text('CONFIRMED',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold,
                                  letterSpacing: 0.5)),
                        ),
                      ]),
                ]),
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // ISSUED BY  |  BILL TO  (light background)
          // ══════════════════════════════════════════════════
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: pdfSurface,
                    border: pw.Border.all(color: pdfBorderLight),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ISSUED BY',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfGold,
                              font: fontBold,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 5),
                      pw.Text('Travello AI (Pvt.) Ltd.',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTxtPri,
                              font: fontBold)),
                      pw.SizedBox(height: 2),
                      pw.Text('15-B, Clifton Block 5, Karachi, Pakistan',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('support@travelloai.com',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('+92 300 1234567',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('www.travelloai.com',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                    ]),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: pdfSurface,
                    border: pw.Border.all(color: pdfBorderLight),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO (GUEST)',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfGold,
                              font: fontBold,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 5),
                      pw.Text(guestName.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTxtPri,
                              font: fontBold)),
                      pw.SizedBox(height: 2),
                      if (guestCnic.isNotEmpty)
                        pw.Text('CNIC: $guestCnic',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      if (guestPhone.isNotEmpty)
                        pw.Text('Phone: $guestPhone',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      if (guestEmail.isNotEmpty)
                        pw.Text('Email: $guestEmail',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      if (guestGender.isNotEmpty)
                        pw.Text('Gender: $guestGender',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      pw.Text('Total Guests: $guests',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                    ]),
              ),
            ),
          ]),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // HOTEL INFORMATION
          // ══════════════════════════════════════════════════
          secHeader('HOTEL INFORMATION'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: pdfSurface,
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(hotel?.name ?? 'Hotel',
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTxtPri,
                                  font: fontBold)),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: const pw.BoxDecoration(
                                color: pdfGold,
                                borderRadius:
                                    pw.BorderRadius.all(pw.Radius.circular(4))),
                            child: pw.Text(hotel?.category ?? '',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                    font: fontBold)),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(hotel?.address ?? '',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                          pw.Text('${hotel?.city ?? ''}, Pakistan',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                        ]),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.6),
                      1: const pw.FlexColumnWidth(1.4),
                    },
                    children: [
                      _pdfKvTableRow(
                          'Star Rating',
                          '${hotel?.rating ?? 'N/A'} / 5.0',
                          fontBold,
                          fontRegular),
                      _pdfKvTableRow('Check-In Date', fmtDate(checkIn),
                          fontBold, fontRegular),
                      _pdfKvTableRow('Check-Out Date', fmtDate(checkOut),
                          fontBold, fontRegular),
                      _pdfKvTableRow(
                          'Check-In Time', '2:00 PM', fontBold, fontRegular),
                      _pdfKvTableRow(
                          'Check-Out Time', '12:00 PM', fontBold, fontRegular),
                    ],
                  ),
                ]),
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // STAY SUMMARY STRIP (Gold accent)
          // ══════════════════════════════════════════════════
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const pw.BoxDecoration(
                color: pdfDark,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatDark('NIGHTS', '$nights', fontBold, fontRegular),
                  _pdfVertDividerGold(),
                  _pdfStatDark('ROOM TYPE', roomType?.name ?? 'Room', fontBold,
                      fontRegular),
                  _pdfVertDividerGold(),
                  _pdfStatDark('ROOMS', '$rooms', fontBold, fontRegular),
                  _pdfVertDividerGold(),
                  _pdfStatDark('GUESTS', '$guests', fontBold, fontRegular),
                ]),
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // SERVICES & CHARGES TABLE
          // ══════════════════════════════════════════════════
          secHeader('SERVICES & CHARGES  (FBR Tax Invoice)'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: pdfBorderLight, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(3.6),
              2: const pw.FlexColumnWidth(1.7),
              3: const pw.FixedColumnWidth(54),
              4: const pw.FlexColumnWidth(1.7),
            },
            children: [
              // Table header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdfDark),
                children: ['#', 'DESCRIPTION', 'UNIT RATE', 'QTY', 'AMOUNT']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfGold,
                                  font: fontBold)),
                        ))
                    .toList(),
              ),
              // Room accommodation
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.white),
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('1',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtMuted,
                              font: fontRegular))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                '${roomType?.name ?? 'Room'} — Hotel Accommodation',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: pdfTxtPri,
                                    font: fontBold)),
                            pw.Text('Check-In: ${fmtDate(checkIn)}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: pdfTxtSec,
                                    font: fontRegular)),
                            pw.Text('Check-Out: ${fmtDate(checkOut)}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: pdfTxtSec,
                                    font: fontRegular)),
                            if ((roomType?.bedType ?? '').isNotEmpty)
                              pw.Text('Bed: ${roomType!.bedType!}',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      color: pdfTxtSec,
                                      font: fontRegular)),
                          ])),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(pkr(roomRatePerNight),
                          style: pw.TextStyle(
                              fontSize: 9, color: pdfTxtPri, font: fontRegular),
                          textAlign: pw.TextAlign.right)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('$nights N x $rooms Rm',
                          style: pw.TextStyle(
                              fontSize: 8, color: pdfTxtSec, font: fontRegular),
                          textAlign: pw.TextAlign.center)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(pkr(roomsBase),
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTxtPri,
                              font: fontBold),
                          textAlign: pw.TextAlign.right)),
                ],
              ),
              // Breakfast add-on
              if (breakfastAdded)
                _pdfExtraRow(
                    extrasIncluded
                            .where((e) => e.contains('Breakfast'))
                            .firstOrNull ??
                        'Breakfast for 2',
                    breakfastPrice,
                    extrasIncluded.isNotEmpty
                        ? extrasIncluded.indexOf(extrasIncluded
                                    .where((e) => e.contains('Breakfast'))
                                    .firstOrNull ??
                                '') +
                            2
                        : 2,
                    fontBold,
                    fontRegular,
                    fontMedium,
                    pdfSurface,
                    pdfTxtPri,
                    pdfTxtSec,
                    pdfGreen,
                    pkr),
              // Airport transfer add-on
              if (airportTransferAdded)
                _pdfExtraRow(
                    extrasIncluded
                            .where((e) => e.contains('transfer'))
                            .firstOrNull ??
                        'Airport Transfer',
                    transferPrice,
                    (breakfastAdded ? 3 : 2),
                    fontBold,
                    fontRegular,
                    fontMedium,
                    pdfSurface,
                    pdfTxtPri,
                    pdfTxtSec,
                    pdfGreen,
                    pkr),
              // Late checkout add-on
              if (lateCheckoutAdded)
                _pdfExtraRow(
                    extrasIncluded
                            .where((e) => e.contains('check-out'))
                            .firstOrNull ??
                        'Late Check-Out',
                    lateCheckoutPrice,
                    (breakfastAdded ? 1 : 0) +
                        (airportTransferAdded ? 1 : 0) +
                        2,
                    fontBold,
                    fontRegular,
                    fontMedium,
                    pdfSurface,
                    pdfTxtPri,
                    pdfTxtSec,
                    pdfGreen,
                    pkr),
            ],
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // FARE BREAKDOWN  (full width — no truncation)
          // ══════════════════════════════════════════════════
          secHeader('FARE BREAKDOWN'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: pdfSurface,
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: [
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Base Accommodation',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                    pw.Text(pkr(roomsBase),
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                  ]),
              if (breakfastAdded) ...[
                thinDiv(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Breakfast for 2',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text(pkr(breakfastPrice),
                          style: pw.TextStyle(
                              fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                    ]),
              ],
              if (airportTransferAdded) ...[
                thinDiv(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Airport Transfer',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text(pkr(transferPrice),
                          style: pw.TextStyle(
                              fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                    ]),
              ],
              if (lateCheckoutAdded) ...[
                thinDiv(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Late Check-Out',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text(pkr(lateCheckoutPrice),
                          style: pw.TextStyle(
                              fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                    ]),
              ],
              thinDiv(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Service Charge (5%)',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                    pw.Text(pkr(serviceCharge),
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                  ]),
              thinDiv(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tourism / FED Tax (3%)',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                    pw.Text(pkr(tourismTax),
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                  ]),
              thinDiv(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GST @ 16% (FBR)',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                    pw.Text(pkr(gstVal),
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontMedium)),
                  ]),
              pw.SizedBox(height: 5),
              pw.Container(
                height: 2,
                color: pdfGold,
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL PAYABLE',
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfTxtPri,
                            font: fontBold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: const pw.BoxDecoration(
                          color: pdfGold,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Text(pkr(totalPrice),
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              font: fontBold)),
                    ),
                  ]),
            ]),
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // PAYMENT INFORMATION  (full width — all rows visible)
          // ══════════════════════════════════════════════════
          secHeader('PAYMENT INFORMATION'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: pdfSurface,
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: [
              kvRow('Payment Method',
                  bookingData['paymentMethod'] as String? ?? 'Card'),
              thinDiv(),
              kvRow('Transaction ID', transactionId),
              thinDiv(),
              kvRow('Booking Reference', bookingReference,
                  bold: true, vColor: pdfGold),
              thinDiv(),
              kvRow('Invoice Date & Time', issuedAt),
              thinDiv(),
              kvRow('Booking Status', 'CONFIRMED',
                  vColor: pdfGreen, bold: true),
              thinDiv(),
              kvRow(
                  'Cancellation Policy',
                  isRefundable
                      ? 'Refundable — Free cancellation 24h before check-in'
                      : 'Non-Refundable — No cancellations permitted',
                  vColor: isRefundable ? pdfGreen : pdfRed,
                  bold: true),
              thinDiv(),
              kvRow('Total Nights', '$nights night(s)'),
              thinDiv(),
              kvRow('Total Rooms', '$rooms room(s)'),
              thinDiv(),
              kvRow('Total Guests', '$guests guest(s)'),
            ]),
          ),

          pw.SizedBox(height: 12),

          // ══════════════════════════════════════════════════
          // FBR TERMS & CONDITIONS
          // ══════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: const PdfColor(0.96, 0.96, 0.96),
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Container(width: 3, height: 12, color: pdfGold),
                    pw.SizedBox(width: 8),
                    pw.Text('TERMS, CONDITIONS & IMPORTANT NOTICES',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfTxtPri,
                            font: fontBold)),
                  ]),
                  pw.SizedBox(height: 8),
                  for (final line in [
                    'This is a valid FBR-compliant Tax Invoice for hotel accommodation services provided in Pakistan.',
                    'GST @ 16% has been charged as per Federal Board of Revenue (FBR) regulations on hotel services.',
                    'Check-in time: 2:00 PM  |  Check-out time: 12:00 PM. Early/late check-in subject to availability.',
                    'A valid CNIC or Passport is mandatory at check-in as per NADRA / FIA regulations for all guests.',
                    isRefundable
                        ? 'This booking is REFUNDABLE. Full refund applies for cancellations made 24 hours before check-in.'
                        : 'This booking is NON-REFUNDABLE. No cancellations or changes are permitted after confirmation.',
                    'All disputes related to this invoice shall be subject to jurisdiction of courts in Karachi, Pakistan.',
                    'For support: support@travelloai.com  |  +92 300 1234567  |  www.travelloai.com',
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text('• $line',
                          style: pw.TextStyle(
                              fontSize: 9,
                              height: 1.5,
                              color: pdfTxtSec,
                              font: fontRegular)),
                    ),
                ]),
          ),

          pw.SizedBox(height: 10),

          // ══════════════════════════════════════════════════
          // FOOTER
          // ══════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            decoration: const pw.BoxDecoration(
                border:
                    pw.Border(top: pw.BorderSide(color: pdfGold, width: 1.5))),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Travello AI (Pvt.) Ltd.  |  www.travelloai.com',
                      style: pw.TextStyle(
                          fontSize: 8, color: pdfTxtMuted, font: fontRegular)),
                  pw.Text('Invoice: $bookingReference  |  Generated: $issuedAt',
                      style: pw.TextStyle(
                          fontSize: 8, color: pdfTxtMuted, font: fontRegular)),
                ]),
          ),
        ],
      ));

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invoice generation failed: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ── PDF helper: stat column (dark bg, gold text) ───────────────────────
  pw.Widget _pdfStatDark(
      String label, String value, pw.Font bold, pw.Font regular) {
    return pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.831, 0.686, 0.216), // gold
              font: bold)),
      pw.SizedBox(height: 3),
      pw.Text(label,
          style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey400,
              font: regular,
              letterSpacing: 0.4)),
    ]);
  }

  // ── PDF helper: gold vertical divider for stat strip ──────────────────
  pw.Widget _pdfVertDividerGold() => pw.Container(
      width: 1, height: 28, color: const PdfColor(0.831, 0.686, 0.216));

  // ── PDF helper: hotel info key-value table row ─────────────────────────
  pw.TableRow _pdfKvTableRow(
      String k, String v, pw.Font bold, pw.Font regular) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(k,
            style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor(0.35, 0.35, 0.35),
                font: regular)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(v,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.1, 0.1, 0.1),
                font: bold),
            textAlign: pw.TextAlign.right),
      ),
    ]);
  }

  // ── PDF helper: extras add-on table row ───────────────────────────────
  pw.TableRow _pdfExtraRow(
    String name,
    double price,
    int index,
    pw.Font fontBold,
    pw.Font fontRegular,
    pw.Font fontMedium,
    PdfColor surface,
    PdfColor txtPri,
    PdfColor txtSec,
    PdfColor green,
    String Function(double?) pkr,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: surface),
      children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('$index',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: const PdfColor(0.5, 0.5, 0.5),
                    font: fontRegular))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(name,
                style: pw.TextStyle(
                    fontSize: 9, color: txtPri, font: fontRegular))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(pkr(price),
                style:
                    pw.TextStyle(fontSize: 9, color: txtPri, font: fontRegular),
                textAlign: pw.TextAlign.right)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('1',
                style:
                    pw.TextStyle(fontSize: 9, color: txtSec, font: fontRegular),
                textAlign: pw.TextAlign.center)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(pkr(price),
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: txtPri,
                    font: fontBold),
                textAlign: pw.TextAlign.right)),
      ],
    );
  }

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

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: spacingUnit(0.5)),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    color: Colors.black87)),
          ),
        ]),
      );

  Widget _div() => Padding(
        padding: EdgeInsets.symmetric(vertical: spacingUnit(1)),
        child: Divider(color: Colors.grey.shade200, height: 1),
      );
}

// ── Progress Widgets ─────────────────────────────────────────────────────────

class _ProgStep extends StatelessWidget {
  final int num;
  final String label;
  final bool done;
  final Color primary;
  const _ProgStep(
      {required this.num,
      required this.label,
      required this.done,
      required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: done ? primary : const Color(0xFFE0E0E0),
            shape: BoxShape.circle),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text('$num',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
        ),
      ),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              fontSize: 9,
              color: done ? primary : Colors.grey.shade500,
              fontWeight: FontWeight.normal)),
    ]);
  }
}

class _ProgLine extends StatelessWidget {
  final bool done;
  final Color primary;
  const _ProgLine({required this.done, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 18),
          color: done ? primary : const Color(0xFFE0E0E0)),
    );
  }
}

// ── Checklist item data ──────────────────────────────────────────────────────
class _Item {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  const _Item(this.icon, this.title, this.subtitle, this.tag);
}

class _HotelTravelExtra {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String tag;
  final Color tagColor;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  const _HotelTravelExtra({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
}

class _HotelExtraCardTile extends StatefulWidget {
  final _HotelTravelExtra ex;
  const _HotelExtraCardTile({required this.ex});
  @override
  State<_HotelExtraCardTile> createState() => _HotelExtraCardTileState();
}

class _HotelExtraCardTileState extends State<_HotelExtraCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: ex.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? ex.iconColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: ex.iconColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _hovered ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ex.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ex.icon, color: ex.iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(ex.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              )),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ex.tagColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: ex.tagColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(ex.tag,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: ex.tagColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(ex.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          )),
                    ],
                  ),
                ),
                AnimatedSlide(
                  offset: _hovered ? const Offset(0.15, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(ex.action,
                          style: TextStyle(
                            fontSize: 11,
                            color: ex.iconColor,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: ex.iconColor),
                    ],
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
