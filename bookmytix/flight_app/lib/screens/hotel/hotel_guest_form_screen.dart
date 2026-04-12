import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/hotel.dart';
import 'package:flight_app/models/room_type.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HotelGuestFormScreen extends StatefulWidget {
  const HotelGuestFormScreen({super.key});

  @override
  State<HotelGuestFormScreen> createState() => _HotelGuestFormScreenState();
}

class _HotelGuestFormScreenState extends State<HotelGuestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late Hotel hotel;
  RoomType? roomType;
  late DateTime checkInDate;
  late DateTime checkOutDate;
  late int rooms;
  late int guests;
  late double totalPrice;

  // Primary guest
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _gender = 'Male';
  bool _cnicVerified = false;
  bool _saveGuestDetails = false;

  // Extra guests (guests 2, 3, … N): one name + one doc controller per guest
  List<TextEditingController> _extraNameCtrls = [];
  List<TextEditingController> _extraDocCtrls = [];

  // Extras
  bool _addBreakfast = false;
  bool _addAirportTransfer = false;
  bool _addLateCheckout = false;

  static const double _breakfastCost = 1400;
  static const double _airportTransferCost = 2500;
  static const double _lateCheckoutCost = 800;

  @override
  void initState() {
    super.initState();
    // BUG 9 FIX: null-safe argument reading with sensible fallbacks
    final args = Get.arguments as Map? ?? {};
    final hotelArg = args['hotel'];
    if (hotelArg == null || hotelArg is! Hotel) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      return;
    }
    hotel = hotelArg;
    roomType = args['roomType'] as RoomType?;
    checkInDate = (args['checkInDate'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 1));
    checkOutDate = (args['checkOutDate'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 2));
    rooms = (args['rooms'] as int?) ?? 1;
    guests = (args['guests'] as int?) ?? 1;
    totalPrice = ((args['totalPrice'] as num?) ?? 0).toDouble();
    final extraCount = (guests - 1).clamp(0, 9);
    _extraNameCtrls = List.generate(extraCount, (_) => TextEditingController());
    _extraDocCtrls = List.generate(extraCount, (_) => TextEditingController());
    _addListeners();
    _loadGuestData();
  }

  Future<void> _loadGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('saved_hotel_guest_data');
      if (saved == null || saved.isEmpty) return;
      final data = jsonDecode(saved) as Map<String, dynamic>;
      final savedExtras = data['extraGuests'] as List? ?? [];
      setState(() {
        _firstNameCtrl.text = data['firstName'] ?? '';
        _lastNameCtrl.text = data['lastName'] ?? '';
        _cnicCtrl.text = data['cnic'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        _gender = data['gender'] ?? 'Male';
        _saveGuestDetails = true;
        // Restore extra guest data up to the number of extra guests slots
        for (int i = 0;
            i < _extraNameCtrls.length && i < savedExtras.length;
            i++) {
          final e = savedExtras[i] as Map? ?? {};
          _extraNameCtrls[i].text = e['name'] as String? ?? '';
          _extraDocCtrls[i].text = e['doc'] as String? ?? '';
        }
      });
    } catch (_) {}
  }

  Future<void> _saveGuestData() async {
    if (!_saveGuestDetails) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'saved_hotel_guest_data',
          jsonEncode({
            'firstName': _firstNameCtrl.text.trim(),
            'lastName': _lastNameCtrl.text.trim(),
            'cnic': _cnicCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'gender': _gender,
            'extraGuests': [
              for (int i = 0; i < _extraNameCtrls.length; i++)
                {
                  'name': _extraNameCtrls[i].text.trim(),
                  'doc': _extraDocCtrls[i].text.trim()
                },
            ],
          }));
    } catch (_) {}
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cnicCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    for (final c in _extraNameCtrls) {
      c.dispose();
    }
    for (final c in _extraDocCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  int get numberOfNights => checkOutDate.difference(checkInDate).inDays;

  /// Pakistan airport name by hotel city.
  String get _airportName {
    switch (hotel.city) {
      case 'Karachi':
        return 'Jinnah International Airport';
      case 'Lahore':
        return 'Allama Iqbal International Airport';
      case 'Islamabad':
      case 'Rawalpindi':
        return 'New Islamabad International Airport';
      case 'Peshawar':
        return 'Bacha Khan International Airport';
      case 'Quetta':
        return 'Quetta International Airport';
      case 'Multan':
        return 'Multan International Airport';
      case 'Faisalabad':
        return 'Faisalabad International Airport';
      case 'Sialkot':
        return 'Sialkot International Airport';
      case 'Skardu':
        return 'Skardu Airport';
      default:
        return '${hotel.city} Airport';
    }
  }

  double get extrasTotal {
    double e = 0;
    // BUG 11 FIX: multiply breakfast by rooms count, not just nights
    if (_addBreakfast) e += _breakfastCost * numberOfNights * rooms;
    if (_addAirportTransfer) e += _airportTransferCost * rooms;
    if (_addLateCheckout) e += _lateCheckoutCost * rooms;
    return e;
  }

  double get finalTotal => totalPrice + extrasTotal;

  /// Reactively tracked — add listeners in initState for this to update button.
  // NEW:
  bool get _isFormValid {
    if (_firstNameCtrl.text.trim().isEmpty) return false;
    if (_lastNameCtrl.text.trim().isEmpty) return false;
    final cnicDigits = _cnicCtrl.text.replaceAll('-', '');
    if (cnicDigits.length != 13) return false;
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) return false;
    if (phone.startsWith('0')) return false;
    if (!phone.startsWith('3') && !phone.startsWith('2')) return false;
    for (int i = 0; i < _extraNameCtrls.length; i++) {
      if (_extraNameCtrls[i].text.trim().isEmpty) return false;
      final doc = _extraDocCtrls[i].text.replaceAll('-', '');
      if (doc.length != 13) return false;
    }
    // Issue 1 fix: block if ANY duplicate exists
    if (_hasDuplicateNames()) return false;
    if (_hasDuplicateCnics()) return false;
    return true;
  }

  void _addListeners() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _cnicCtrl,
      _phoneCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
    for (final c in [..._extraNameCtrls, ..._extraDocCtrls]) {
      c.addListener(() => setState(() {}));
    }
  }

  bool _hasDuplicateNames() {
    final names = <String>[];
    final primary = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'
        .trim()
        .toLowerCase();
    if (primary.isNotEmpty) names.add(primary);
    for (final c in _extraNameCtrls) {
      final n = c.text.trim().toLowerCase();
      if (n.isEmpty) continue;
      if (names.contains(n)) return true;
      names.add(n);
    }
    return false;
  }

  bool _hasDuplicateCnics() {
    final cnics = <String>[];
    final primary = _cnicCtrl.text.replaceAll('-', '');
    if (primary.isNotEmpty) cnics.add(primary);
    for (final c in _extraDocCtrls) {
      final d = c.text.replaceAll('-', '');
      if (d.isEmpty) continue;
      if (cnics.contains(d)) return true;
      cnics.add(d);
    }
    return false;
  }

  Future<void> _proceedToPayment() async {
    // Issue 2 fix: show explicit duplicate errors before form validation
    if (_hasDuplicateNames()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guest names must be different'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (_hasDuplicateCnics()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CNIC numbers must be different'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating));
      return;
    }

    final extrasIncluded = <String>[];
    if (_addBreakfast) extrasIncluded.add('Breakfast for $guests');
    if (_addAirportTransfer) extrasIncluded.add('Airport transfer ×$rooms');
    if (_addLateCheckout) extrasIncluded.add('Late check-out ×$rooms');

    // Build unified guestsData list
    final guestsData = <Map<String, dynamic>>[
      {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'cnic': _cnicCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gender': _gender,
        'type': 'primary',
      },
      for (int i = 0; i < _extraNameCtrls.length; i++)
        if (_extraNameCtrls[i].text.trim().isNotEmpty)
          {
            'firstName': _extraNameCtrls[i].text.trim().split(' ').first,
            'lastName': _extraNameCtrls[i].text.trim().contains(' ')
                ? _extraNameCtrls[i].text.trim().split(' ').skip(1).join(' ')
                : '',
            'fullName': _extraNameCtrls[i].text.trim(),
            'cnic': _extraDocCtrls[i].text.trim(),
            'type': 'guest',
            'guestNumber': i + 2,
          },
    ];

    await _saveGuestData();

    Get.toNamed('/hotel-checkout', arguments: {
      'hotel': hotel,
      'roomType': roomType,
      'checkInDate': checkInDate,
      'checkOutDate': checkOutDate,
      'rooms': rooms,
      'guests': guests,
      'guestsData': guestsData,
      'nights': numberOfNights,
      'totalPrice': finalTotal,
      'basePrice': totalPrice,
      'extrasTotal': extrasTotal,
      'extrasIncluded': extrasIncluded,
      'breakfastAdded': _addBreakfast,
      'airportTransferAdded': _addAirportTransfer,
      'lateCheckoutAdded': _addLateCheckout,
      'bookingType': 'hotel',
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: TravelloTheme.primaryMain,
        foregroundColor: Colors.white,
        title: const Text('Guest Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          // ── Progress steps ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                _Step(num: 1, label: 'Hotel', done: true),
                _StepLine(done: true),
                _Step(num: 2, label: 'Rooms', done: true),
                _StepLine(done: true),
                _Step(num: 3, label: 'Guests', done: false, active: true),
                _StepLine(done: false),
                _Step(num: 4, label: 'Checkout', done: false),
                _StepLine(done: false),
                _Step(num: 5, label: 'Payment', done: false),
                _StepLine(done: false),
                _Step(num: 6, label: 'Done', done: false),
              ],
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Booking summary strip ──────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(spacingUnit(1.75)),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  roomType != null
                                      ? roomType!.name
                                      : hotel.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                                'PKR ${fmt.format((roomType?.pricePerNight ?? hotel.pricePerNight).round())}/night',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: TravelloTheme.primaryMain,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 13, color: TravelloTheme.primaryMain),
                            const SizedBox(width: 3),
                            Expanded(
                                child: Text(hotel.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        if (roomType?.isRefundable == true ||
                            hotel.isRefundable) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 13, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 3),
                              Text(
                                'Free cancellation until ${DateFormat('d MMM').format(checkInDate.subtract(const Duration(days: 1)))}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Contact Details header ─────────────────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacingUnit(1.75),
                        vertical: spacingUnit(1.25)),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.18)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.contact_page_outlined,
                            color: TravelloTheme.primaryMain, size: 20),
                        SizedBox(width: 10),
                        Text('Contact Details',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: TravelloTheme.primaryMain)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Primary Guest ──────────────────────────────────────────
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Primary Guest',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  _field(_firstNameCtrl, 'First Name *',
                                      Icons.person_outline,
                                      required: true),
                                  const SizedBox(height: 12),
                                  _field(_lastNameCtrl, 'Last Name *',
                                      Icons.person_outline,
                                      required: true),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                    child: _field(_firstNameCtrl,
                                        'First Name *', Icons.person_outline,
                                        required: true)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _field(_lastNameCtrl, 'Last Name *',
                                        Icons.person_outline,
                                        required: true)),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // CNIC
                        TextFormField(
                          controller: _cnicCtrl,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [_CnicFormatter()],
                          decoration: InputDecoration(
                            labelText: 'CNIC Number *',
                            hintText: 'XXXXX-XXXXXXX-X',
                            prefixIcon: const Icon(Icons.credit_card),
                            suffixIcon: _cnicVerified
                                ? const Icon(Icons.verified,
                                    color: Colors.green)
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: TravelloTheme.primaryMain)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'CNIC is required';
                            }
                            final raw = v.replaceAll('-', '');
                            if (raw.length != 13) {
                              return 'Enter valid 13-digit CNIC';
                            }
                            return null;
                          },
                          onChanged: (v) {
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            setState(() => _cnicVerified = digits.length == 13);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Phone + Gender
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _phoneCtrl,
                                    style: const TextStyle(color: Colors.black),
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    buildCounter: (_,
                                            {required currentLength,
                                            required isFocused,
                                            maxLength}) =>
                                        null,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                      _NoLeadingZeroFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Mobile *',
                                      hintText: '3001234567',
                                      prefixIcon: const Icon(Icons.phone),
                                      prefixText: '+92 ',
                                      prefixStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: TravelloTheme.primaryMain,
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color:
                                                  TravelloTheme.primaryMain)),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone required';
                                      }
                                      final digits =
                                          v.replaceAll(RegExp(r'[^0-9]'), '');
                                      if (digits.startsWith('0')) {
                                        return 'Do not include leading 0 with +92';
                                      }
                                      if (digits.length != 10) {
                                        return 'Enter 10-digit mobile number';
                                      }
                                      if (!digits.startsWith('3') &&
                                          !digits.startsWith('2')) {
                                        return 'Invalid Pakistan phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      prefixIcon: const Icon(Icons.wc),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color:
                                                  TravelloTheme.primaryMain)),
                                    ),
                                    items: ['Male', 'Female']
                                        .map((g) => DropdownMenuItem(
                                            value: g, child: Text(g)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _gender = v ?? 'Male'),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    style: const TextStyle(color: Colors.black),
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    buildCounter: (_,
                                            {required currentLength,
                                            required isFocused,
                                            maxLength}) =>
                                        null,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                      _NoLeadingZeroFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Mobile *',
                                      hintText: '3001234567',
                                      prefixIcon: const Icon(Icons.phone),
                                      prefixText: '+92 ',
                                      prefixStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: TravelloTheme.primaryMain,
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color:
                                                  TravelloTheme.primaryMain)),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Phone required';
                                      }
                                      final digits =
                                          v.replaceAll(RegExp(r'[^0-9]'), '');
                                      if (digits.startsWith('0')) {
                                        return 'Do not include leading 0 with +92';
                                      }
                                      if (digits.length != 10) {
                                        return 'Enter 10-digit mobile number';
                                      }
                                      if (!digits.startsWith('3') &&
                                          !digits.startsWith('2')) {
                                        return 'Invalid Pakistan phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      prefixIcon: const Icon(Icons.wc),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color:
                                                  TravelloTheme.primaryMain)),
                                    ),
                                    items: ['Male', 'Female']
                                        .map((g) => DropdownMenuItem(
                                            value: g, child: Text(g)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _gender = v ?? 'Male'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email (required — booking confirmation sent here)
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Email Address *',
                            hintText: 'Booking confirmation will be sent here',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: TravelloTheme.primaryMain)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required for booking confirmation';
                            }
                            if (!GetUtils.isEmail(v.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Save Details Checkbox ──────────────────────────────────
                  InkWell(
                    onTap: () =>
                        setState(() => _saveGuestDetails = !_saveGuestDetails),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _saveGuestDetails,
                            onChanged: (v) =>
                                setState(() => _saveGuestDetails = v ?? false),
                            activeColor: TravelloTheme.primaryMain,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Save guest details for next time',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text('Auto-fills this form on your next booking',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── NADRA Banner ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFFFCC00).withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag,
                                size: 16, color: Color(0xFF856404)),
                            SizedBox(width: 6),
                            Expanded(
                                child: Text('NADRA CNIC Required',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF856404)))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'All adult guests must show valid CNIC at check-in. Married couples require original Nikah Nama per Pakistan hotel policy.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.brown.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Additional Guests (dynamic loop for guests 2…N) ─────────
                  for (int i = 0; i < _extraNameCtrls.length; i++) ...[
                    Text(
                      'Guest ${i + 2}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _field(_extraNameCtrls[i], 'Full Name *',
                              Icons.person_outline,
                              required: true,
                              extraValidator: (_) {
                                if (_hasDuplicateNames()) {
                                  return 'Guest names must be different';
                                }
                                return null;
                              }),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _extraDocCtrls[i],
                            style: const TextStyle(color: Colors.black),
                            keyboardType: TextInputType.number,
                            inputFormatters: [_CnicFormatter()],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'CNIC / B-Form is required';
                              }
                              final raw = v.replaceAll('-', '');
                              if (raw.length != 13 ||
                                  !RegExp(r'^\d+$').hasMatch(raw)) {
                                return 'Enter a valid 13-digit CNIC / B-Form';
                              }
                              // Duplicate check against primary guest
                              if (raw == _cnicCtrl.text.replaceAll('-', '')) {
                                return 'CNIC numbers must be different';
                              }
                              // Duplicate check against other extra guests
                              for (int j = 0; j < _extraDocCtrls.length; j++) {
                                if (j == i) continue; // skip self
                                final other =
                                    _extraDocCtrls[j].text.replaceAll('-', '');
                                if (other.isNotEmpty && other == raw) {
                                  return 'CNIC numbers must be different';
                                }
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'CNIC / B-Form',
                              hintText: 'XXXXX-XXXXXXX-X',
                              prefixIcon: const Icon(Icons.credit_card),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: TravelloTheme.primaryMain)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Add Extras ─────────────────────────────────────────────
                  const Text('Add extras',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (roomType?.breakfastIncluded == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Breakfast already included in your room',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _ExtraCard(
                      icon: Icons.free_breakfast,
                      title: 'Breakfast for $guests',
                      subtitle:
                          'Served 7–10 AM · PKR ${fmt.format(_breakfastCost.round())}/night ×$numberOfNights nights${rooms > 1 ? " ×$rooms rooms" : ""}',
                      price:
                          '+PKR ${fmt.format((_breakfastCost * numberOfNights * rooms).round())}',
                      selected: _addBreakfast,
                      onToggle: () =>
                          setState(() => _addBreakfast = !_addBreakfast),
                    ),
                  const SizedBox(height: 8),
                  _ExtraCard(
                    icon: Icons.airport_shuttle,
                    title: 'Airport transfer',
                    subtitle: _airportName,
                    price:
                        '+PKR ${fmt.format((_airportTransferCost * rooms).round())}',
                    selected: _addAirportTransfer,
                    onToggle: () => setState(
                        () => _addAirportTransfer = !_addAirportTransfer),
                  ),
                  const SizedBox(height: 8),
                  _ExtraCard(
                    icon: Icons.schedule,
                    title: 'Late check-out',
                    subtitle:
                        'Until 3:00 PM${rooms > 1 ? " ×$rooms rooms" : ""}',
                    price:
                        '+PKR ${fmt.format((_lateCheckoutCost * rooms).round())}',
                    selected: _addLateCheckout,
                    onToggle: () =>
                        setState(() => _addLateCheckout = !_addLateCheckout),
                  ),
                  const SizedBox(height: 16),

                  // ── House Rules ─────────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(spacingUnit(1.75)),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.house,
                                color: Colors.amber.shade800, size: 18),
                            const SizedBox(width: 6),
                            const Text('House rules',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...[
                          'Check-in: 2:00 PM · Check-out: 12:00 PM',
                          'No smoking on premises',
                          'Married couples must carry Nikah Nama',
                          'Valid CNIC/Passport required at reception',
                        ].map((rule) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                      child: Text(rule,
                                          style:
                                              const TextStyle(fontSize: 12))),
                                ],
                              ),
                            )),
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

      // ── Bottom Bar ─────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Extras summary
              if (extrasTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline,
                          size: 14, color: TravelloTheme.primaryMain),
                      const SizedBox(width: 4),
                      Text(
                          'Extras: PKR ${NumberFormat('#,##0').format(extrasTotal.round())}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: TravelloTheme.primaryMain,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total amount',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                            'PKR ${NumberFormat('#,##0').format(finalTotal.round())}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: TravelloTheme.primaryMain)),
                        Text(
                            '$guests ${guests == 1 ? 'guest' : 'guests'} · $numberOfNights nights',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DSButton(
                    label: 'Continue to Checkout',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onTap: _proceedToPayment,
                    disabled: !_isFormValid,
                    width: 200,
                    height: 52,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, String? Function(String?)? extraValidator}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.black),
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TravelloTheme.primaryMain)),
      ),
      validator: (v) {
        if (required) {
          if (v == null || v.trim().isEmpty) return 'Required';
          final nameRegex = RegExp(r"^[a-zA-Z .'-]+$");
          if (!nameRegex.hasMatch(v.trim())) return 'Letters only';
          if (v.trim().length < 2) return 'Too short';
        }
        return extraValidator?.call(v);
      },
    );
  }
}

// ── Progress Step ──────────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final int num;
  final String label;
  final bool done;
  final bool active;
  const _Step(
      {required this.num,
      required this.label,
      required this.done,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    const gold = TravelloTheme.primaryMain;
    return Column(
      children: [
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
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: done ? TravelloTheme.primaryMain : const Color(0xFFE0E0E0),
      ),
    );
  }
}

// ── Extra Card ─────────────────────────────────────────────────────────────────

class _ExtraCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback onToggle;

  const _ExtraCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.price,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(spacingUnit(1.75)),
        decoration: BoxDecoration(
          color: selected
              ? TravelloTheme.primaryMain.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  selected ? TravelloTheme.primaryMain : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? TravelloTheme.primaryMain.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected
                      ? TravelloTheme.primaryMain
                      : Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Text(price,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: TravelloTheme.primaryMain)),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? TravelloTheme.primaryMain : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: selected
                        ? TravelloTheme.primaryMain
                        : Colors.grey.shade400,
                    width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── CNIC Text Input Formatter ──────────────────────────────────────────────────

class _CnicFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue val) {
    final digits = val.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 13; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
        text: str, selection: TextSelection.collapsed(offset: str.length));
  }
}

// ── Prevent leading zero in phone number (international format) ────────────

class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // If user tries to type 0 as first character, reject it
    if (newValue.text.startsWith('0')) {
      return oldValue;
    }
    return newValue;
  }
}
