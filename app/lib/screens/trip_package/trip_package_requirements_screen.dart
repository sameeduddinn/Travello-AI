// FILE: screens/trip_package/trip_package_requirements_screen.dart
// PURPOSE: Step 1 of the native Trip Package flow — a structured form for
// origin, destination, dates, party size and preferences. Every field here
// is a native control (dropdown/stepper/date picker); nothing is inferred by
// an LLM. Submitting calls POST /trip-packages/search, which runs the same
// searches and composition (agents/trip_selection.build_options) a chat Trip
// Planner turn uses — see routers/trip_packages.py.

import 'dart:convert';

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';

/// ApiClient's error text carries the server's raw JSON body verbatim
/// (`"... HTTP 422 — {"error":true,"detail":"...",...}"`) — consistent with
/// every other API error in this app, but showing that raw dict to a
/// traveller looks broken. Pull out just `detail` when the message is
/// shaped that way; fall back to the raw text for anything else (a genuine
/// network/timeout error has no JSON body to parse).
String _friendlyError(Object e) {
  final raw = e.toString().replaceFirst('Exception: ', '');
  final braceIndex = raw.indexOf('{');
  if (braceIndex != -1) {
    try {
      final parsed = jsonDecode(raw.substring(braceIndex));
      if (parsed is Map && parsed['detail'] is String) {
        return parsed['detail'] as String;
      }
    } catch (_) {
      // Not JSON, or shaped differently -- fall through to the raw text.
    }
  }
  return raw;
}

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFEF9EC);
const _goldDark = Color(0xFFB8935C);

class _Destination {
  final String name;
  final String subtitle;
  final IconData icon;
  const _Destination(this.name, this.subtitle, this.icon);
}

// The engine behind /trip-packages/search (agents/trip_selection.py) only
// ever composes a package for these four — see services/northern_routes.py's
// NORTHERN_DESTINATIONS. Confirmed from source, not a UI-only restriction.
const _destinations = [
  _Destination('Naran', 'Kaghan Valley', Icons.terrain),
  _Destination('Hunza', 'Karakoram peaks', Icons.landscape),
  _Destination('Swat', 'Switzerland of Pakistan', Icons.forest),
  _Destination('Skardu', 'Gateway to K2', Icons.filter_hdr),
];

class TripPackageRequirementsScreen extends StatefulWidget {
  const TripPackageRequirementsScreen({super.key});

  @override
  State<TripPackageRequirementsScreen> createState() =>
      _TripPackageRequirementsScreenState();
}

class _TripPackageRequirementsScreenState
    extends State<TripPackageRequirementsScreen> {
  String? _destination;
  String? _origin;
  DateTime? _travelDate;
  int _nights = 2;
  int _travelers = 2;
  String _preferredMode = 'flight';
  String _cabinClass = 'ECONOMY';
  int? _minHotelStars;
  bool _searching = false;
  String? _error;

  static final _originCities = airportList.map((a) => a.location).toSet().toList()
    ..sort();

  Future<void> _pickTravelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _travelDate = picked);
  }

  bool get _canSearch =>
      _destination != null &&
      _origin != null &&
      _travelDate != null &&
      !_searching;

  Future<void> _search() async {
    if (!_canSearch) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await ApiClient.searchTripPackage(
        origin: _origin!,
        destination: _destination!,
        travelDate: DateFormat('yyyy-MM-dd').format(_travelDate!),
        nights: _nights,
        travelers: _travelers,
        preferredMode: _preferredMode,
        cabinClass: _preferredMode == 'flight' ? _cabinClass : null,
        minHotelStars: _minHotelStars,
      );
      if (!mounted) return;
      await Get.toNamed(AppLink.tripPackageOptions, arguments: {
        'conversationId': result['conversation_id'],
        'options': Map<String, dynamic>.from(result['options'] as Map),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      appBar: AppBar(
        backgroundColor: _gold,
        elevation: 0,
        title: const Text('Trip Package',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Where are you headed?', style: TravelloTheme.title2
                .copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: spacingUnit(0.5)),
            Text(
              'One flight or train, one hotel and — where the road runs on '
              'from a hub city — one transfer, priced and booked together.',
              style: TravelloTheme.caption.copyWith(color: Colors.grey.shade600),
            ),
            SizedBox(height: spacingUnit(1.5)),
            _destinationGrid(),
            SizedBox(height: spacingUnit(1.5)),
            _sectionLabel('Departure city'),
            _originDropdown(),
            SizedBox(height: spacingUnit(1.25)),
            _sectionLabel('How are you travelling?'),
            _modeSelector(),
            SizedBox(height: spacingUnit(1.25)),
            if (_preferredMode == 'flight') ...[
              _sectionLabel('Cabin class'),
              _cabinDropdown(),
              SizedBox(height: spacingUnit(1.25)),
            ],
            _sectionLabel('Travel date'),
            _datePickerField(),
            SizedBox(height: spacingUnit(1.25)),
            _sectionLabel('Nights at destination'),
            _stepperField(
              value: _nights,
              min: 1,
              max: 14,
              onChanged: (v) => setState(() => _nights = v),
            ),
            SizedBox(height: spacingUnit(1.25)),
            _sectionLabel('Travellers'),
            _stepperField(
              value: _travelers,
              min: 1,
              max: 9,
              onChanged: (v) => setState(() => _travelers = v),
            ),
            SizedBox(height: spacingUnit(1.25)),
            _sectionLabel('Minimum hotel rating (optional)'),
            _starsDropdown(),
            if (_error != null) ...[
              SizedBox(height: spacingUnit(1)),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ),
                ]),
              ),
            ],
            SizedBox(height: spacingUnit(2)),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSearch ? _search : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  disabledBackgroundColor: _gold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _searching
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Search Packages',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: EdgeInsets.only(bottom: spacingUnit(0.5)),
        child: Text(text,
            style: TravelloTheme.caption
                .copyWith(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
      );

  Widget _destinationGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: _destinations.map((d) {
        final selected = _destination == d.name;
        return GestureDetector(
          onTap: () => setState(() => _destination = d.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? _gold : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? _gold : Colors.grey.shade300, width: 1.5),
              boxShadow: selected
                  ? [BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(d.icon, color: selected ? Colors.white : _goldDark, size: 26),
                const SizedBox(height: 6),
                Text(d.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: selected ? Colors.white : Colors.black87)),
                Text(d.subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white70 : Colors.grey.shade500)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _originDropdown() {
    return _fieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _origin,
          isExpanded: true,
          hint: const Text('Select departure city'),
          items: _originCities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _origin = v),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Row(children: [
      Expanded(child: _modeChip('flight', 'Flight', Icons.flight)),
      const SizedBox(width: 10),
      Expanded(child: _modeChip('train', 'Train', Icons.train)),
    ]);
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final selected = _preferredMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _preferredMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _goldLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _gold : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? _goldDark : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? _goldDark : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _cabinDropdown() {
    const options = ['ECONOMY', 'BUSINESS', 'FIRST'];
    return _fieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _cabinClass,
          isExpanded: true,
          items: options
              .map((c) => DropdownMenuItem(
                  value: c, child: Text(c[0] + c.substring(1).toLowerCase())))
              .toList(),
          onChanged: (v) => setState(() => _cabinClass = v ?? 'ECONOMY'),
        ),
      ),
    );
  }

  Widget _starsDropdown() {
    return _fieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _minHotelStars,
          isExpanded: true,
          hint: const Text('Any rating'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any rating')),
            ...[3, 4, 5].map((s) =>
                DropdownMenuItem(value: s, child: Text('$s★ and above'))),
          ],
          onChanged: (v) => setState(() => _minHotelStars = v),
        ),
      ),
    );
  }

  Widget _datePickerField() {
    return GestureDetector(
      onTap: _pickTravelDate,
      child: _fieldShell(
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: _goldDark),
          const SizedBox(width: 10),
          Text(
            _travelDate == null
                ? 'Select date'
                : DateFormat('d MMM yyyy').format(_travelDate!),
            style: TextStyle(
                color: _travelDate == null ? Colors.grey.shade500 : Colors.black87,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  Widget _stepperField({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return _fieldShell(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Row(children: [
            _stepBtn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
            const SizedBox(width: 8),
            _stepBtn(Icons.add, value < max ? () => onChanged(value + 1) : null),
          ]),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade100 : _goldLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: onTap == null ? Colors.grey.shade400 : _goldDark),
      ),
    );
  }

  Widget _fieldShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }
}
