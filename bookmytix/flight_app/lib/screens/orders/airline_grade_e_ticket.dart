import 'dart:math' as math;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  ✈️ TRAVELLO AI — AIRLINE-GRADE E-TICKET
//  International Standard | IATA-Compliant | Print-Ready
//  Design Level: Emirates, Qatar Airways, Lufthansa quality
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// ═══════════════════════════════════════════════════════════════════════════
/// DESIGN SYSTEM - Airline-Grade Tokens
/// ═════════════════════════════════════════════════════════════════════════════

class AirlineDesignSystem {
  // ────────────────────────────────────────────────────────────────────────
  // COLOR PALETTE (International Airline Standard)
  // ────────────────────────────────────────────────────────────────────────

  // Primary Brand Colors
  static const brandNavy = Color(0xFF0A1628);
  static const brandBlue = Color(0xFF2563EB);
  static const brandSky = Color(0xFF3B82F6);
  static const brandBlueLight = Color(0xFFDBEAFE);

  // Success Colors
  static const successPrimary = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const successBg = Color(0xFFF0FDF4);

  // Warning Colors
  static const warningPrimary = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);

  // Error Colors
  static const errorPrimary = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);

  // Neutral Palette
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const surfaceCream = Color(0xFFFAFBFC);
  static const surfaceLight = Color(0xFFF8FAFC);

  static const borderLight = Color(0xFFE2E8F0);
  static const borderMedium = Color(0xFFCBD5E1);
  static const borderDark = Color(0xFF94A3B8);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const textDisabled = Color(0xFFCBD5E1);

  // ────────────────────────────────────────────────────────────────────────
  // GRADIENTS
  // ────────────────────────────────────────────────────────────────────────

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF1E3A70)],
  );

  static const successGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
  );

  // ────────────────────────────────────────────────────────────────────────
  // SHADOWS (Elevation System)
  // ────────────────────────────────────────────────────────────────────────

  static const shadowSm = [
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const shadowMd = [
    BoxShadow(
      color: Color(0x0F0A1628),
      blurRadius: 6,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const shadowLg = [
    BoxShadow(
      color: Color(0x140A1628),
      blurRadius: 15,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 6,
      offset: Offset(0, 4),
    ),
  ];

  static const shadowXl = [
    BoxShadow(
      color: Color(0x1A0A1628),
      blurRadius: 25,
      offset: Offset(0, 20),
    ),
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 10,
      offset: Offset(0, 8),
    ),
  ];

  // ────────────────────────────────────────────────────────────────────────
  // TYPOGRAPHY SCALE
  // ────────────────────────────────────────────────────────────────────────

  // Hero/Display
  static TextStyle pnrCode() => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        height: 1.2,
        color: brandNavy,
      );

  // Large Titles
  static TextStyle cityCode() => const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        height: 1.0,
        color: textPrimary,
      );

  static TextStyle sectionTitle() => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.3,
        color: textPrimary,
      );

  // Body/Primary
  static TextStyle flightTime() => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.2,
        color: textPrimary,
      );

  static TextStyle passengerName() => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
        color: textPrimary,
      );

  static TextStyle bodyText() => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.5,
        color: textSecondary,
      );

  // Supporting/Metadata
  static TextStyle labelText({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        height: 1.3,
        color: color ?? textTertiary,
      );

  static TextStyle captionText({Color? color}) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
        color: color ?? textTertiary,
      );

  static TextStyle finePrint() => const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        height: 1.5,
        color: textTertiary,
      );

  // Badge/Pill Text
  static TextStyle statusBadge() => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.0,
        color: successPrimary,
      );

  static TextStyle chipText({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.0,
        color: color ?? Colors.white,
      );

  // ────────────────────────────────────────────────────────────────────────
  // SPACING CONSTANTS (8pt Grid System)
  // ────────────────────────────────────────────────────────────────────────

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // Component-specific
  static const double cardPadding = 24.0;
  static const double sectionPadding = 20.0;
  static const double compactPadding = 12.0;
  static const double microPadding = 8.0;

  // Border Radius
  static const double radiusLg = 16.0;
  static const double radiusMd = 12.0;
  static const double radiusSm = 8.0;
  static const double radiusPill = 20.0;

  // Container Max Width
  static const double maxWidthTicket = 480.0;
}

typedef DS = AirlineDesignSystem;

/// ═══════════════════════════════════════════════════════════════════════════
/// MAIN E-TICKET SCREEN
/// ═══════════════════════════════════════════════════════════════════════════

class AirlineGradeETicket extends StatefulWidget {
  const AirlineGradeETicket({super.key});

  @override
  State<AirlineGradeETicket> createState() => _AirlineGradeETicketState();
}

class _AirlineGradeETicketState extends State<AirlineGradeETicket>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _booking = {};
  bool _isRoundTrip = false;
  bool _hidePdfOption = false;
  bool _generatingPdf = false;
  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBookingData();
  }

  void _initializeAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    _entryController.forward();
  }

  void _loadBookingData() {
    final raw = Get.arguments;
    if (raw is Map<String, dynamic>) {
      final data = Map<String, dynamic>.from(raw);
      final hidePdfOption = data.remove('hidePdfOption') == true;
      setState(() {
        _booking = data;
        _isRoundTrip = data['isRoundTrip'] == true;
        _hidePdfOption = hidePdfOption;
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // DATA ACCESSORS
  // ────────────────────────────────────────────────────────────────────────

  String get _pnr => _booking['pnr'] ?? 'TVL-000000';
  String get _formattedPnr {
    final raw = _pnr.replaceAll('-', '');
    if (raw.length >= 9) {
      return '${raw.substring(0, 3)}-${raw.substring(3, 6)}-${raw.substring(6)}';
    }
    return _pnr;
  }

  List<Map<String, dynamic>> get _allPassengers {
    final raw = _booking['allPassengers'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [
      {'name': 'Passenger', 'passportOrId': '', 'salutation': ''}
    ];
  }

  dynamic _flightData(bool isReturn, String key) {
    final fd = isReturn
        ? (_booking['returnFlightDetails'] as Map<String, dynamic>?)
        : (_booking['flightDetails'] as Map<String, dynamic>?);
    return fd?[key];
  }

  String _airline(bool r) => _flightData(r, 'airline') as String? ?? 'Airline';
  String _flightNum(bool r) =>
      _flightData(r, 'flightNumber') as String? ?? 'FL000';
  String _cabin(bool r) => _flightData(r, 'class') as String? ?? 'Economy';
  String _from(bool r) =>
      _flightData(r, 'from') as String? ?? 'Departure (DEP)';
  String _to(bool r) => _flightData(r, 'to') as String? ?? 'Arrival (ARR)';
  String _dep(bool r) => _flightData(r, 'departure') as String? ?? '00:00';
  String _arr(bool r) => _flightData(r, 'arrival') as String? ?? '00:00';
  String _duration(bool r) => _flightData(r, 'duration') as String? ?? '--';
  String _date(bool r) => _flightData(r, 'date') as String? ?? 'N/A';

  String _extractCode(String full) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(full);
    return match?.group(1) ?? full.substring(0, math.min(3, full.length));
  }

  String _extractCity(String full) => full.split('(').first.trim();

  // ────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.surfaceCream,
      appBar: _buildAppBar(),
      body: _booking.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: DS.surfaceWhite,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        color: DS.textPrimary,
        onPressed: () => Get.back(),
      ),
      title: Column(
        children: [
          Text('E-Ticket', style: DS.sectionTitle()),
          const SizedBox(height: 2),
          Text('Travello AI', style: DS.captionText()),
        ],
      ),
      centerTitle: true,
      actions: [
        if (!_hidePdfOption)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _generatingPdf ? null : _downloadPdf,
              icon: _generatingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                'PDF',
                style: DS.chipText(color: DS.brandBlue),
              ),
              style: TextButton.styleFrom(
                foregroundColor: DS.brandBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: DS.borderLight),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: DS.surfaceLight,
              shape: BoxShape.circle,
              boxShadow: DS.shadowMd,
            ),
            child: const Icon(
              Icons.airplane_ticket_outlined,
              size: 48,
              color: DS.brandBlue,
            ),
          ),
          const SizedBox(height: DS.space24),
          Text('No Booking Found', style: DS.sectionTitle()),
          const SizedBox(height: DS.space8),
          Text(
            'Complete a booking to view your e-ticket',
            style: DS.bodyText(),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // MAIN CONTENT
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final passengers = _allPassengers;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.space20,
            vertical: DS.space24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DS.maxWidthTicket),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusSection(),
                  const SizedBox(height: DS.space32),
                  ...List.generate(passengers.length, (i) {
                    final pax = passengers[i];
                    final name = pax['name'] as String? ?? 'Passenger ${i + 1}';
                    final doc = pax['passportOrId'] as String? ?? '';
                    return Column(
                      children: [
                        if (_isRoundTrip || passengers.length > 1)
                          _buildFlightLabel(
                              'OUTBOUND', name, Icons.flight_takeoff),
                        _buildTicketCard(false, name, doc),
                        const SizedBox(height: DS.space24),
                      ],
                    );
                  }),
                  if (_isRoundTrip)
                    ...List.generate(passengers.length, (i) {
                      final pax = passengers[i];
                      final name =
                          pax['name'] as String? ?? 'Passenger ${i + 1}';
                      final doc = pax['passportOrId'] as String? ?? '';
                      return Column(
                        children: [
                          _buildFlightLabel('RETURN', name, Icons.flight_land),
                          _buildTicketCard(true, name, doc),
                          const SizedBox(height: DS.space24),
                        ],
                      );
                    }),
                  _buildTravelGuidelines(),
                  const SizedBox(height: DS.space32),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 1: STATUS SECTION (PNR Prominence)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildStatusSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: DS.successGradient,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.shadowLg,
      ),
      padding: const EdgeInsets.all(DS.cardPadding),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: DS.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOKING CONFIRMED',
                      style: DS.chipText().copyWith(
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: DS.space4),
                    Text(
                      'Your e-ticket is ready',
                      style: DS.captionText(
                          color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.space20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            padding: const EdgeInsets.all(DS.space16),
            child: Column(
              children: [
                Text(
                  'CONFIRMATION CODE',
                  style:
                      DS.labelText(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: DS.space8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formattedPnr,
                      style: DS.pnrCode().copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: DS.space12),
                    GestureDetector(
                      onTap: _copyPnr,
                      child: Container(
                        padding: const EdgeInsets.all(DS.space8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                        ),
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyPnr() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _pnr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: DS.space12),
            Text('PNR copied: $_formattedPnr'),
          ],
        ),
        backgroundColor: DS.successPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // FLIGHT DIRECTION LABEL
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildFlightLabel(String label, String passengerName, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.space12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.space12,
              vertical: DS.space8,
            ),
            decoration: BoxDecoration(
              color: label == 'OUTBOUND' ? DS.brandNavy : DS.successPrimary,
              borderRadius: BorderRadius.circular(DS.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: DS.space8),
                Text(
                  '$label  •  $passengerName',
                  style: DS.chipText(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 3: TICKET CARD (Main Component)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildTicketCard(
      bool isReturn, String passengerName, String passportOrId) {
    final fromCode = _extractCode(_from(isReturn));
    final toCode = _extractCode(_to(isReturn));
    final fromCity = _extractCity(_from(isReturn));
    final toCity = _extractCity(_to(isReturn));
    final airline = _airline(isReturn);
    final flightNum = _flightNum(isReturn);
    final cabin = _cabin(isReturn);
    final dep = _dep(isReturn);
    final arr = _arr(isReturn);
    final dur = _duration(isReturn);
    final date = _date(isReturn);

    return Container(
      decoration: BoxDecoration(
        color: DS.surfaceWhite,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.shadowLg,
        border: Border.all(color: DS.borderLight, width: 1),
      ),
      child: Column(
        children: [
          // 3A. FLIGHT HEADER
          _buildCardHeader(airline, flightNum, cabin),

          // 3B. ROUTE SECTION
          _buildRouteSection(
              fromCode, toCode, fromCity, toCity, dep, arr, date, dur),

          // 3C. FLIGHT DETAILS GRID
          _buildFlightDetailsGrid(),

          // 3D. PERFORATED DIVIDER
          _buildPerforatedDivider(),

          // 3E. PASSENGER SECTION
          _buildPassengerSection(passengerName, passportOrId, date),

          // 3F. SCAN SECTION
          _buildScanSection(flightNum, isReturn, passengerName),
        ],
      ),
    );
  }

  // ── 3A. Card Header ─────────────────────────────────────────────────────

  Widget _buildCardHeader(String airline, String flightNum, String cabin) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DS.headerGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DS.radiusLg),
          topRight: Radius.circular(DS.radiusLg),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DS.cardPadding,
        vertical: DS.space20,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(Icons.flight, color: Colors.white, size: 28),
          ),
          const SizedBox(width: DS.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  airline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: DS.space4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.space8,
                    vertical: DS.space4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    flightNum,
                    style: DS.chipText().copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.space12,
                  vertical: DS.space8,
                ),
                decoration: BoxDecoration(
                  color: DS.successPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DS.radiusPill),
                  border: Border.all(
                    color: DS.successPrimary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: DS.successPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DS.space4),
                    Text('CONFIRMED', style: DS.statusBadge()),
                  ],
                ),
              ),
              const SizedBox(height: DS.space8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.space12,
                  vertical: DS.space4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cabin,
                  style: DS.captionText(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3B. Route Section ───────────────────────────────────────────────────

  Widget _buildRouteSection(
    String fromCode,
    String toCode,
    String fromCity,
    String toCity,
    String dep,
    String arr,
    String date,
    String dur,
  ) {
    return Container(
      padding: const EdgeInsets.all(DS.space32),
      child: Column(
        children: [
          // Airport Codes with connector in between
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FROM CODE
              Text(fromCode, style: DS.cityCode()),

              // CONNECTOR (spanning between codes)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DS.space16),
                  child: _buildFlightConnector(),
                ),
              ),

              // TO CODE
              Text(toCode, style: DS.cityCode()),
            ],
          ),

          const SizedBox(height: DS.space16),

          // Duration and NON-STOP badge centered
          Column(
            children: [
              Text(dur, style: DS.captionText()),
              const SizedBox(height: DS.space4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.space8,
                  vertical: DS.space4,
                ),
                decoration: BoxDecoration(
                  color: DS.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NON-STOP',
                  style: DS.chipText(color: DS.brandBlue).copyWith(
                        fontSize: 9,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.space16),

          // Times and cities
          Row(
            children: [
              // FROM details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dep, style: DS.flightTime()),
                    const SizedBox(height: DS.space4),
                    Text(date, style: DS.captionText()),
                  ],
                ),
              ),

              // TO details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(arr,
                        style: DS.flightTime(), textAlign: TextAlign.right),
                    const SizedBox(height: DS.space4),
                    Text(date,
                        style: DS.captionText(), textAlign: TextAlign.right),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlightConnector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left circle - hollow
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: DS.brandBlue, width: 1.5),
          ),
        ),
        // Left line (expandable)
        Expanded(
          child: Container(
            height: 2,
            color: DS.brandBlue.withValues(alpha: 0.3),
          ),
        ),
        // Plane icon in the middle
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.space8),
          child: Icon(
            Icons.flight,
            color: DS.brandBlue,
            size: 16,
          ),
        ),
        // Right line (expandable)
        Expanded(
          child: Container(
            height: 2,
            color: DS.brandBlue.withValues(alpha: 0.3),
          ),
        ),
        // Right circle - filled blue
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: DS.brandBlue,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  // ── 3C. Flight Details Grid ────────────────────────────────────────────

  Widget _buildFlightDetailsGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DS.cardPadding),
      padding: const EdgeInsets.all(DS.space16),
      decoration: BoxDecoration(
        color: DS.surfaceLight,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailChip(Icons.airline_seat_recline_normal, 'SEAT', 'A1'),
          _buildVerticalDivider(),
          _buildDetailChip(Icons.door_front_door_rounded, 'GATE', 'H22'),
          _buildVerticalDivider(),
          _buildDetailChip(Icons.account_balance_rounded, 'TERMINAL', '3'),
          _buildVerticalDivider(),
          _buildDetailChip(Icons.schedule_rounded, 'BOARDS', _dep(false)),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: DS.brandBlue),
        const SizedBox(height: DS.space4),
        Text(label, style: DS.labelText()),
        const SizedBox(height: DS.space4),
        Text(value, style: DS.bodyText()),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: DS.borderLight,
    );
  }

  // ── 3D. Perforated Divider ─────────────────────────────────────────────

  Widget _buildPerforatedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DS.space8),
      child: SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dashed line spanning full width
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 1,
                    color: DS.borderLight.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: DS.space12),
                  const SizedBox(
                    height: 8,
                    child: CustomPaint(
                      painter: _PerforationPainter(),
                      size: Size(double.infinity, 8),
                    ),
                  ),
                ],
              ),
            ),
            // Left circle
            Positioned(
              left: 0,
              child: Container(
                width: 18,
                height: 32,
                decoration: BoxDecoration(
                  color: DS.surfaceCream,
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.borderLight, width: 1),
                ),
              ),
            ),
            // Right circle
            Positioned(
              right: 0,
              child: Container(
                width: 18,
                height: 32,
                decoration: BoxDecoration(
                  color: DS.surfaceCream,
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.borderLight, width: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3E. Passenger Section ───────────────────────────────────────────────

  Widget _buildPassengerSection(String name, String passportOrId, String date) {
    return Container(
      padding: const EdgeInsets.all(DS.cardPadding),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DS.brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: DS.brandBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: DS.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PASSENGER', style: DS.labelText()),
                    const SizedBox(height: DS.space4),
                    Text(name, style: DS.passengerName()),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('PASSPORT / ID', style: DS.labelText()),
                  const SizedBox(height: DS.space4),
                  Text(
                    passportOrId.isNotEmpty ? passportOrId : 'N/A',
                    style: DS.bodyText(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DS.space20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIS TICKET', style: DS.labelText()),
                    const SizedBox(height: DS.space4),
                    Text('1 Passenger', style: DS.bodyText()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('PAID VIA', style: DS.labelText()),
                    const SizedBox(height: DS.space4),
                    Text(
                      _booking['paymentMethod'] as String? ?? 'Card',
                      style: DS.bodyText(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DATE', style: DS.labelText()),
                    const SizedBox(height: DS.space4),
                    Text(date, style: DS.bodyText()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3F. Scan Section ────────────────────────────────────────────────────

  Widget _buildScanSection(
      String flightNum, bool isReturn, String passengerName) {
    // Enhanced barcode format: PNR-LEG-ROUTE-FLIGHT-SEAT
    final leg = isReturn ? 'R' : 'O';
    final fromCode = _extractCode(_from(isReturn));
    final toCode = _extractCode(_to(isReturn));
    final route = '$fromCode$toCode';
    final seat = _flightData(isReturn, 'seat') ?? 'A1';
    final barcodeData = '$_pnr$leg$route$flightNum$seat'.toUpperCase();

    final qrData =
        'TRAVELLO|PNR:$_pnr|PAX:$passengerName|FLT:$flightNum|ROUTE:$fromCode-$toCode|SEAT:$seat|LEG:$leg';

    return Container(
      padding: const EdgeInsets.all(DS.cardPadding),
      decoration: const BoxDecoration(
        color: DS.surfaceLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(DS.radiusLg),
          bottomRight: Radius.circular(DS.radiusLg),
        ),
      ),
      child: Column(
        children: [
          Text('SCAN AT GATE', style: DS.labelText()),
          const SizedBox(height: DS.space16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: DS.surfaceWhite,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: barcodeData,
                        drawText: false,
                        height: 60,
                      ),
                    ),
                    const SizedBox(height: DS.space8),
                    Text(
                      barcodeData,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: DS.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DS.space4),
                    Text(
                      'Scan at boarding gate',
                      style: DS.finePrint(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DS.space16),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DS.surfaceWhite,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 120,
                      backgroundColor: DS.surfaceWhite,
                      eyeStyle: const QrEyeStyle(
                        color: DS.brandNavy,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        color: DS.brandNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.space8),
                  Text(
                    'QUICK SCAN',
                    style: DS.finePrint(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DS.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 12, color: DS.brandBlue),
              const SizedBox(width: DS.space4),
              Text(
                'Travello AI  •  Verified & Secure Ticket',
                style: DS.finePrint(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 4: TRAVEL GUIDELINES
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildTravelGuidelines() {
    final tips = [
      (Icons.schedule_rounded, 'Arrive at least 2 hours before departure'),
      (Icons.badge_rounded, 'Carry valid CNIC/Passport and this e-ticket'),
      (
        Icons.door_front_door_rounded,
        'Check-in closes 45 minutes before departure'
      ),
      (Icons.luggage_rounded, 'Baggage allowance: 20 kg checked + 7 kg cabin'),
      (
        Icons.wifi_protected_setup_rounded,
        'Web check-in opens 24 hours before departure'
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: DS.surfaceWhite,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.borderLight),
        boxShadow: DS.shadowMd,
      ),
      padding: const EdgeInsets.all(DS.sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DS.space8),
                decoration: BoxDecoration(
                  color: DS.warningLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: DS.warningPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: DS.space12),
              Text('Travel Guidelines', style: DS.sectionTitle()),
            ],
          ),
          const SizedBox(height: DS.space16),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: DS.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DS.brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(tip.$1, size: 14, color: DS.brandBlue),
                    ),
                    const SizedBox(width: DS.space12),
                    Expanded(
                      child: Text(tip.$2, style: DS.bodyText()),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 5: FOOTER
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'This is an official e-ticket issued by Travello AI.\nPresent this at check-in counter.',
          textAlign: TextAlign.center,
          style: DS.bodyText(),
        ),
        const SizedBox(height: DS.space12),
        const Divider(color: DS.borderLight, height: 1),
        const SizedBox(height: DS.space12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent_rounded,
                size: 14, color: DS.textTertiary),
            const SizedBox(width: DS.space8),
            Text(
              'support@travello.pk  •  +92 300 1234567',
              style: DS.captionText(),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PDF GENERATION
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _downloadPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final doc = pw.Document();
      final pdfFontRegular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Regular.ttf'));
      final pdfFontBold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Bold.ttf'));
      final pdfTheme = pw.ThemeData.withFont(
        base: pdfFontRegular,
        bold: pdfFontBold,
      );
      final paxList = _allPassengers;

      // Generate PDF for outbound flights
      for (final pax in paxList) {
        _addPdfPage(
          doc,
          theme: pdfTheme,
          isReturn: false,
          passengerName: pax['name'] as String? ?? '',
          passportOrId: pax['passportOrId'] as String? ?? '',
        );
      }

      // Generate PDF for return flights if round trip
      if (_isRoundTrip) {
        for (final pax in paxList) {
          _addPdfPage(
            doc,
            theme: pdfTheme,
            isReturn: true,
            passengerName: pax['name'] as String? ?? '',
            passportOrId: pax['passportOrId'] as String? ?? '',
          );
        }
      }

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generation failed'),
            backgroundColor: DS.errorPrimary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  void _addPdfPage(
    pw.Document doc, {
    required pw.ThemeData theme,
    required bool isReturn,
    required String passengerName,
    required String passportOrId,
  }) {
    // PDF Colors matching airline design
    const pdfNavy = PdfColor(0.039, 0.086, 0.157); // #0A1628
    const pdfBlue = PdfColor(0.145, 0.388, 0.922); // #2563EB
    const pdfGreen = PdfColor(0.063, 0.725, 0.506); // #10B981
    const pdfBlueBg = PdfColor(0.859, 0.918, 0.996); // #DBEAFE
    const pdfTextPrimary = PdfColor(0.059, 0.090, 0.165); // #0F172A
    const pdfTextSecondary = PdfColor(0.278, 0.337, 0.412); // #475569
    const pdfTextTertiary = PdfColor(0.580, 0.639, 0.722); // #94A3B8
    const pdfBorder = PdfColor(0.886, 0.910, 0.941); // #E2E8F0
    const pdfSurfaceLight = PdfColor(0.973, 0.980, 0.988); // #F8FAFC

    // Extract flight data
    final fromCode = _extractCode(_from(isReturn));
    final toCode = _extractCode(_to(isReturn));
    final airline = _airline(isReturn);
    final flightNum = _flightNum(isReturn);
    final cabin = _cabin(isReturn);
    final dep = _dep(isReturn);
    final arr = _arr(isReturn);
    final dur = _duration(isReturn);
    final date = _date(isReturn);
    final seat = _flightData(isReturn, 'seat') ?? 'A1';

    // Barcode data
    final leg = isReturn ? 'R' : 'O';
    final route = '$fromCode$toCode';
    final barcodeData = '$_pnr$leg$route$flightNum$seat'.toUpperCase();
    final qrData =
        'TRAVELLO|PNR:$_pnr|PAX:$passengerName|FLT:$flightNum|ROUTE:$fromCode-$toCode|SEAT:$seat|LEG:$leg';
    final flightLabel = isReturn ? 'RETURN FLIGHT' : 'OUTBOUND FLIGHT';

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.SizedBox(
            width: math.max(460.0, MediaQuery.of(context).size.width),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Label Bar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: isReturn ? pdfGreen : pdfNavy,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(20)),
                          ),
                          child: pw.Text(
                            flightLabel,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'PNR: $_formattedPnr',
                          style: const pw.TextStyle(
                            color: pdfTextTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Travello AI  -  E-Ticket',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfTextSecondary,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // Main Ticket Card
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(16)),
                    border: pw.Border.all(color: pdfBorder),
                  ),
                  child: pw.Column(
                    children: [
                      // Header with navy gradient - matches on-screen design
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        decoration: const pw.BoxDecoration(
                          gradient: pw.LinearGradient(
                            begin: pw.Alignment.topLeft,
                            end: pw.Alignment.bottomRight,
                            colors: [
                              PdfColor(0.039, 0.086, 0.157),
                              PdfColor(0.118, 0.227, 0.439)
                            ],
                          ),
                          borderRadius: pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(16),
                            topRight: pw.Radius.circular(16),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            // Icon box (matches on-screen)
                            pw.Container(
                              width: 56,
                              height: 56,
                              decoration: pw.BoxDecoration(
                                color: const PdfColor(1.0, 1.0, 1.0, 0.12),
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(12)),
                                border: pw.Border.all(
                                  color: const PdfColor(1.0, 1.0, 1.0, 0.2),
                                  width: 1,
                                ),
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  '>>',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 16),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    airline,
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColor(1.0, 1.0, 1.0, 0.15),
                                      borderRadius: pw.BorderRadius.all(
                                          pw.Radius.circular(4)),
                                    ),
                                    child: pw.Text(
                                      flightNum,
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor(
                                        0.063, 0.725, 0.506, 0.2),
                                    borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(20)),
                                    border: pw.Border.all(
                                      color: const PdfColor(
                                          0.063, 0.725, 0.506, 0.5),
                                    ),
                                  ),
                                  child: pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      pw.Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const pw.BoxDecoration(
                                          color: pdfGreen,
                                          shape: pw.BoxShape.circle,
                                        ),
                                      ),
                                      pw.SizedBox(width: 4),
                                      pw.Text(
                                        'CONFIRMED',
                                        style: pw.TextStyle(
                                          color: pdfGreen,
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor(1.0, 1.0, 1.0, 0.12),
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(6)),
                                  ),
                                  child: pw.Text(
                                    cabin,
                                    style: const pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Route Section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(32),
                        child: pw.Column(
                          children: [
                            // Airport codes with connector
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  fromCode,
                                  style: pw.TextStyle(
                                    fontSize: 42,
                                    fontWeight: pw.FontWeight.bold,
                                    color: pdfTextPrimary,
                                    letterSpacing: 2,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const pw.BoxDecoration(
                                            color: pdfBlue,
                                            shape: pw.BoxShape.circle,
                                          ),
                                        ),
                                        pw.Expanded(
                                          child: pw.Container(
                                            height: 2,
                                            color: const PdfColor(
                                                0.145, 0.388, 0.922, 0.3),
                                          ),
                                        ),
                                        pw.Padding(
                                          padding:
                                              const pw.EdgeInsets.symmetric(
                                                  horizontal: 8),
                                          child: pw.Text(
                                            '>>',
                                            style: pw.TextStyle(
                                              color: pdfBlue,
                                              fontSize: 12,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        pw.Expanded(
                                          child: pw.Container(
                                            height: 2,
                                            color: const PdfColor(
                                                0.145, 0.388, 0.922, 0.3),
                                          ),
                                        ),
                                        pw.Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const pw.BoxDecoration(
                                            color: pdfBlue,
                                            shape: pw.BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  toCode,
                                  style: pw.TextStyle(
                                    fontSize: 42,
                                    fontWeight: pw.FontWeight.bold,
                                    color: pdfTextPrimary,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),

                            pw.SizedBox(height: 16),

                            // Duration and NON-STOP
                            pw.Column(
                              children: [
                                pw.Text(
                                  dur,
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: pdfTextTertiary,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: const pw.BoxDecoration(
                                    color: pdfBlueBg,
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text(
                                    'NON-STOP',
                                    style: pw.TextStyle(
                                      color: pdfBlue,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            pw.SizedBox(height: 16),

                            // Times
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      dep,
                                      style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold,
                                        color: pdfTextPrimary,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      date,
                                      style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      arr,
                                      style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold,
                                        color: pdfTextPrimary,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      date,
                                      style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Flight Details Grid
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: pdfSurfaceLight,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: pdfBorder),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            _buildPdfDetailChip(
                                'SEAT', seat, pdfTextTertiary, pdfTextPrimary),
                            pw.Container(
                                width: 1, height: 40, color: pdfBorder),
                            _buildPdfDetailChip(
                                'GATE', 'H22', pdfTextTertiary, pdfTextPrimary),
                            pw.Container(
                                width: 1, height: 40, color: pdfBorder),
                            _buildPdfDetailChip('TERMINAL', '3',
                                pdfTextTertiary, pdfTextPrimary),
                            pw.Container(
                                width: 1, height: 40, color: pdfBorder),
                            _buildPdfDetailChip(
                                'BOARDS', dep, pdfTextTertiary, pdfTextPrimary),
                          ],
                        ),
                      ),

                      // Tear-line
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 18,
                              height: 32,
                              decoration: pw.BoxDecoration(
                                color: pdfSurfaceLight,
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(color: pdfBorder),
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                children: [
                                  pw.Container(
                                      height: 1,
                                      color: const PdfColor(
                                          0.886, 0.910, 0.941, 0.7)),
                                  pw.SizedBox(height: 12),
                                  pw.Container(height: 1, color: pdfBorder),
                                ],
                              ),
                            ),
                            pw.Container(
                              width: 18,
                              height: 32,
                              decoration: pw.BoxDecoration(
                                color: pdfSurfaceLight,
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(color: pdfBorder),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Passenger Section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor(0.145, 0.388, 0.922, 0.1),
                                    shape: pw.BoxShape.circle,
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'P',
                                      style: pw.TextStyle(
                                        fontSize: 20,
                                        fontWeight: pw.FontWeight.bold,
                                        color:
                                            const PdfColor(0.145, 0.388, 0.922),
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 16),
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        'PASSENGER',
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: pdfTextTertiary,
                                          fontWeight: pw.FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      pw.SizedBox(height: 4),
                                      pw.Text(
                                        passengerName,
                                        style: pw.TextStyle(
                                          fontSize: 14,
                                          fontWeight: pw.FontWeight.bold,
                                          color: pdfTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (passportOrId.isNotEmpty)
                                  pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text(
                                        'PASSPORT / ID',
                                        style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: pdfTextTertiary,
                                        ),
                                      ),
                                      pw.SizedBox(height: 4),
                                      pw.Text(
                                        passportOrId,
                                        style: pw.TextStyle(
                                          fontSize: 12,
                                          fontWeight: pw.FontWeight.bold,
                                          color: pdfTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            pw.SizedBox(height: 20),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceAround,
                              children: [
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'THIS TICKET',
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      '1 Passenger',
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                        color: pdfTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'PAID VIA',
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      'card',
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                        color: pdfTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      'DATE',
                                      style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      date,
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                        color: pdfTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Scan Section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        decoration: const pw.BoxDecoration(
                          color: pdfSurfaceLight,
                          borderRadius: pw.BorderRadius.only(
                            bottomLeft: pw.Radius.circular(16),
                            bottomRight: pw.Radius.circular(16),
                          ),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'SCAN AT GATE',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: pdfTextTertiary,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            pw.SizedBox(height: 16),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Column(
                                    children: [
                                      pw.Container(
                                        height: 60,
                                        padding: const pw.EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: const pw.BoxDecoration(
                                          color: PdfColors.white,
                                          borderRadius: pw.BorderRadius.all(
                                              pw.Radius.circular(8)),
                                        ),
                                        child: pw.BarcodeWidget(
                                          barcode: pw.Barcode.code128(),
                                          data: barcodeData,
                                          drawText: false,
                                          height: 60,
                                        ),
                                      ),
                                      pw.SizedBox(height: 8),
                                      pw.Text(
                                        barcodeData,
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: pdfTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 20),
                                pw.Column(
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.all(8),
                                      decoration: const pw.BoxDecoration(
                                        color: PdfColors.white,
                                        borderRadius: pw.BorderRadius.all(
                                            pw.Radius.circular(8)),
                                      ),
                                      child: pw.BarcodeWidget(
                                        barcode: pw.Barcode.qrCode(),
                                        data: qrData,
                                        width: 80,
                                        height: 80,
                                      ),
                                    ),
                                    pw.SizedBox(height: 8),
                                    pw.Text(
                                      'QUICK SCAN',
                                      style: const pw.TextStyle(
                                        fontSize: 7,
                                        color: pdfTextTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 16),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const pw.BoxDecoration(
                                    color: pdfNavy,
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(4)),
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'T',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Text(
                                  'Travello AI  -  Verified & Secure Ticket',
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: pdfTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Travel Guidelines
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(12)),
                    border: pw.Border.all(color: pdfBorder),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Travel Guidelines',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfTextPrimary,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      ...[
                        'Arrive at least 2 hours before departure',
                        'Carry valid CNIC/Passport and this e-ticket',
                        'Check-in closes 45 minutes before departure',
                        'Baggage allowance: 20kg checked + 7kg cabin',
                        'Web check-in opens 24 hours before departure',
                      ].map((tip) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 5),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  width: 4,
                                  height: 4,
                                  margin: const pw.EdgeInsets.only(
                                      top: 4, right: 8),
                                  decoration: const pw.BoxDecoration(
                                    color: pdfBlue,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    tip,
                                    style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: pdfTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
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

  pw.Widget _buildPdfDetailChip(
      String label, String value, PdfColor labelColor, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: labelColor,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: Perforated Tear-Line
// ══════════════════════════════════════════════════════════════════════════

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = DS.borderLight
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
