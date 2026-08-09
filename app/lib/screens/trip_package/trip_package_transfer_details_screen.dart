// FILE: screens/trip_package/trip_package_transfer_details_screen.dart
// PURPOSE: The minimum new UI the Trip Package flow needs that has no
// existing reusable form: the hub pickup address for the package's
// hub->destination car transfer. Vehicle and drop-off are already known
// (they came from the pick on the Options screen) — this collects only the
// one thing that isn't: where to collect the traveller from.

import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFEF9EC);
const _goldDark = Color(0xFFB8935C);

class TripPackageTransferDetailsScreen extends StatefulWidget {
  const TripPackageTransferDetailsScreen({super.key});

  @override
  State<TripPackageTransferDetailsScreen> createState() =>
      _TripPackageTransferDetailsScreenState();
}

class _TripPackageTransferDetailsScreenState
    extends State<TripPackageTransferDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? const {};
    final vehicle = (args['vehicle'] as String?) ?? 'Vehicle';
    final hub = (args['hub'] as String?) ?? 'the hub';
    final destination = (args['destination'] as String?) ?? '';
    final farePkr = (args['farePkr'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      appBar: AppBar(
        backgroundColor: _gold,
        elevation: 0,
        title: const Text('Transfer Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _goldLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.directions_car, color: _goldDark, size: 20),
                      const SizedBox(width: 8),
                      Text('$vehicle transfer',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                    const SizedBox(height: 8),
                    Text('$hub → $destination',
                        style: TextStyle(color: Colors.grey.shade700)),
                    if (farePkr > 0) ...[
                      const SizedBox(height: 4),
                      Text('PKR ${farePkr.toString().replaceAllMapped(
                            RegExp(r'\B(?=(\d{3})+(?!\d))'),
                            (m) => ',',
                          )}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: _goldDark)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Where should the driver collect you from at $hub?',
                  style: TravelloTheme.paragraph
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pickupCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. $hub Airport, Arrivals',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'Enter a real pickup address'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Contact number for the driver (optional)',
                  style: TravelloTheme.paragraph
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '03xx xxxxxxx',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    Get.back(result: {
                      'pickupLocation': _pickupCtrl.text.trim(),
                      'contactPhone': _contactPhoneCtrl.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
