import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flight_app/utils/format_utils.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/widgets/app_input/ds_input_field.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class TrainPassengerForm extends StatefulWidget {
  const TrainPassengerForm({super.key});

  @override
  State<TrainPassengerForm> createState() => _TrainPassengerFormState();
}

class _TrainPassengerFormState extends State<TrainPassengerForm> {
  final _pageController = PageController();
  final _scrollController = ScrollController();
  final _contactScrollController = ScrollController();

  late TrainResult train;
  late String selectedClass;
  late Map<String, dynamic> searchParams;
  bool isRoundTrip = false;
  TrainResult? outboundTrain;
  String? outboundClass;
  TrainResult? returnTrain;
  String? returnClass;

  late int _adults;
  late int _children;
  late int _infants;
  late int _totalPassengers;
  late DateTime _departureDate;
  DateTime? _returnDate;

  int _currentPage = 0;
  late List<_TrainPassengerData> _passengers;
  late List<GlobalKey<FormState>> _formKeys;

  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  final _contactNameKey = GlobalKey();
  final _contactEmailKey = GlobalKey();
  final _contactPhoneKey = GlobalKey();

  final List<String> _steps = [
    'PASSENGERS',
    'FACILITIES',
    'CHECKOUT',
    'PAYMENT',
    'DONE'
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    train = args['train'] as TrainResult;
    selectedClass = args['selectedClass'] as String? ?? '';
    searchParams = args['searchParams'] as Map<String, dynamic>? ?? {};
    isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    outboundTrain = args['outboundTrain'] as TrainResult?;
    outboundClass = args['outboundClass'] as String?;
    returnTrain = args['returnTrain'] as TrainResult?;
    returnClass = args['returnClass'] as String?;
    _adults = (searchParams['adults'] as int?) ?? 1;
    _children = (searchParams['children'] as int?) ?? 0;
    _infants = (searchParams['infants'] as int?) ?? 0;
    final sum = _adults + _children + _infants;
    _totalPassengers = sum > 0 ? sum : 1;
    _departureDate =
        searchParams['departureDate'] as DateTime? ?? DateTime.now();
    _returnDate = searchParams['returnDate'] as DateTime?;
    _passengers = List.generate(_totalPassengers, (index) {
      final passenger = _TrainPassengerData();
      // Set default document type based on passenger category
      // Adults (0 to _adults-1): CNIC
      // Children and Infants (_adults onwards): B-Form
      if (index >= _adults) {
        passenger.documentType = 'B-Form';
      } else {
        passenger.documentType = 'CNIC';
      }
      // Set concession type
      if (index < _adults) {
        passenger.concessionType = 'ADULT';
      } else if (index < _adults + _children) {
        passenger.concessionType = 'CHILD_3_10';
      } else {
        passenger.concessionType = 'INFANT';
      }
      return passenger;
    });
    _formKeys =
        List.generate(_totalPassengers + 1, (_) => GlobalKey<FormState>());
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < _passengers.length; i++) {
        final raw = prefs.getString('train_passenger_$i');
        if (raw == null) continue;
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          final p = _passengers[i];
          p.salutation = data['salutation'] ?? 'Mr';
          p.firstNameCtrl.text = data['firstName'] ?? '';
          p.lastNameCtrl.text = data['lastName'] ?? '';
          p.cnicCtrl.text = data['cnic'] ?? '';
          p.bFormCtrl.text = data['bForm'] ?? '';
          p.passportNumberCtrl.text = data['passportNumber'] ?? '';
          p.nationality = data['nationality'] ?? 'Pakistan';
          p.documentType = data['documentType'] ?? 'CNIC';
          if (data['dob'] != null) {
            p.dateOfBirth = DateTime.tryParse(data['dob']);
          }
          p.saveDetails = true;
        });
      }
      // Load saved contact info
      final contactRaw = prefs.getString('saved_contact_info_train');
      if (contactRaw != null) {
        final c = jsonDecode(contactRaw) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _contactNameCtrl.text = c['contactName'] ?? '';
            _contactEmailCtrl.text = c['contactEmail'] ?? '';
            _contactPhoneCtrl.text = c['contactPhone'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveData(int index) async {
    try {
      final p = _passengers[index];
      if (!p.saveDetails) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'train_passenger_$index',
          jsonEncode({
            'salutation': p.salutation,
            'firstName': p.firstNameCtrl.text.trim(),
            'lastName': p.lastNameCtrl.text.trim(),
            'cnic': p.cnicCtrl.text.trim(),
            'bForm': p.bFormCtrl.text.trim(),
            'passportNumber': p.passportNumberCtrl.text.trim(),
            'nationality': p.nationality,
            'documentType': p.documentType,
            'dob': p.dateOfBirth?.toIso8601String(),
          }));
      if (mounted) {
        Get.snackbar(
          'Saved',
          'Passenger details saved!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _contactScrollController.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    for (final p in _passengers) {
      p.dispose();
    }
    super.dispose();
  }

  String _passengerLabel(int i) {
    if (i < _adults) return 'Adult ${i + 1}';
    if (i < _adults + _children) return 'Child ${i - _adults + 1}';
    return 'Infant ${i - _adults - _children + 1}';
  }

  String _getPassengerBreakdown() {
    final parts = <String>[];
    if (_adults > 0) parts.add('$_adults Adult${_adults > 1 ? "s" : ""}');
    if (_children > 0) {
      parts.add('$_children Child${_children > 1 ? "ren" : ""}');
    }
    if (_infants > 0) parts.add('$_infants Infant${_infants > 1 ? "s" : ""}');
    final cls =
        isRoundTrip ? '${outboundClass ?? selectedClass} (RT)' : selectedClass;
    return '${parts.join(" | ")} – $cls';
  }

  double _calculateTotalPrice() {
    double basePrice = 0.0;
    if (isRoundTrip && outboundTrain != null && returnTrain != null) {
      final a =
          outboundTrain!.classPrices[outboundClass ?? selectedClass] ?? 0.0;
      final b = returnTrain!.classPrices[returnClass ?? selectedClass] ?? 0.0;
      basePrice = (a + b);
    } else {
      basePrice = train.classPrices[selectedClass] ?? 0.0;
    }

    // Calculate total with concession discounts
    double total = 0.0;
    for (var passenger in _passengers) {
      if (passenger.concessionType == 'INFANT') {
        total += 0.0; // Infants (under 3 years) travel free
      } else if (passenger.concessionType == 'CHILD_3_10') {
        total += basePrice * 0.5; // Children (3-11 years) get 50% discount
      } else {
        total += basePrice; // Adults (12+ years) pay full fare
      }
    }
    return total;
  }

  bool get _isContactPage => _currentPage == _totalPassengers;

  void _goBack() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Get.back();
    }
  }

  void _goNext() {
    if (_currentPage < _totalPassengers) {
      setState(() => _passengers[_currentPage].submitted = true);
    }
    if (!_formKeys[_currentPage].currentState!.validate()) {
      if (_currentPage < _totalPassengers) {
        _scrollToFirstPassengerError(_currentPage);
      }
      return;
    }
    if (_currentPage < _totalPassengers) {
      final p = _passengers[_currentPage];
      if (p.dateOfBirth == null) {
        _scrollToFirstPassengerError(_currentPage);
        return;
      }
      if (p.saveDetails) _saveData(_currentPage);
    }
    setState(() => _currentPage++);
    _pageController.nextPage(
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  // Calculate age from date of birth
  String _calculateAge(DateTime? dob) {
    if (dob == null) return '--';
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.toString();
  }

  bool _hasDuplicateDocuments() {
    final seen = <String>{};
    for (final p in _passengers) {
      final doc = p.documentType == 'CNIC'
          ? p.cnicCtrl.text.replaceAll('-', '').trim()
          : p.documentType == 'B-Form'
              ? p.bFormCtrl.text.replaceAll('-', '').trim()
              : p.passportNumberCtrl.text.trim();
      if (doc.isEmpty) continue;
      if (!seen.add(doc)) return true;
    }
    return false;
  }

  Future<void> _submit() async {
    if (_totalPassengers > 1 && _hasDuplicateDocuments()) {
      Get.snackbar(
        'Validation Error',
        'Each passenger must have a unique CNIC / document number.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (!_formKeys[_totalPassengers].currentState!.validate()) {
      _scrollToFirstContactError();
      return;
    }
    final passengersData = List.generate(_totalPassengers, (i) {
      final p = _passengers[i];

      // Determine the travel document number based on document type
      String travelDocNumber = '';
      if (p.documentType == 'CNIC') {
        travelDocNumber = p.cnicCtrl.text.trim();
      } else if (p.documentType == 'B-Form') {
        travelDocNumber = p.bFormCtrl.text.trim();
      } else {
        travelDocNumber = p.passportNumberCtrl.text.trim();
      }

      return {
        'salutation': p.salutation,
        'firstName': p.firstNameCtrl.text.trim(),
        'lastName': p.lastNameCtrl.text.trim(),
        'cnic': p.cnicCtrl.text.trim(),
        'nationalId': p.cnicCtrl.text.trim(),
        'bForm': p.bFormCtrl.text.trim(),
        'passportNumber': p.passportNumberCtrl.text.trim(),
        'nationality': p.nationality,
        'documentType': p.documentType,
        'dateOfBirth': p.dateOfBirth?.toIso8601String() ?? '',
        'age': _calculateAge(p.dateOfBirth),
        'concessionType': p.concessionType,
        'idNumber': travelDocNumber,
        'passportOrId': travelDocNumber,
        'phone': _contactPhoneCtrl.text.trim(),
      };
    });
    // Save contact info for future auto-fill
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'saved_contact_info_train',
          jsonEncode({
            'contactName': _contactNameCtrl.text.trim(),
            'contactEmail': _contactEmailCtrl.text.trim(),
            'contactPhone': _contactPhoneCtrl.text.trim(),
          }));
    } catch (_) {}

    Get.toNamed('/railway-booking-facilities', arguments: {
      'train': train,
      'selectedClass': selectedClass,
      'searchParams': searchParams,
      'passengers': passengersData,
      'contactName': _contactNameCtrl.text.trim(),
      'contactEmail': _contactEmailCtrl.text.trim(),
      'contactPhone': _contactPhoneCtrl.text.trim(),
      'isRoundTrip': isRoundTrip,
      'outboundTrain': outboundTrain,
      'outboundClass': outboundClass,
      'returnTrain': returnTrain,
      'returnClass': returnClass,
      'departureDate': _departureDate,
      'returnDate': _returnDate,
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFD4AF37),
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

  Widget _buildStepper() {
    const goldColor = Color(0xFFD4AF37);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          final index = i ~/ 2;
          final isActive = index == 0; // PASSENGERS
          final isCompleted = index < 0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? goldColor
                      : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isActive ? Colors.white : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
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

  Widget _buildPassengerPage(int i) {
    final p = _passengers[i];
    final label = _passengerLabel(i);

    // Auto-set concession type based on passenger category
    if (i < _adults) {
      p.concessionType = 'ADULT';
    } else if (i < _adults + _children) {
      p.concessionType = 'CHILD_3_10'; // Children 3-11 years get 50% discount
    } else {
      p.concessionType = 'INFANT'; // Infants under 3 years travel free
    }

    final fromStation = searchParams['fromStation'] as RailwayStation?;
    final toStation = searchParams['toStation'] as RailwayStation?;
    final fromCode = fromStation?.code ?? 'DEP';
    final toCode = toStation?.code ?? 'ARR';
    final fromName = fromStation?.name ?? 'Departure';
    final toName = toStation?.name ?? 'Arrival';

    Widget journeySection;
    if (isRoundTrip && outboundTrain != null && returnTrain != null) {
      journeySection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrainCard(
            t: outboundTrain!,
            cls: outboundClass!,
            fromCode: fromCode,
            toCode: toCode,
            fromName: fromName,
            toName: toName,
            date: _departureDate,
          ),
          const SizedBox(height: 20),
          const Text(
            'Return',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 12),
          _buildTrainCard(
            t: returnTrain!,
            cls: returnClass!,
            fromCode: toCode,
            toCode: fromCode,
            fromName: toName,
            toName: fromName,
            date: _returnDate ?? _departureDate,
          ),
        ],
      );
    } else {
      journeySection = _buildTrainCard(
        t: train,
        cls: selectedClass,
        fromCode: fromCode,
        toCode: toCode,
        fromName: fromName,
        toName: toName,
        date: _departureDate,
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  color: Colors.black87,
                  letterSpacing: 0.3),
            ),
            const SizedBox(height: 12),
            journeySection,
            const SizedBox(height: 20),

            // ── "Add Passenger Details" heading ──────────────────
            const Text('Add Passenger Details',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Text('Passenger ${i + 1} of $_totalPassengers',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 16),

            // ── Passenger card ───────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Green tinted header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F8E9),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person,
                              color: Color(0xFFD4AF37), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37))),
                        const SizedBox(width: 8),
                        if (i >= _adults && i < _adults + _children)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Child',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (i >= _adults + _children)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Infant',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(
                                  color: Color(0xFFD4AF37), width: 3),
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
                                  'Your name must be entered exactly as it appears on your government-issued ID.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title radios
                        _sectionLabel('Title'),
                        const SizedBox(height: 8),
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
                                      child: RadioGroup<String>(
                                        groupValue: p.salutation,
                                        onChanged: (v) =>
                                            setState(() => p.salutation = v!),
                                        child: Radio<String>(
                                          value: t,
                                          activeColor: const Color(0xFFD4AF37),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
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

                        // First Name + Last Name
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  _buildTextField(
                                    controller: p.firstNameCtrl,
                                    label: 'First Name',
                                    icon: Icons.person_outline,
                                    hint: 'Enter First Name',
                                    capitalization: TextCapitalization.words,
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
                                    fieldKey: p.firstNameKey,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: p.lastNameCtrl,
                                    label: 'Last Name',
                                    icon: Icons.person_outline,
                                    hint: 'Enter Last Name',
                                    capitalization: TextCapitalization.words,
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
                                    fieldKey: p.lastNameKey,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: p.firstNameCtrl,
                                    label: 'First Name',
                                    icon: Icons.person_outline,
                                    hint: 'Enter First Name',
                                    capitalization: TextCapitalization.words,
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
                                    fieldKey: p.firstNameKey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: p.lastNameCtrl,
                                    label: 'Last Name',
                                    icon: Icons.person_outline,
                                    hint: 'Enter Last Name',
                                    capitalization: TextCapitalization.words,
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
                                    fieldKey: p.lastNameKey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Scroll anchor for DOB / document section
                        Container(key: p.dobKey, height: 0),
                        // Date of Birth + CNIC side by side (conditionally show CNIC)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            if (isMobile) {
                              return Column(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      // Age-based date range
                                      final DateTime firstDate;
                                      final DateTime lastDate;
                                      final DateTime initialDate;
                                      final String ageHint;

                                      if (i >= _adults + _children) {
                                        // Infant: Under 3 years (0-1095 days)
                                        firstDate = _departureDate.subtract(
                                            const Duration(days: 1095));
                                        lastDate = _departureDate;
                                        initialDate = _departureDate.subtract(
                                            const Duration(days: 365));
                                        ageHint =
                                            'Infant: Under 3 years at travel date';
                                      } else if (i >= _adults) {
                                        // Child: 3-11 years (1095-4383 days)
                                        firstDate = _departureDate.subtract(
                                            const Duration(days: 4383));
                                        lastDate = _departureDate.subtract(
                                            const Duration(days: 1095));
                                        initialDate = _departureDate.subtract(
                                            const Duration(days: 2555));
                                        ageHint =
                                            'Child: 3-11 years at travel date';
                                      } else {
                                        // Adult: 12+ years (4383+ days)
                                        firstDate = DateTime(1920);
                                        lastDate = _departureDate.subtract(
                                            const Duration(days: 4383));
                                        initialDate = DateTime(1990);
                                        ageHint =
                                            'Adult: 12+ years at travel date';
                                      }

                                      return _buildDatePicker(
                                        label: 'Date of Birth',
                                        selectedDate: p.dateOfBirth,
                                        showError: p.submitted &&
                                            p.dateOfBirth == null,
                                        ageHint: ageHint,
                                        onTap: () async {
                                          DateTime safeInitialDate =
                                              initialDate;
                                          if (p.dateOfBirth != null) {
                                            if (p.dateOfBirth!
                                                .isBefore(firstDate)) {
                                              safeInitialDate = firstDate;
                                            } else if (p.dateOfBirth!
                                                .isAfter(lastDate)) {
                                              safeInitialDate = lastDate;
                                            } else {
                                              safeInitialDate = p.dateOfBirth!;
                                            }
                                          }

                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: safeInitialDate,
                                            firstDate: firstDate,
                                            lastDate: lastDate,
                                            helpText: ageHint,
                                            builder: (ctx, child) => Theme(
                                              data: Theme.of(ctx).copyWith(
                                                colorScheme:
                                                    const ColorScheme.light(
                                                        primary:
                                                            Color(0xFFD4AF37)),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked != null) {
                                            setState(
                                                () => p.dateOfBirth = picked);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  if (i < _adults) ...[
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: p.cnicCtrl,
                                      label: 'CNIC',
                                      icon: Icons.article_outlined,
                                      hint: 'XXXXX-XXXXXXX-X',
                                      keyboardType: TextInputType.number,
                                      maxLength: 15,
                                      inputFormatters: [_CnicFormatter()],
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'CNIC is required';
                                        }
                                        final clean = v.replaceAll('-', '');
                                        if (clean.length != 13) {
                                          return 'Must be 13 digits';
                                        }
                                        for (int j = 0;
                                            j < _passengers.length;
                                            j++) {
                                          if (j == i) continue;
                                          final otherCnic = _passengers[j]
                                              .cnicCtrl
                                              .text
                                              .replaceAll('-', '');
                                          if (otherCnic.isNotEmpty &&
                                              otherCnic == clean) {
                                            return 'CNIC already used for another passenger';
                                          }
                                        }
                                        return null;
                                      },
                                      fieldKey: p.documentKey,
                                    ),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      // Age-based date range
                                      final DateTime firstDate;
                                      final DateTime lastDate;
                                      final DateTime initialDate;
                                      final String ageHint;

                                      if (i >= _adults + _children) {
                                        // Infant: Under 3 years (0-1095 days)
                                        firstDate = _departureDate.subtract(
                                            const Duration(days: 1095));
                                        lastDate = _departureDate;
                                        initialDate = _departureDate.subtract(
                                            const Duration(days: 365));
                                        ageHint =
                                            'Infant: Under 3 years at travel date';
                                      } else if (i >= _adults) {
                                        // Child: 3-11 years (1095-4383 days)
                                        firstDate = _departureDate.subtract(
                                            const Duration(days: 4383));
                                        lastDate = _departureDate.subtract(
                                            const Duration(days: 1095));
                                        initialDate = _departureDate.subtract(
                                            const Duration(days: 2555));
                                        ageHint =
                                            'Child: 3-11 years at travel date';
                                      } else {
                                        // Adult: 12+ years (4383+ days)
                                        firstDate = DateTime(1920);
                                        lastDate = _departureDate.subtract(
                                            const Duration(days: 4383));
                                        initialDate = DateTime(1990);
                                        ageHint =
                                            'Adult: 12+ years at travel date';
                                      }

                                      return _buildDatePicker(
                                        label: 'Date of Birth',
                                        selectedDate: p.dateOfBirth,
                                        showError: p.submitted &&
                                            p.dateOfBirth == null,
                                        ageHint: ageHint,
                                        onTap: () async {
                                          // Ensure initialDate is within valid range
                                          DateTime safeInitialDate =
                                              initialDate;
                                          if (p.dateOfBirth != null) {
                                            if (p.dateOfBirth!
                                                .isBefore(firstDate)) {
                                              safeInitialDate = firstDate;
                                            } else if (p.dateOfBirth!
                                                .isAfter(lastDate)) {
                                              safeInitialDate = lastDate;
                                            } else {
                                              safeInitialDate = p.dateOfBirth!;
                                            }
                                          }

                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: safeInitialDate,
                                            firstDate: firstDate,
                                            lastDate: lastDate,
                                            helpText: ageHint,
                                            builder: (ctx, child) => Theme(
                                              data: Theme.of(ctx).copyWith(
                                                colorScheme:
                                                    const ColorScheme.light(
                                                        primary:
                                                            Color(0xFFD4AF37)),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked != null) {
                                            setState(
                                                () => p.dateOfBirth = picked);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                                // Only show CNIC for adults (not for children and infants)
                                if (i < _adults) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: p.cnicCtrl,
                                      label: 'CNIC',
                                      icon: Icons.article_outlined,
                                      hint: 'XXXXX-XXXXXXX-X',
                                      keyboardType: TextInputType.number,
                                      maxLength: 15,
                                      inputFormatters: [_CnicFormatter()],
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'CNIC is required';
                                        }
                                        final clean = v.replaceAll('-', '');
                                        if (clean.length != 13) {
                                          return 'Must be 13 digits';
                                        }
                                        // Uniqueness: no two passengers may share the same CNIC
                                        final entered = v.trim();
                                        for (int j = 0;
                                            j < _totalPassengers;
                                            j++) {
                                          if (j == i) continue;
                                          if (_passengers[j]
                                                  .cnicCtrl
                                                  .text
                                                  .trim() ==
                                              entered) {
                                            return 'This CNIC is already used for another passenger';
                                          }
                                        }
                                        return null;
                                      },
                                      fieldKey: p.documentKey,
                                    ),
                                  ),
                                ],
                                if (i >= _adults)
                                  const Expanded(child: SizedBox()),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Notice section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange.shade700, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Notice',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '1. Adults: 12+ years (Full fare)\n'
                                '2. Children: 3-11 years (50% discount)\n'
                                '3. Infants: Under 3 years (Free of charge)',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFB3B3B3),
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Save Details checkbox
                        GestureDetector(
                          onTap: () =>
                              setState(() => p.saveDetails = !p.saveDetails),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: p.saveDetails,
                                  onChanged: (v) => setState(
                                      () => p.saveDetails = v ?? false),
                                  activeColor: const Color(0xFFD4AF37),
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
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainCard({
    required TrainResult t,
    required String cls,
    required String fromCode,
    required String toCode,
    required String fromName,
    required String toName,
    required DateTime date,
  }) {
    const color = Color(0xFFD4AF37);
    final price = t.classPrices[cls];
    final depDate = DateFormat('dd MMM').format(date);
    final arrDate = t.arrivesNextDay
        ? '${DateFormat('dd MMM').format(date)} +1'
        : DateFormat('dd MMM').format(date);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
          // ── Header bar ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withValues(alpha: 0.07),
                  color.withValues(alpha: 0.03),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Train icon container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.train_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                // Train name + number · class
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.trainName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t.trainNumber}  ·  $cls',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Direct pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Direct',
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

          // ── Route section ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
            child: Column(
              children: [
                // Times row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.departureTime,
                        style: TextStyle(
                            fontSize: R.sp(context, 32),
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.5,
                            height: 1.0),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t.arrivalTime,
                        style: TextStyle(
                            fontSize: R.sp(context, 32),
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

                // Station codes + timeline row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // From code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        fromCode,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Timeline: dot — dashed — train icon — dashed — dot
                    Expanded(
                      child: Row(
                        children: [
                          // Left hollow dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2.2),
                              color: Colors.white,
                            ),
                          ),
                          // Left dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _DashedLinePainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Train icon (no rotation — unlike plane)
                          const Icon(Icons.train_rounded,
                              size: 28, color: color),
                          // Right dashed line
                          Expanded(
                            child: CustomPaint(
                              painter: _DashedLinePainter(
                                  color: Colors.grey.shade300),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                          // Right filled dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // To code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        toCode,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // City names + duration chip + dates
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fromName,
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
                    // Duration chip
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
                            t.duration,
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
                            toName,
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
                                color: t.arrivesNextDay
                                    ? Colors.orange.shade600
                                    : Colors.grey.shade400,
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

          // ── Footer: base fare per person ──────────────────────
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
                    price != null ? formatPKR(price) : 'N/A',
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

  Widget _buildContactPage() {
    return SingleChildScrollView(
      controller: _contactScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKeys[_totalPassengers],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.04),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.contact_phone_outlined,
                              color: Color(0xFFD4AF37), size: 18),
                        ),
                        const SizedBox(width: 10),
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
                        // Info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(color: Colors.orange, width: 3),
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
                          key: _contactNameKey,
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
                            if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(s)) {
                              return 'Letters only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DSInputField(
                          key: _contactEmailKey,
                          label: 'Email Address',
                          controller: _contactEmailCtrl,
                          hint: 'Enter email address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: DSValidators.email,
                        ),
                        const SizedBox(height: 14),
                        DSInputField(
                          key: _contactPhoneKey,
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
                ],
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ...List.generate(
                    _totalPassengers, (i) => _buildPassengerPage(i)),
                _buildContactPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final isContact = _isContactPage;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                    Text(isRoundTrip ? 'Total (Round Trip)' : 'Total',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    Text(
                      formatPKR(_calculateTotalPrice()),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
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
              Expanded(
                child: DSButton(
                  label: isContact ? 'CONFIRM' : 'NEXT',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onTap: isContact ? _submit : _goNext,
                  height: R.rh(context, 52),
                  color: const Color(0xFFD4AF37),
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  void _scrollToFirstPassengerError(int i) {
    final p = _passengers[i];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalKey? errorKey;
      if (p.firstNameKey.currentState?.errorText != null) {
        errorKey = p.firstNameKey;
      } else if (p.lastNameKey.currentState?.errorText != null) {
        errorKey = p.lastNameKey;
      } else if (p.dateOfBirth == null) {
        errorKey = p.dobKey;
      } else if (p.documentKey.currentState?.errorText != null) {
        errorKey = p.documentKey;
      }
      final ctx = errorKey?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    });
  }

  void _scrollToFirstContactError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checks = <(TextEditingController, GlobalKey)>[
        (_contactNameCtrl, _contactNameKey),
        (_contactEmailCtrl, _contactEmailKey),
        (_contactPhoneCtrl, _contactPhoneKey),
      ];
      for (final (ctrl, key) in checks) {
        if (ctrl.text.trim().isEmpty) {
          final ctx = key.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.15,
            );
          }
          return;
        }
      }
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? prefixText,
    String? helper,
    GlobalKey<FormFieldState>? fieldKey,
  }) {
    const color = Color(0xFFD4AF37);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ...?inputFormatters,
          ],
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            helperText: helper,
            helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
              borderSide: const BorderSide(color: color, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    bool showError = false,
    String? ageHint,
  }) {
    final hasError = showError && selectedDate == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                Icon(Icons.calendar_month_outlined,
                    size: 18,
                    color:
                        hasError ? Colors.red.shade400 : Colors.grey.shade500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('dd MMM yyyy').format(selectedDate)
                        : 'Select',
                    style: TextStyle(
                      fontSize: 13,
                      color: selectedDate != null
                          ? Colors.black87
                          : (hasError
                              ? Colors.red.shade300
                              : Colors.grey.shade400),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (ageHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(ageHint,
                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 11)),
          ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Date of birth is required',
                style: TextStyle(color: Colors.red.shade600, fontSize: 11)),
          ),
      ],
    );
  }
}

// ─────────────────── Data Model ───────────────────
class _TrainPassengerData {
  String salutation = 'Mr';
  String concessionType = 'ADULT'; // ADULT, CHILD_3_10, INFANT
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final cnicCtrl = TextEditingController();
  final bFormCtrl = TextEditingController();
  final passportNumberCtrl = TextEditingController();
  String nationality = 'Pakistan';
  String documentType = 'CNIC'; // CNIC, B-Form, Passport
  DateTime? dateOfBirth;
  bool saveDetails = false;
  bool submitted = false;

  // Keys for scroll-to-error
  final firstNameKey = GlobalKey<FormFieldState>();
  final lastNameKey = GlobalKey<FormFieldState>();
  final dobKey = GlobalKey();
  final documentKey = GlobalKey<FormFieldState>();

  Map<String, dynamic> toJson() => {
        'salutation': salutation,
        'concessionType': concessionType,
        'firstName': firstNameCtrl.text,
        'lastName': lastNameCtrl.text,
        'cnic': cnicCtrl.text,
        'bForm': bFormCtrl.text,
        'passportNumber': passportNumberCtrl.text,
        'nationality': nationality,
        'documentType': documentType,
        'dob': dateOfBirth?.toIso8601String(),
      };

  void fromJson(Map<String, dynamic> j) {
    salutation = j['salutation'] ?? 'Mr';
    concessionType = j['concessionType'] ?? 'ADULT';
    firstNameCtrl.text = j['firstName'] ?? '';
    lastNameCtrl.text = j['lastName'] ?? '';
    cnicCtrl.text = j['cnic'] ?? '';
    bFormCtrl.text = j['bForm'] ?? '';
    passportNumberCtrl.text = j['passportNumber'] ?? '';
    nationality = j['nationality'] ?? 'Pakistan';
    documentType = j['documentType'] ?? 'CNIC';
    final dob = j['dob'];
    if (dob != null) dateOfBirth = DateTime.tryParse(dob);
  }

  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    cnicCtrl.dispose();
    bFormCtrl.dispose();
    passportNumberCtrl.dispose();
  }
}

// ─────────────────── Formatters ───────────────────
class _CnicFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 13; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.startsWith('0') && newValue.text.length == 1) {
      return oldValue;
    }
    return newValue;
  }
}

// ─────────────────── Painters ───────────────────
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
