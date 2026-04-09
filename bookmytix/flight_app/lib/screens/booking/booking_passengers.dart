import 'dart:math' as math;
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/widgets/app_input/ds_input_field.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flight_app/utils/design_system_formatters.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flight_app/ui/themes/theme_system.dart';

// â”€â”€â”€ nationality list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const List<String> _kCountries = [
  'Pakistan',
  'Afghanistan',
  'Australia',
  'Bahrain',
  'Bangladesh',
  'Canada',
  'China',
  'Egypt',
  'France',
  'Germany',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Italy',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kuwait',
  'Malaysia',
  'Morocco',
  'Netherlands',
  'Nigeria',
  'Oman',
  'Qatar',
  'Russia',
  'Saudi Arabia',
  'Singapore',
  'South Africa',
  'South Korea',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Sweden',
  'Switzerland',
  'Thailand',
  'Turkey',
  'UAE',
  'UK',
  'USA',
  'Uzbekistan',
  'Yemen',
];

class BookingPassengers extends StatefulWidget {
  const BookingPassengers({super.key});

  @override
  State<BookingPassengers> createState() => _BookingPassengersState();
}

class _BookingPassengersState extends State<BookingPassengers> {
  late List<GlobalKey<FormState>> _formKeys;
  final _pageController = PageController();
  final _scrollController = ScrollController();

  late FlightResult _flight;
  late Airport _fromAirport;
  late Airport _toAirport;
  late DateTime _departureDate;
  late int _totalPassengers;
  late int _adults;
  late int _children;
  late int _infants;
  Map<String, dynamic> _searchParams = {};

  // Round trip support
  bool _isRoundTrip = false;
  FlightResult? _outboundFlight;
  FlightResult? _returnFlight;
  DateTime? _returnDate;

  // Contact
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // Emergency Contact
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyEmailCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyRelationCtrl = TextEditingController();

  // Page state: 0..(_totalPassengers-1) = passenger pages, last = contact page
  int _currentPage = 0;

  // Stepper
  final List<String> _steps = [
    'PASSENGERS',
    'FACILITIES',
    'CHECKOUT',
    'PAYMENT',
    'DONE'
  ];

  // Per-passenger field holders
  late List<_PassengerData> _passengers;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};

    // Round trip detection
    _isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    _outboundFlight = args['outboundFlight'] as FlightResult?;
    _returnFlight = args['returnFlight'] as FlightResult?;

    // Use outbound flight for round trip, or single flight
    _flight =
        (_isRoundTrip ? _outboundFlight : args['flight']) as FlightResult? ??
            FlightResult(
              id: '0',
              airlineName: 'Unknown Airline',
              airlineCode: 'N/A',
              airlineLogo: '',
              departureTime: '--:--',
              arrivalTime: '--:--',
              duration: '--',
              stops: 0,
              stopCities: [],
              price: 0,
              isRefundable: false,
              cabinClass: 'Economy',
            );
    _searchParams = args['searchParams'] as Map<String, dynamic>? ?? {};
    _fromAirport = _searchParams['fromAirport'] as Airport? ??
        Airport(id: '0', code: 'DEP', name: 'Departure', location: 'Departure');
    _toAirport = _searchParams['toAirport'] as Airport? ??
        Airport(id: '0', code: 'ARR', name: 'Arrival', location: 'Arrival');
    _departureDate =
        _searchParams['departureDate'] as DateTime? ?? DateTime.now();
    _returnDate = _searchParams['returnDate'] as DateTime?;
    _adults = (_searchParams['adults'] as int?) ?? 1;
    _children = (_searchParams['children'] as int?) ?? 0;
    _infants = (_searchParams['infants'] as int?) ?? 0;
    _totalPassengers = (_adults + _children + _infants).clamp(1, 99);

    // Initialize passengers with appropriate default document types
    _passengers = List.generate(_totalPassengers, (i) {
      final passengerData = _PassengerData();
      // Set default document type based on passenger category
      // Adults (i < _adults): CNIC default
      // Children/Infants (i >= _adults): B-Form default
      if (i >= _adults) {
        passengerData.documentType = 'B-Form';
      }
      return passengerData;
    });
    _formKeys =
        List.generate(_totalPassengers + 1, (_) => GlobalKey<FormState>());
    // Defer load until after first frame so setState calls are valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedPassengerData();
    });

    // Add listeners to trigger UI updates when contact fields change
    _contactNameCtrl.addListener(_onContactFieldChanged);
    _contactEmailCtrl.addListener(_onContactFieldChanged);
    _contactPhoneCtrl.addListener(_onContactFieldChanged);
    _emergencyNameCtrl.addListener(_onContactFieldChanged);
    _emergencyPhoneCtrl.addListener(_onContactFieldChanged);
    _emergencyRelationCtrl.addListener(_onContactFieldChanged);
  }

  // Callback to rebuild UI when contact fields change
  void _onContactFieldChanged() {
    if (_isContactPage) {
      setState(() {}); // Trigger rebuild to update button state
    }
  }

  // ── Save/Load Passenger Data ──────────────────────────────────────────────
  Future<void> _loadSavedPassengerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return; // widget disposed while awaiting
      for (int idx = 0; idx < _passengers.length; idx++) {
        final savedData = prefs.getString('saved_passenger_data_$idx');
        if (savedData == null || savedData.isEmpty) continue;
        final data = jsonDecode(savedData) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          final p = _passengers[idx];
          p.salutation = data['salutation'] ?? 'Mr';
          p.firstNameCtrl.text = data['firstName'] ?? '';
          p.lastNameCtrl.text = data['lastName'] ?? '';
          p.nationality = data['nationality'];
          p.documentType = data['documentType'] ?? 'CNIC';
          if (data['dateOfBirth'] != null) {
            p.dateOfBirth = DateTime.tryParse(data['dateOfBirth']);
          }
          p.nationalIdCtrl.text = data['nationalId'] ?? '';
          p.bFormCtrl.text = data['bForm'] ?? '';
          p.passportNumberCtrl.text = data['passportNumber'] ?? '';
          p.passportIssuingCountry = data['passportIssuingCountry'];
          if (data['passportIssuanceDate'] != null) {
            p.passportIssuanceDate =
                DateTime.tryParse(data['passportIssuanceDate']);
          }
          if (data['passportExpiryDate'] != null) {
            p.passportExpiryDate =
                DateTime.tryParse(data['passportExpiryDate']);
          }
          p.saveDetails = true; // restore checkbox state
        });
      }
      // Load saved contact info
      final contactRaw = prefs.getString('saved_contact_info_flight');
      if (contactRaw != null) {
        final c = jsonDecode(contactRaw) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _contactNameCtrl.text = c['contactName'] ?? '';
            _contactEmailCtrl.text = c['contactEmail'] ?? '';
            _contactPhoneCtrl.text = c['contactPhone'] ?? '';
            _emergencyNameCtrl.text = c['emergencyName'] ?? '';
            _emergencyPhoneCtrl.text = c['emergencyPhone'] ?? '';
            _emergencyRelationCtrl.text = c['emergencyRelation'] ?? '';
          });
        }
      }
    } catch (e) {
      // Ignore errors silently
    }
  }

  Future<void> _savePassengerData(int index) async {
    try {
      if (index >= _passengers.length) return;
      final p = _passengers[index];
      if (!p.saveDetails) return; // Only save if checkbox is checked

      final prefs = await SharedPreferences.getInstance();
      final data = {
        'salutation': p.salutation,
        'firstName': p.firstNameCtrl.text.trim(),
        'lastName': p.lastNameCtrl.text.trim(),
        'nationality': p.nationality,
        'documentType': p.documentType,
        'dateOfBirth': p.dateOfBirth?.toIso8601String(),
        'nationalId': p.nationalIdCtrl.text.trim(),
        'bForm': p.bFormCtrl.text.trim(),
        'passportNumber': p.passportNumberCtrl.text.trim(),
        'passportIssuingCountry': p.passportIssuingCountry,
        'passportIssuanceDate': p.passportIssuanceDate?.toIso8601String(),
        'passportExpiryDate': p.passportExpiryDate?.toIso8601String(),
      };
      await prefs.setString('saved_passenger_data_$index', jsonEncode(data));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Passenger details saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save passenger details'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();

    // Remove listeners before disposing
    _contactNameCtrl.removeListener(_onContactFieldChanged);
    _contactEmailCtrl.removeListener(_onContactFieldChanged);
    _contactPhoneCtrl.removeListener(_onContactFieldChanged);
    _emergencyNameCtrl.removeListener(_onContactFieldChanged);
    _emergencyPhoneCtrl.removeListener(_onContactFieldChanged);
    _emergencyRelationCtrl.removeListener(_onContactFieldChanged);

    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyEmailCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    for (final p in _passengers) {
      p.dispose();
    }
    super.dispose();
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _passengerLabel(int i) {
    if (i < _adults) return 'Adult ${i + 1}';
    if (i < _adults + _children) return 'Child ${i - _adults + 1}';
    return 'Infant ${i - _adults - _children + 1}';
  }

  String _getPassengerBreakdown() {
    final parts = <String>[];
    if (_adults > 0) {
      parts.add('$_adults Adult${_adults > 1 ? 's' : ''}');
    }
    if (_children > 0) {
      parts.add('$_children Child${_children > 1 ? 'ren' : ''}');
    }
    if (_infants > 0) {
      parts.add('$_infants Infant${_infants > 1 ? 's' : ''}');
    }
    return '${parts.join(' | ')} - ${_flight.cabinClass}';
  }

  double _calculateTotalPrice() {
    if (_isRoundTrip && _outboundFlight != null && _returnFlight != null) {
      return (_outboundFlight!.price + _returnFlight!.price) * _totalPassengers;
    }
    return _flight.price * _totalPassengers;
  }

  bool get _isContactPage => _currentPage == _totalPassengers;

  void _goNext() {
    if (_currentPage < _totalPassengers) {
      // mark passenger page as submitted so dropdowns/pickers show errors
      setState(() => _passengers[_currentPage].submitted = true);
    }
    if (!_formKeys[_currentPage].currentState!.validate()) return;

    // validate required custom fields (dropdown / date pickers)
    if (_currentPage < _totalPassengers) {
      final p = _passengers[_currentPage];
      if (p.nationality == null) return; // nationality required
      if (p.dateOfBirth == null) return; // DOB required

      // Document validation based on nationality, passenger type and document type
      if (p.nationality == 'Pakistan') {
        // Pakistani nationals - different requirements for adults vs children/infants
        if (_currentPage < _adults) {
          // Adults: CNIC or Passport
          if (p.documentType == 'CNIC') {
            // CNIC validation handled by form validator
          } else if (p.documentType == 'Passport') {
            if (p.passportIssuingCountry == null) return;
            if (p.passportIssuanceDate == null) return;
            if (p.passportExpiryDate == null) return;
          }
        } else {
          // Children & Infants: B-Form or Passport only
          if (p.documentType == 'B-Form') {
            // B-Form validation handled by form validator
          } else if (p.documentType == 'Passport') {
            if (p.passportIssuingCountry == null) return;
            if (p.passportIssuanceDate == null) return;
            if (p.passportExpiryDate == null) return;
          }
        }
      } else if (p.nationality != null && p.nationality != 'Pakistan') {
        // Non-Pakistani nationals: passport required
        if (p.passportIssuingCountry == null) return;
        if (p.passportIssuanceDate == null) return;
        if (p.passportExpiryDate == null) return;
      }
      // Save passenger data if save checkbox is checked
      if (p.saveDetails) {
        _savePassengerData(_currentPage);
      }
    }

    setState(() => _currentPage++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _goBack() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Get.back();
    }
  }

  // Check if contact form has all required fields filled
  bool get _isContactFormValid {
    return _contactNameCtrl.text.trim().isNotEmpty &&
        _contactEmailCtrl.text.trim().isNotEmpty &&
        _contactPhoneCtrl.text.trim().isNotEmpty &&
        _emergencyNameCtrl.text.trim().isNotEmpty &&
        _emergencyPhoneCtrl.text.trim().isNotEmpty &&
        _emergencyRelationCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKeys[_totalPassengers].currentState!.validate()) return;
    final passengersData = List.generate(_totalPassengers, (i) {
      final p = _passengers[i];

      // Determine the travel document number based on nationality and document type
      String travelDocNumber = '';
      if (p.nationality == 'Pakistan') {
        if (p.documentType == 'CNIC') {
          travelDocNumber = p.nationalIdCtrl.text.trim();
        } else if (p.documentType == 'B-Form') {
          travelDocNumber = p.bFormCtrl.text.trim();
        } else {
          travelDocNumber = p.passportNumberCtrl.text.trim();
        }
      } else {
        travelDocNumber = p.passportNumberCtrl.text.trim();
      }

      return {
        'firstName': p.firstNameCtrl.text.trim(),
        'lastName': p.lastNameCtrl.text.trim(),
        'salutation': p.salutation,
        'nationality': p.nationality ?? '',
        'dateOfBirth': p.dateOfBirth?.toIso8601String() ?? '',
        'documentType':
            p.nationality == 'Pakistan' ? p.documentType : 'Passport',
        'passportNumber': p.passportNumberCtrl.text.trim(),
        'passportIssuingCountry': p.passportIssuingCountry ?? '',
        'passportIssuanceDate': p.passportIssuanceDate?.toIso8601String() ?? '',
        'passportExpiryDate': p.passportExpiryDate?.toIso8601String() ?? '',
        'nationalId': p.nationalIdCtrl.text.trim(),
        'bForm': p.bFormCtrl.text.trim(),
        'idNumber': travelDocNumber,
        'passportOrId':
            travelDocNumber, // Used in e-tickets and payment confirmations
        'phone': _contactPhoneCtrl.text.trim(),
      };
    });
    // Save contact info for future auto-fill
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'saved_contact_info_flight',
          jsonEncode({
            'contactName': _contactNameCtrl.text.trim(),
            'contactEmail': _contactEmailCtrl.text.trim(),
            'contactPhone': _contactPhoneCtrl.text.trim(),
            'emergencyName': _emergencyNameCtrl.text.trim(),
            'emergencyPhone': _emergencyPhoneCtrl.text.trim(),
            'emergencyRelation': _emergencyRelationCtrl.text.trim(),
          }));
    } catch (_) {}

    Get.toNamed(AppLink.bookingStep2, arguments: {
      'flight': _flight,
      'searchParams': _searchParams,
      'passengers': passengersData,
      'contactName': _contactNameCtrl.text.trim(),
      'contactEmail': _contactEmailCtrl.text.trim(),
      'contactPhone': _contactPhoneCtrl.text.trim(),
      // Emergency contact
      'emergencyName': _emergencyNameCtrl.text.trim(),
      'emergencyEmail': _emergencyEmailCtrl.text.trim(),
      'emergencyPhone': _emergencyPhoneCtrl.text.trim(),
      'emergencyRelation': _emergencyRelationCtrl.text.trim(),
      // Round trip data
      'isRoundTrip': _isRoundTrip,
      'outboundFlight': _outboundFlight,
      'returnFlight': _returnFlight,
    });
  }

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildStepper(context),
          Container(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalPassengers + 1,
              itemBuilder: (_, i) {
                if (i < _totalPassengers) {
                  return _buildPassengerPage(context, i);
                }
                return _buildContactPage(context);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // â”€â”€ app bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: TravelloTheme.primaryMain,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: _goBack,
      ),
      title: Text(
        _isContactPage ? 'Contact Details' : 'Passenger Details',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: () => Get.toNamed('/faq'),
          tooltip: 'Help & FAQs',
        ),
      ],
    );
  }

  // â”€â”€ 5-step stepper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStepper(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    const goldColor = Color(0xFFD4AF37);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 12,
        horizontal: isMobile ? 8 : 16,
      ),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            // Connecting line
            final stepBefore = i ~/ 2;
            final isCompleted = stepBefore < 0;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: isCompleted ? goldColor : const Color(0xFFE0E0E0),
              ),
            );
          }
          // Circle
          final index = i ~/ 2;
          final isActive = index == 0; // PASSENGERS
          final isCompleted = index < 0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? goldColor
                      : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check,
                          color: Colors.white, size: isMobile ? 12 : 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isActive ? Colors.white : Colors.grey.shade500,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                _steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 9,
                  color: isCompleted || isActive
                      ? goldColor
                      : Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // â”€â”€ passenger page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // ── flight info card ────────────────────────────────────────────────────────

  Widget _buildFlightInfo(BuildContext context) {
    const primary = TravelloTheme.primaryMain;
    final depDate = DateFormat('dd MMM').format(_departureDate);
    final arrDate = DateFormat('dd MMM')
        .format(_departureDate.add(const Duration(hours: 3)));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Airline header bar ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  primary.withValues(alpha: 0.07),
                  primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Airline icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(Icons.flight_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                // Airline name + code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _flight.airlineName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_flight.airlineCode}  ·  ${_flight.cabinClass}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Non-Stop pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Non-Stop',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Horizontal route section ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
            child: Column(
              children: [
                // Top row: Times
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _flight.departureTime,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.5,
                            height: 1.0),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _flight.arrivalTime,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.5,
                            height: 1.0),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Middle row: City codes + Timeline
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // KHI badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fromAirport.code,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primary,
                            letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Timeline (dashed line + plane + dashed line)
                    Expanded(
                      child: Row(
                        children: [
                          // Left dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primary, width: 2.2),
                              color: Colors.white,
                            ),
                          ),
                          // Left dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _HorizontalDashedPainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Plane icon (facing right/forward)
                          Transform.rotate(
                            angle: math.pi / 4,
                            child: const Icon(Icons.flight_rounded,
                                size: 28, color: primary),
                          ),
                          // Right dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _HorizontalDashedPainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Right dot (filled)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // LHE badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _toAirport.code,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primary,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: City names + Duration chip + Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fromAirport.location,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            depDate,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // Duration chip (center)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _flight.duration,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB3B3B3)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _toAirport.location,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            arrDate,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Colors.grey.shade100),

          // ── Footer: price per person ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Row(
              children: [
                Icon(Icons.sell_outlined,
                    size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  'Base fare per person',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatPKR(_flight.price),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnFlightCard(BuildContext context) {
    if (_returnFlight == null || _returnDate == null) {
      return const SizedBox.shrink();
    }

    const primary = TravelloTheme.primaryMain;
    final depDate = DateFormat('dd MMM').format(_returnDate!);
    final arrDate =
        DateFormat('dd MMM').format(_returnDate!.add(const Duration(hours: 3)));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Airline header bar ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  primary.withValues(alpha: 0.07),
                  primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Airline icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(Icons.flight_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                // Airline name + code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _returnFlight!.airlineName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_returnFlight!.airlineCode}  ·  ${_returnFlight!.cabinClass}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Non-Stop pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Non-Stop',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Horizontal route section ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
            child: Column(
              children: [
                // Top row: Times
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _returnFlight!.departureTime,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.5,
                            height: 1.0),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _returnFlight!.arrivalTime,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.5,
                            height: 1.0),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Middle row: City codes + Timeline (reversed for return)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LHE badge (return starts from destination)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _toAirport.code,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primary,
                            letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Timeline (dashed line + plane + dashed line)
                    Expanded(
                      child: Row(
                        children: [
                          // Left dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primary, width: 2.2),
                              color: Colors.white,
                            ),
                          ),
                          // Left dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _HorizontalDashedPainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Plane icon (facing right/forward)
                          Transform.rotate(
                            angle: math.pi / 4,
                            child: const Icon(Icons.flight_rounded,
                                size: 28, color: primary),
                          ),
                          // Right dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _HorizontalDashedPainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Right dot (filled)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // KHI badge (return ends at origin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fromAirport.code,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primary,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: City names + Duration chip + Date (reversed)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _toAirport.location,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            depDate,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // Duration chip (center)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _returnFlight!.duration,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB3B3B3)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fromAirport.location,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            arrDate,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Colors.grey.shade100),

          // ── Footer: price per person ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Row(
              children: [
                Icon(Icons.sell_outlined,
                    size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  'Base fare per person',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatPKR(_returnFlight!.price),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerPage(BuildContext context, int i) {
    final p = _passengers[i];
    return SingleChildScrollView(
      primary: false,
      controller: _currentPage == i ? _scrollController : null,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[i],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Departure Section ──
            const Text(
              'Departure',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD4AF37),
                  letterSpacing: 0.3),
            ),
            const SizedBox(height: 12),
            _buildFlightInfo(context),
            const SizedBox(height: 16),

            // Return flight card for round trips
            if (_isRoundTrip && _returnFlight != null) ...[
              const Text(
                'Return',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD4AF37),
                    letterSpacing: 0.3),
              ),
              const SizedBox(height: 12),
              _buildReturnFlightCard(context),
              const SizedBox(height: 16),
            ],

            const Text(
              'Add Passenger Details',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4AF37)),
            ),
            const SizedBox(height: 4),
            Text(
              'Passenger ${_currentPage + 1} of $_totalPassengers',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12.8),
            Container(
              decoration: BoxDecoration(
                color: TravelloTheme.paperLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.04),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.4),
                          decoration: BoxDecoration(
                            color: TravelloTheme.primaryMain
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person,
                              color: TravelloTheme.primaryMain, size: 18),
                        ),
                        const SizedBox(width: 9.6),
                        Text(_passengerLabel(i),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37))),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9.6),
                          decoration: BoxDecoration(
                            color: TravelloTheme.primaryMain
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(
                                  color: TravelloTheme.primaryMain, width: 3),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: TravelloTheme.primaryMain, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your name must be entered exactly as it appears on your government-issued ID.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // salutation
                        _sectionLabel('Title'),
                        const SizedBox(height: 6.4),
                        Row(
                          children: ['Mr', 'Mrs', 'Miss'].map((t) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: GestureDetector(
                                onTap: () => setState(() => p.salutation = t),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Radio<String>(
                                        value: t,
                                        groupValue: p.salutation,
                                        onChanged: (v) =>
                                            setState(() => p.salutation = v!),
                                        activeColor: TravelloTheme.primaryMain,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 4.8),
                                    Text(t,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // first + last name
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  _buildTextField(
                                    label: 'First Name',
                                    controller: p.firstNameCtrl,
                                    icon: Icons.person_outline,
                                    hint: 'Enter First Name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z ]'))
                                    ],
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'First name is required';
                                      }
                                      if (s.length < 2) {
                                        return 'Minimum 2 characters';
                                      }
                                      if (!RegExp(r'^[a-zA-Z ]+$')
                                          .hasMatch(s)) {
                                        return 'Letters only';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    label: 'Last Name',
                                    controller: p.lastNameCtrl,
                                    icon: Icons.person_outline,
                                    hint: 'Enter Last Name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z ]'))
                                    ],
                                    validator: (v) {
                                      final s = v?.trim() ?? '';
                                      if (s.isEmpty) {
                                        return 'Last name is required';
                                      }
                                      if (s.length < 2) {
                                        return 'Minimum 2 characters';
                                      }
                                      if (!RegExp(r'^[a-zA-Z ]+$')
                                          .hasMatch(s)) {
                                        return 'Letters only';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                    child: _buildTextField(
                                  label: 'First Name',
                                  controller: p.firstNameCtrl,
                                  icon: Icons.person_outline,
                                  hint: 'Enter First Name',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z ]'))
                                  ],
                                  validator: (v) {
                                    final s = v?.trim() ?? '';
                                    if (s.isEmpty) {
                                      return 'First name is required';
                                    }
                                    if (s.length < 2) {
                                      return 'Minimum 2 characters';
                                    }
                                    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(s)) {
                                      return 'Letters only';
                                    }
                                    return null;
                                  },
                                )),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildTextField(
                                  label: 'Last Name',
                                  controller: p.lastNameCtrl,
                                  icon: Icons.person_outline,
                                  hint: 'Enter Last Name',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z ]'))
                                  ],
                                  validator: (v) {
                                    final s = v?.trim() ?? '';
                                    if (s.isEmpty) {
                                      return 'Last name is required';
                                    }
                                    if (s.length < 2) {
                                      return 'Minimum 2 characters';
                                    }
                                    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(s)) {
                                      return 'Letters only';
                                    }
                                    return null;
                                  },
                                )),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // nationality + date of birth
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  _buildDropdown(
                                    label: 'Nationality',
                                    icon: Icons.language,
                                    value: p.nationality,
                                    hint: 'Select',
                                    items: _kCountries,
                                    onChanged: (v) =>
                                        setState(() => p.nationality = v),
                                    showError:
                                        p.submitted && p.nationality == null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDatePicker(
                                    context: context,
                                    label: 'Date of Birth',
                                    icon: Icons.calendar_month_outlined,
                                    value: p.dateOfBirth,
                                    hint: 'Select',
                                    // Age-based date range
                                    firstDate: i >= _adults + _children
                                        ? _departureDate
                                            .subtract(const Duration(days: 730))
                                        : i >= _adults
                                            ? _departureDate.subtract(
                                                const Duration(days: 4383))
                                            : DateTime(1920),
                                    lastDate: i >= _adults + _children
                                        ? _departureDate
                                        : i >= _adults
                                            ? _departureDate.subtract(
                                                const Duration(days: 730))
                                            : _departureDate.subtract(
                                                const Duration(days: 4383)),
                                    initialPickerDate: i >= _adults + _children
                                        ? _departureDate
                                            .subtract(const Duration(days: 180))
                                        : i >= _adults
                                            ? _departureDate.subtract(
                                                const Duration(days: 2190))
                                            : _departureDate.subtract(
                                                const Duration(days: 9125)),
                                    ageHint: i >= _adults + _children
                                        ? 'Infant: 0 – 24 months at travel date'
                                        : i >= _adults
                                            ? 'Child: 2 – 12 years at travel date'
                                            : 'Adult: 12+ years at travel date',
                                    onPicked: (d) =>
                                        setState(() => p.dateOfBirth = d),
                                    showError:
                                        p.submitted && p.dateOfBirth == null,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                    child: _buildDropdown(
                                  label: 'Nationality',
                                  icon: Icons.language,
                                  value: p.nationality,
                                  hint: 'Select',
                                  items: _kCountries,
                                  onChanged: (v) =>
                                      setState(() => p.nationality = v),
                                  showError:
                                      p.submitted && p.nationality == null,
                                )),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildDatePicker(
                                  context: context,
                                  label: 'Date of Birth',
                                  icon: Icons.calendar_month_outlined,
                                  value: p.dateOfBirth,
                                  hint: 'Select',
                                  // Age-based date range
                                  firstDate: i >= _adults + _children
                                      ? _departureDate
                                          .subtract(const Duration(days: 730))
                                      : i >= _adults
                                          ? _departureDate.subtract(
                                              const Duration(days: 4383))
                                          : DateTime(1920),
                                  lastDate: i >= _adults + _children
                                      ? _departureDate
                                      : i >= _adults
                                          ? _departureDate.subtract(
                                              const Duration(days: 730))
                                          : _departureDate.subtract(
                                              const Duration(days: 4383)),
                                  initialPickerDate: i >= _adults + _children
                                      ? _departureDate
                                          .subtract(const Duration(days: 180))
                                      : i >= _adults
                                          ? _departureDate.subtract(
                                              const Duration(days: 2190))
                                          : _departureDate.subtract(
                                              const Duration(days: 9125)),
                                  ageHint: i >= _adults + _children
                                      ? 'Infant: 0 – 24 months at travel date'
                                      : i >= _adults
                                          ? 'Child: 2 – 12 years at travel date'
                                          : 'Adult: 12+ years at travel date',
                                  onPicked: (d) =>
                                      setState(() => p.dateOfBirth = d),
                                  showError:
                                      p.submitted && p.dateOfBirth == null,
                                )),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ══════ ADULTS: CNIC/PASSPORT SELECTOR (Pakistan Only) ══════
                        if (p.nationality == 'Pakistan' && i < _adults) ...[
                          // Document Type Selector for Adults
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Travel Document Type',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Adults (18+) can use CNIC or Passport',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 500;
                                    final spacing = isMobile ? 8 : 12;

                                    final cnicButton = InkWell(
                                      onTap: () => setState(
                                          () => p.documentType = 'CNIC'),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.documentType == 'CNIC'
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: p.documentType == 'CNIC'
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .dividerColor,
                                            width: p.documentType == 'CNIC'
                                                ? 2
                                                : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              p.documentType == 'CNIC'
                                                  ? Icons.radio_button_checked
                                                  : Icons
                                                      .radio_button_unchecked,
                                              size: 20,
                                              color: p.documentType == 'CNIC'
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'CNIC',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    p.documentType == 'CNIC'
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color: p.documentType == 'CNIC'
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    final passportButton = InkWell(
                                      onTap: () => setState(
                                          () => p.documentType = 'Passport'),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.documentType == 'Passport'
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: p.documentType == 'Passport'
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .dividerColor,
                                            width: p.documentType == 'Passport'
                                                ? 2
                                                : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              p.documentType == 'Passport'
                                                  ? Icons.radio_button_checked
                                                  : Icons
                                                      .radio_button_unchecked,
                                              size: 20,
                                              color:
                                                  p.documentType == 'Passport'
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Passport',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    p.documentType == 'Passport'
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                color:
                                                    p.documentType == 'Passport'
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

                                    if (isMobile) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          cnicButton,
                                          SizedBox(height: spacing.toDouble()),
                                          passportButton,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: cnicButton),
                                        SizedBox(width: spacing.toDouble()),
                                        Expanded(child: passportButton),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ══════ ADULTS: CNIC FIELDS ══════
                        if (p.documentType == 'CNIC' && i < _adults) ...[
                          _buildTextField(
                            label: 'National ID (CNIC)',
                            controller: p.nationalIdCtrl,
                            icon: Icons.credit_card_outlined,
                            hint: 'Enter CNIC (XXXXX-XXXXXXX-X)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              CnicFormatter(),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'CNIC is required for Pakistani adults';
                              }
                              // Remove dashes to check digit count
                              final digits = v.replaceAll('-', '');
                              if (digits.length != 13) {
                                return 'CNIC must be exactly 13 digits';
                              }
                              // Format validation
                              if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$')
                                  .hasMatch(v)) {
                                return 'Format: XXXXX-XXXXXXX-X (13 digits)';
                              }
                              // Uniqueness check
                              for (int j = 0; j < _totalPassengers; j++) {
                                if (j == i) continue;
                                final otherP = _passengers[j];
                                if (otherP.nationality == 'Pakistan' &&
                                    otherP.documentType == 'CNIC') {
                                  final otherDigits = otherP.nationalIdCtrl.text
                                      .trim()
                                      .replaceAll('-', '');
                                  if (otherDigits == digits) {
                                    return 'This CNIC is already used for another passenger';
                                  }
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'CNIC is valid for Pakistani adults (18+ years)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ══════ CHILDREN/INFANTS: B-FORM SELECTOR ══════
                        if (p.nationality == 'Pakistan' && i >= _adults) ...[
                          // Document Type Selector for Children/Infants
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Travel Document Type',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  i >= _adults + _children
                                      ? 'Infants require B-Form or Passport'
                                      : 'Children require B-Form or Passport',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(
                                            () => p.documentType = 'B-Form'),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.documentType == 'B-Form'
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: p.documentType == 'B-Form'
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .dividerColor,
                                              width: p.documentType == 'B-Form'
                                                  ? 2
                                                  : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                p.documentType == 'B-Form'
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                        .radio_button_unchecked,
                                                size: 20,
                                                color:
                                                    p.documentType == 'B-Form'
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.5),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'B-Form',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      p.documentType == 'B-Form'
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                  color:
                                                      p.documentType == 'B-Form'
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(
                                            () => p.documentType = 'Passport'),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.documentType == 'Passport'
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  p.documentType == 'Passport'
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Theme.of(context)
                                                          .dividerColor,
                                              width:
                                                  p.documentType == 'Passport'
                                                      ? 2
                                                      : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                p.documentType == 'Passport'
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                        .radio_button_unchecked,
                                                size: 20,
                                                color:
                                                    p.documentType == 'Passport'
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.5),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Passport',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: p.documentType ==
                                                          'Passport'
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: p.documentType ==
                                                          'Passport'
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ══════ CHILDREN/INFANTS: B-FORM FIELDS ══════
                        if (p.documentType == 'B-Form' && i >= _adults) ...[
                          _buildTextField(
                            label: 'B-Form Number (NADRA Child Certificate)',
                            controller: p.bFormCtrl,
                            icon: Icons.credit_card_outlined,
                            hint: 'Enter B-Form (XXXXX-XXXXXXX-X)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              BFormFormatter(),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'B-Form is required for Pakistani children/infants';
                              }
                              // Remove dashes to check digit count
                              final digits = v.replaceAll('-', '');
                              if (digits.length != 13) {
                                return 'B-Form must be exactly 13 digits';
                              }
                              // Format validation
                              if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$')
                                  .hasMatch(v)) {
                                return 'Format: XXXXX-XXXXXXX-X (13 digits)';
                              }
                              // Uniqueness check
                              for (int j = 0; j < _totalPassengers; j++) {
                                if (j == i) continue;
                                final otherP = _passengers[j];
                                if (otherP.nationality == 'Pakistan' &&
                                    otherP.documentType == 'B-Form') {
                                  final otherDigits = otherP.bFormCtrl.text
                                      .trim()
                                      .replaceAll('-', '');
                                  if (otherDigits == digits) {
                                    return 'This B-Form is already used for another passenger';
                                  }
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'B-Form (Form-B) is issued by NADRA for Pakistani children under 18 years',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ══════ ALL PAKISTANIS: PASSPORT FIELDS ══════
                        if (p.documentType == 'Passport' &&
                            p.nationality == 'Pakistan') ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  label: 'Passport Number',
                                  controller: p.passportNumberCtrl,
                                  icon: Icons.article_outlined,
                                  hint: p.nationality == 'Pakistan'
                                      ? 'e.g., AB1234567 (9 characters)'
                                      : 'e.g., A12345678 (6-12 characters)',
                                  capitalization: TextCapitalization.characters,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[A-Za-z0-9]')),
                                    LengthLimitingTextInputFormatter(12),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Passport number is required';
                                    }
                                    final passport = v.trim().toUpperCase();

                                    // Length validation
                                    if (passport.length < 6) {
                                      return 'Passport must be at least 6 characters';
                                    }
                                    if (passport.length > 12) {
                                      return 'Passport cannot exceed 12 characters';
                                    }

                                    // Format validation: Alphanumeric only
                                    if (!RegExp(r'^[A-Z0-9]+$')
                                        .hasMatch(passport)) {
                                      return 'Only letters and numbers allowed';
                                    }

                                    // Pakistani passport specific validation
                                    if (p.nationality == 'Pakistan') {
                                      if (passport.length < 7 ||
                                          passport.length > 9) {
                                        return 'Pakistani passport: 7-9 characters';
                                      }
                                      // Modern Pakistani passports: 2 letters + 7 digits
                                      if (passport.length == 9) {
                                        if (!RegExp(r'^[A-Z]{2}[0-9]{7}$')
                                            .hasMatch(passport)) {
                                          return 'Format: 2 letters + 7 digits (e.g., AB1234567)';
                                        }
                                      }
                                    }

                                    // Uniqueness check across all passengers
                                    for (int j = 0; j < _totalPassengers; j++) {
                                      if (j == i) continue;
                                      final otherP = _passengers[j];
                                      final otherPassport = otherP
                                          .passportNumberCtrl.text
                                          .trim()
                                          .toUpperCase();
                                      if (otherPassport.isNotEmpty &&
                                          otherPassport == passport) {
                                        return 'This passport is already used for another passenger';
                                      }
                                    }

                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Issuing Country',
                                  icon: Icons.language,
                                  value: p.passportIssuingCountry,
                                  hint: 'Select',
                                  items: _kCountries,
                                  onChanged: (v) => setState(
                                      () => p.passportIssuingCountry = v),
                                  showError: p.submitted &&
                                      p.passportIssuingCountry == null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatePicker(
                                  context: context,
                                  label: 'Issue Date',
                                  icon: Icons.calendar_today_outlined,
                                  value: p.passportIssuanceDate,
                                  hint: 'Select',
                                  firstDate: DateTime(1980),
                                  lastDate: DateTime.now(),
                                  onPicked: (d) => setState(
                                      () => p.passportIssuanceDate = d),
                                  showError: p.submitted &&
                                      p.passportIssuanceDate == null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDatePicker(
                                  context: context,
                                  label: 'Expiry Date',
                                  icon: Icons.calendar_today_outlined,
                                  value: p.passportExpiryDate,
                                  hint: 'Select',
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2060),
                                  onPicked: (d) =>
                                      setState(() => p.passportExpiryDate = d),
                                  highlightExpiry: true,
                                  showError: p.submitted &&
                                      p.passportExpiryDate == null,
                                  validator: (date) {
                                    if (date == null) return null;
                                    // Passport must be valid for at least 6 months
                                    final sixMonthsFromNow = DateTime.now()
                                        .add(const Duration(days: 180));
                                    if (date.isBefore(sixMonthsFromNow)) {
                                      return 'Passport must be valid for 6+ months';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ══════ NON-PAKISTANI NATIONALS: PASSPORT REQUIRED ══════
                        if (p.nationality != null &&
                            p.nationality != 'Pakistan') ...[
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                label: 'Passport Number',
                                controller: p.passportNumberCtrl,
                                icon: Icons.article_outlined,
                                hint: 'e.g., A12345678 (6-12 characters)',
                                capitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[A-Za-z0-9]')),
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Passport number is required';
                                  }
                                  final passport = v.trim().toUpperCase();

                                  // Length validation
                                  if (passport.length < 6) {
                                    return 'Passport must be at least 6 characters';
                                  }
                                  if (passport.length > 12) {
                                    return 'Passport cannot exceed 12 characters';
                                  }

                                  // Format validation: Alphanumeric only
                                  if (!RegExp(r'^[A-Z0-9]+$')
                                      .hasMatch(passport)) {
                                    return 'Only letters and numbers allowed';
                                  }

                                  // Uniqueness check
                                  for (int j = 0; j < _totalPassengers; j++) {
                                    if (j == i) continue;
                                    final otherPassport = _passengers[j]
                                        .passportNumberCtrl
                                        .text
                                        .trim()
                                        .toUpperCase();
                                    if (otherPassport.isNotEmpty &&
                                        otherPassport == passport) {
                                      return 'This passport is already used';
                                    }
                                  }

                                  return null;
                                },
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildDropdown(
                                label: 'Passport Issuing Country',
                                icon: Icons.language,
                                value: p.passportIssuingCountry,
                                hint: 'Select',
                                items: _kCountries,
                                onChanged: (v) => setState(
                                    () => p.passportIssuingCountry = v),
                                showError: p.submitted &&
                                    p.passportIssuingCountry == null,
                              )),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildDatePicker(
                                context: context,
                                label: 'Passport Issuance',
                                icon: Icons.calendar_today_outlined,
                                value: p.passportIssuanceDate,
                                hint: 'Select',
                                firstDate: DateTime(1980),
                                lastDate: DateTime.now(),
                                onPicked: (d) =>
                                    setState(() => p.passportIssuanceDate = d),
                                showError: p.submitted &&
                                    p.passportIssuanceDate == null,
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildDatePicker(
                                context: context,
                                label: 'Passport Expiry',
                                icon: Icons.calendar_today_outlined,
                                value: p.passportExpiryDate,
                                hint: 'Select',
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2060),
                                onPicked: (d) =>
                                    setState(() => p.passportExpiryDate = d),
                                highlightExpiry: true,
                                showError:
                                    p.submitted && p.passportExpiryDate == null,
                                validator: (date) {
                                  if (date == null) return null;
                                  // Passport must be valid for at least 6 months
                                  final sixMonthsFromNow = DateTime.now()
                                      .add(const Duration(days: 180));
                                  if (date.isBefore(sixMonthsFromNow)) {
                                    return 'Passport must be valid for 6+ months';
                                  }
                                  return null;
                                },
                              )),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        // save details
                        GestureDetector(
                          onTap: () async {
                            final newVal = !p.saveDetails;
                            setState(() => p.saveDetails = newVal);
                            if (!newVal) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove('saved_passenger_data_$i');
                            }
                          },
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: p.saveDetails,
                                  onChanged: (v) async {
                                    setState(() => p.saveDetails = v!);
                                    if (!v!) {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs
                                          .remove('saved_passenger_data_$i');
                                    }
                                  },
                                  activeColor: TravelloTheme.primaryMain,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                  side: BorderSide(
                                      color: Colors.grey.shade400, width: 1.5),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Save Details for future use',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  // â”€â”€ contact page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContactPage(BuildContext context) {
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[_totalPassengers],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: TravelloTheme.paperLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.04),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.4),
                          decoration: BoxDecoration(
                            color: TravelloTheme.primaryMain
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.contact_phone_outlined,
                              color: TravelloTheme.primaryMain, size: 18),
                        ),
                        const SizedBox(width: 9.6),
                        const Text('Contact Details',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9.6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                  color: Colors.orange.shade400, width: 3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange.shade600, size: 16),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Booking confirmation and e-ticket will be sent to this contact.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        DSInputField(
                          label: 'Full Name',
                          controller: _contactNameCtrl,
                          hint: 'Enter full name',
                          prefixIcon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z ]')),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Full name is required';
                            if (s.length < 3) return 'Minimum 3 characters';
                            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(s)) {
                              return 'Letters only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14.4),
                        DSInputField(
                          label: 'Email Address',
                          controller: _contactEmailCtrl,
                          hint: 'Enter email address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: DSValidators.email,
                        ),
                        const SizedBox(height: 14.4),
                        DSInputField(
                          label: 'Phone Number',
                          controller: _contactPhoneCtrl,
                          hint: '3001234567',
                          prefixIcon: Icons.phone_outlined,
                          prefixText: '+92 ',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            _NoLeadingZeroFormatter(),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Phone number is required';
                            if (s.startsWith('0')) {
                              return 'Do not include leading 0';
                            }
                            if (s.length != 10) {
                              return 'Enter 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  // Emergency Contact Section
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      color: TravelloTheme.paperLight,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.emergency_outlined,
                              color: Colors.red.shade700, size: 18),
                        ),
                        const SizedBox(width: 9.6),
                        const Text('Emergency Contact',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9.6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                  color: Colors.red.shade400, width: 3),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFFD4AF37), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Emergency contact will be notified in case of any urgent situation.',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFFB3B3B3)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        DSInputField(
                          label: 'Full Name',
                          controller: _emergencyNameCtrl,
                          hint: 'Enter emergency contact name',
                          prefixIcon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z ]')),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) {
                              return 'Emergency contact name is required';
                            }
                            if (s.length < 3) return 'Minimum 3 characters';
                            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(s)) {
                              return 'Letters only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14.4),
                        DSInputField(
                          label: 'Relationship',
                          controller: _emergencyRelationCtrl,
                          hint: 'e.g., Father, Mother, Spouse, Sibling',
                          prefixIcon: Icons.family_restroom_outlined,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z ]')),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'Relationship is required';
                            if (s.length < 3) return 'Minimum 3 characters';
                            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(s)) {
                              return 'Letters only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14.4),
                        DSInputField(
                          label: 'Email Address (Optional)',
                          controller: _emergencyEmailCtrl,
                          hint: 'Enter email address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return null; // Optional
                            return DSValidators.email(v);
                          },
                        ),
                        const SizedBox(height: 14.4),
                        DSInputField(
                          label: 'Phone Number',
                          controller: _emergencyPhoneCtrl,
                          hint: '3001234567',
                          prefixIcon: Icons.phone_outlined,
                          prefixText: '+92 ',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            _NoLeadingZeroFormatter(),
                          ],
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) {
                              return 'Emergency phone number is required';
                            }
                            if (s.startsWith('0')) {
                              return 'Do not include leading 0';
                            }
                            if (s.length != 10) {
                              return 'Enter 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  // â”€â”€ bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_isRoundTrip ? 'Total (Round Trip)' : 'Total',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    Text(
                      formatPKR(_calculateTotalPrice()),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TravelloTheme.primaryMain,
                      ),
                    ),
                    Text(
                      _getPassengerBreakdown(),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              DSButton(
                label: _isContactPage ? 'CONFIRM' : 'NEXT',
                trailingIcon: Icons.arrow_forward_rounded,
                onTap: _isContactPage ? _submit : _goNext,
                disabled: _isContactPage ? !_isContactFormValid : false,
                width: 148,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ reusable widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
      );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool showLabel = true,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel && label.isNotEmpty) ...[
          _sectionLabel(label),
          const SizedBox(height: 5.6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 11.2, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: TravelloTheme.primaryMain, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    bool showError = false,
  }) {
    final hasError = showError && value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 5.6),
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _CountryPickerSheet(
                selected: value,
                items: items,
                label: label,
              ),
            );
            if (result != null) onChanged(result);
          },
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: hasError ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError ? Colors.red.shade400 : Colors.grey.shade300,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color:
                        hasError ? Colors.red.shade400 : Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: value != null
                          ? TravelloTheme.primaryMain
                          : (hasError
                              ? Colors.red.shade300
                              : Colors.grey.shade400),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color:
                        hasError ? Colors.red.shade400 : Colors.grey.shade500,
                    size: 20),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'This field is required',
              style: TextStyle(color: Colors.red.shade600, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildDatePicker({
    required BuildContext context,
    required String label,
    required IconData icon,
    required DateTime? value,
    required String hint,
    required DateTime firstDate,
    required DateTime lastDate,
    required void Function(DateTime) onPicked,
    bool highlightExpiry = false,
    bool showError = false,
    String? ageHint,
    DateTime? initialPickerDate,
    String? Function(DateTime?)? validator,
  }) {
    final isExpiringSoon = highlightExpiry &&
        value != null &&
        value.isBefore(DateTime.now().add(const Duration(days: 180)));
    final hasError = showError && value == null;
    final validationError = validator != null ? validator(value) : null;
    final displayError = hasError || validationError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 5.6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ??
                  initialPickerDate ??
                  (label.contains('Expiry')
                      ? DateTime.now().add(const Duration(days: 365))
                      : lastDate.isBefore(DateTime.now())
                          ? lastDate
                          : DateTime.now()),
              firstDate: firstDate,
              lastDate: lastDate,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: TravelloTheme.primaryMain),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: displayError
                  ? Colors.red.shade50
                  : isExpiringSoon
                      ? Colors.orange.shade50
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: displayError
                    ? Colors.red.shade400
                    : isExpiringSoon
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                width: displayError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: displayError
                        ? Colors.red.shade400
                        : isExpiringSoon
                            ? Colors.orange.shade600
                            : Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('dd MMM yyyy').format(value)
                        : hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: value != null
                          ? (isExpiringSoon
                              ? Colors.orange.shade700
                              : Colors.black)
                          : (displayError
                              ? Colors.red.shade300
                              : Colors.grey.shade400),
                    ),
                  ),
                ),
                if (isExpiringSoon)
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade500, size: 16),
              ],
            ),
          ),
        ),
        if (displayError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              validationError ?? 'This field is required',
              style: TextStyle(color: Colors.red.shade600, fontSize: 11),
            ),
          ),
        if (!displayError && ageHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              ageHint,
              style: const TextStyle(
                  color: Color.fromARGB(255, 17, 16, 16), fontSize: 10.5),
            ),
          ),
      ],
    );
  }
}

// â”€â”€ PassengerData model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PassengerData {
  String salutation = 'Mr';
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  String? nationality;
  DateTime? dateOfBirth;
  // Document type:
  // - Adults (18+): 'CNIC' or 'Passport'
  // - Children/Infants (<18): 'B-Form' or 'Passport'
  String documentType = 'CNIC';
  // Pakistan → CNIC/B-Form OR passport  |  other nationalities → passport only
  final nationalIdCtrl = TextEditingController(); // For CNIC
  final bFormCtrl = TextEditingController(); // For B-Form (children/infants)
  final passportNumberCtrl = TextEditingController();
  String? passportIssuingCountry;
  DateTime? passportIssuanceDate;
  DateTime? passportExpiryDate;
  bool saveDetails = false;
  bool submitted = false;

  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    nationalIdCtrl.dispose();
    bFormCtrl.dispose();
    passportNumberCtrl.dispose();
  }
}

// â”€â”€ country picker bottom sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CountryPickerSheet extends StatefulWidget {
  final String? selected;
  final List<String> items;
  final String label;
  const _CountryPickerSheet({
    required this.selected,
    required this.items,
    required this.label,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late List<String> _filtered;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.items
            : widget.items.where((c) => c.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          // handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select ${widget.label}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search ...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSel = c == widget.selected;
                return ListTile(
                  title: Text(c,
                      style: TextStyle(
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSel
                      ? const Icon(Icons.check,
                          color: TravelloTheme.primaryMain)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// â"€â"€ prevent leading zero in phone number â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

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

// ── Vertical dashed line for flight timeline ──────────────────────────────
class _HorizontalDashedPainter extends CustomPainter {
  final Color color;
  const _HorizontalDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.5;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_HorizontalDashedPainter old) => old.color != color;
}
