import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CarBookingForm extends StatefulWidget {
  const CarBookingForm({super.key});

  @override
  State<CarBookingForm> createState() => _CarBookingFormState();
}

class _CarBookingFormState extends State<CarBookingForm> {
  final _pickupCtrl  = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  String _vehicleType = 'Sedan';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  static const _vehicles = [
    {'type': 'Sedan', 'price': 800,  'icon': CupertinoIcons.car_detailed},
    {'type': 'SUV',   'price': 1200, 'icon': CupertinoIcons.car_detailed},
    {'type': 'Van',   'price': 1500, 'icon': CupertinoIcons.bus},
  ];

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  int get _currentPrice {
    final v = _vehicles.firstWhere((e) => e['type'] == _vehicleType, orElse: () => _vehicles.first);
    return v['price'] as int;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: TravelloTheme.primaryMain),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: TravelloTheme.primaryMain),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final pickup  = _pickupCtrl.text.trim();
    final dropoff = _dropoffCtrl.text.trim();

    if (pickup.isEmpty || dropoff.isEmpty) {
      Get.snackbar(
        'Missing Information',
        'Please enter both pickup and dropoff locations.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      Get.snackbar(
        'Missing Information',
        'Please select a pickup date and time.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isLoading = true);

    final pickupDt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      final result = await ApiClient.bookCar(
        pickupLocation:  pickup,
        dropoffLocation: dropoff,
        vehicleType:     _vehicleType,
        pickupDatetime:  pickupDt.toIso8601String(),
      );

      if (mounted) {
        _showConfirmation(result);
        // Reset form
        _pickupCtrl.clear();
        _dropoffCtrl.clear();
        setState(() {
          _vehicleType  = 'Sedan';
          _selectedDate = null;
          _selectedTime = null;
        });
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Booking Failed',
          e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showConfirmation(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarConfirmationSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.car_detailed,
                    color: TravelloTheme.primaryMain,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a Driver',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      'Professional drivers across Pakistan',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Pickup location ────────────────────────────────────────
            _LocationField(
              controller: _pickupCtrl,
              label: 'Pickup Location',
              hint: 'e.g. Gulberg, Lahore',
              icon: CupertinoIcons.location_fill,
              iconColor: TravelloTheme.primaryMain,
            ),

            const SizedBox(height: 12),

            // ── Dropoff location ───────────────────────────────────────
            _LocationField(
              controller: _dropoffCtrl,
              label: 'Dropoff Location',
              hint: 'e.g. Allama Iqbal Airport',
              icon: CupertinoIcons.location,
              iconColor: Colors.red.shade400,
            ),

            const SizedBox(height: 18),

            // ── Vehicle type ───────────────────────────────────────────
            Text(
              'Vehicle Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _vehicles.map((v) {
                final type     = v['type'] as String;
                final price    = v['price'] as int;
                final isActive = _vehicleType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _vehicleType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(
                        right: type == 'Van' ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? TravelloTheme.primaryMain
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? TravelloTheme.primaryMain
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: TravelloTheme.primaryMain
                                      .withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            v['icon'] as IconData,
                            size: 20,
                            color: isActive ? Colors.white : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            'PKR ${fmt.format(price)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // ── Date & Time ────────────────────────────────────────────
            Text(
              'Pickup Date & Time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    icon: CupertinoIcons.calendar,
                    label: _selectedDate != null
                        ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                        : 'Select Date',
                    isSet: _selectedDate != null,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTimeButton(
                    icon: CupertinoIcons.clock,
                    label: _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Select Time',
                    isSet: _selectedTime != null,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── Book Now button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  disabledBackgroundColor: TravelloTheme.primaryMain.withValues(alpha: 0.5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.car_detailed,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Book Now  —  PKR ${fmt.format(_currentPrice)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Location text field
// ─────────────────────────────────────────────────────────────────────────────
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;

  const _LocationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: iconColor, size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TravelloTheme.primaryMain, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Date / Time selector button
// ─────────────────────────────────────────────────────────────────────────────
class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSet;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.isSet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSet
              ? TravelloTheme.primaryMain.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet ? TravelloTheme.primaryMain.withValues(alpha: 0.4) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSet ? TravelloTheme.primaryMain : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                  color: isSet ? Colors.grey.shade800 : Colors.grey.shade400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Booking confirmation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CarConfirmationSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CarConfirmationSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final driver   = (data['driver'] as Map?)?.cast<String, dynamic>() ?? {};
    final code     = data['verification_code'] as String? ?? '----';
    final pickup   = data['pickup_location'] as String? ?? '';
    final dropoff  = data['dropoff_location'] as String? ?? '';
    final vType    = data['vehicle_type'] as String? ?? '';
    final amount   = data['total_amount'] as int? ?? 0;
    final fmt      = NumberFormat('#,##0', 'en_US');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Success icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 40),
            ),

            const SizedBox(height: 12),
            Text(
              'Driver Assigned!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your booking is confirmed. Check your email for details.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Verification code box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'VERIFICATION CODE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share this code with your driver to verify identity',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Driver details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DriverRow(
                    icon: CupertinoIcons.person_fill,
                    label: 'Driver',
                    value: driver['name'] as String? ?? '—',
                  ),
                  _DriverRow(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Phone',
                    value: driver['phone'] as String? ?? '—',
                  ),
                  _DriverRow(
                    icon: CupertinoIcons.car_detailed,
                    label: 'Vehicle',
                    value: '${driver['vehicle_color'] ?? ''} ${driver['vehicle_make'] ?? ''} ${driver['vehicle_model'] ?? ''}'.trim(),
                  ),
                  _DriverRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Plate',
                    value: driver['vehicle_plate'] as String? ?? '—',
                  ),
                  if ((driver['rating'] as num?) != null)
                    _DriverRow(
                      icon: Icons.star_rounded,
                      label: 'Rating',
                      value: '${(driver['rating'] as num).toStringAsFixed(1)} ★',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Trip details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _DriverRow(
                    icon: CupertinoIcons.location_fill,
                    label: 'Pickup',
                    value: pickup,
                  ),
                  _DriverRow(
                    icon: CupertinoIcons.location,
                    label: 'Dropoff',
                    value: dropoff,
                  ),
                  _DriverRow(
                    icon: CupertinoIcons.car_detailed,
                    label: 'Vehicle',
                    value: vType,
                  ),
                  _DriverRow(
                    icon: Icons.payments_outlined,
                    label: 'Fare',
                    value: 'PKR ${fmt.format(amount)}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DriverRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: TravelloTheme.primaryMain),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
