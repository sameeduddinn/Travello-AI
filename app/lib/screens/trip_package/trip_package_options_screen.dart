// FILE: screens/trip_package/trip_package_options_screen.dart
// PURPOSE: Step 2 of the native Trip Package flow — the real transport,
// hotel and (where it applies) transfer options POST /trip-packages/search
// returned, exactly as agents/trip_selection.build_options() composed them.
// Every price here is server-priced; nothing is invented or recomputed on
// the client. The traveller picks one from each list — mirrors the chat Trip
// Planner's "Flight 2, Hotel 1, SUV" selection, just as native controls.

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';

const _gold = Color(0xFFD4AF37);
const _goldDark = Color(0xFFB8935C);
final _moneyFmt = NumberFormat('#,##0', 'en_US');

String _money(num v) => 'PKR ${_moneyFmt.format(v)}';

class TripPackageOptionsScreen extends StatefulWidget {
  const TripPackageOptionsScreen({super.key});

  @override
  State<TripPackageOptionsScreen> createState() =>
      _TripPackageOptionsScreenState();
}

class _TripPackageOptionsScreenState extends State<TripPackageOptionsScreen> {
  late final String _conversationId;
  late final Map<String, dynamic> _options;
  final Map<String, int> _picks = {};
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _conversationId = (args['conversationId'] as String?) ?? '';
    _options = Map<String, dynamic>.from(
        (args['options'] as Map?) ?? const {});
  }

  List<Map<String, dynamic>> get _transport =>
      ((_options['transport'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<Map<String, dynamic>> get _hotels =>
      ((_options['hotels'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<Map<String, dynamic>> get _transfers =>
      ((_options['transfers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  bool get _needsTransfer => _transfers.isNotEmpty;

  bool get _complete =>
      _picks.containsKey('transport') &&
      _picks.containsKey('hotel') &&
      (!_needsTransfer || _picks.containsKey('transfer'));

  num get _total {
    num sum = 0;
    final t = _picks['transport'];
    if (t != null && t >= 1 && t <= _transport.length) {
      sum += (_transport[t - 1]['price_pkr'] as num?) ?? 0;
    }
    final h = _picks['hotel'];
    if (h != null && h >= 1 && h <= _hotels.length) {
      sum += (_hotels[h - 1]['price_pkr'] as num?) ?? 0;
    }
    final tr = _picks['transfer'];
    if (tr != null && tr >= 1 && tr <= _transfers.length) {
      sum += (_transfers[tr - 1]['fare_pkr'] as num?) ?? 0;
    }
    return sum;
  }

  Future<void> _continue() async {
    if (!_complete || _navigating) return;
    setState(() => _navigating = true);
    try {
      String? pickupLocation;
      if (_needsTransfer) {
        final transfer = _transfers[_picks['transfer']! - 1];
        final result = await Get.toNamed(
          AppLink.tripPackageTransferDetails,
          arguments: {
            'vehicle': transfer['vehicle'],
            'hub': transfer['hub'],
            'destination': transfer['destination'],
            'farePkr': transfer['fare_pkr'],
          },
        );
        if (result is! Map) return;   // traveller backed out
        pickupLocation = (result['pickupLocation'] as String?)?.trim();
        if (pickupLocation == null || pickupLocation.isEmpty) return;
      }
      if (!mounted) return;
      await Get.toNamed(AppLink.tripPackageReview, arguments: {
        'conversationId': _conversationId,
        'options': _options,
        'picks': Map<String, int>.from(_picks),
        'pickupLocation': pickupLocation,
      });
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = (_options['destination'] as String?) ?? '';
    final isFlight = (_options['transport_kind'] as String?) == 'flight';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      appBar: AppBar(
        backgroundColor: _gold,
        elevation: 0,
        title: Text('$destination Package',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader(isFlight ? 'Flights' : 'Trains',
                    isFlight ? Icons.flight : Icons.train),
                ..._transport.asMap().entries.map((e) => _transportCard(
                    e.key + 1, e.value, isFlight, _picks['transport'] == e.key + 1)),
                const SizedBox(height: 20),
                _sectionHeader('Hotels', Icons.hotel),
                ..._hotels.asMap().entries.map((e) => _hotelCard(
                    e.key + 1, e.value, _picks['hotel'] == e.key + 1)),
                if (_needsTransfer) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('Hub Transfer', Icons.directions_car),
                  ..._transfers.asMap().entries.map((e) => _transferCard(
                      e.key + 1, e.value, _picks['transfer'] == e.key + 1)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          _bottomBar(),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: _goldDark),
        const SizedBox(width: 8),
        Text(title,
            style: TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _selectableCard({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? _gold : Colors.grey.shade300,
                width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _radioMark(bool selected) => Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? _gold : Colors.grey.shade300,
        size: 22,
      );

  Widget _transportCard(int index, Map<String, dynamic> row, bool isFlight, bool selected) {
    final route = (row['origin'] as String?)?.isNotEmpty == true
        ? '${row['origin']} → ${row['destination']}'
        : '';
    final when = [row['depart'], row['arrive']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' → ');
    final extra = (row['cabin'] as String?) ?? (row['travel_class'] as String?) ?? '';
    return _selectableCard(
      selected: selected,
      onTap: () => setState(() => _picks['transport'] = index),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['label'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              if (route.isNotEmpty)
                Text(route, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (when.isNotEmpty)
                Text(when, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (extra.isNotEmpty)
                Text(extra,
                    style: const TextStyle(
                        fontSize: 11, color: _goldDark, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money((row['price_pkr'] as num?) ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          _radioMark(selected),
        ]),
      ]),
    );
  }

  Widget _hotelCard(int index, Map<String, dynamic> row, bool selected) {
    final stars = (row['stars'] as num?) ?? 0;
    final nights = (row['nights'] as num?) ?? 0;
    return _selectableCard(
      selected: selected,
      onTap: () => setState(() => _picks['hotel'] = index),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['name'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Row(children: [
                if (stars > 0) ...[
                  const Icon(Icons.star, size: 13, color: _gold),
                  Text(' ${stars.toStringAsFixed(stars % 1 == 0 ? 0 : 1)} · ',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
                if (nights > 0)
                  Text('$nights night${nights != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money((row['price_pkr'] as num?) ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          _radioMark(selected),
        ]),
      ]),
    );
  }

  Widget _transferCard(int index, Map<String, dynamic> row, bool selected) {
    final estimated = row['estimated'] == true;
    return _selectableCard(
      selected: selected,
      onTap: () => setState(() => _picks['transfer'] = index),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['vehicle'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${row['hub']} → ${row['destination']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (row['note'] != null)
                Text(row['note'] as String,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money((row['fare_pkr'] as num?) ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (estimated)
            Text('Estimated',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          _radioMark(selected),
        ]),
      ]),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total', style: TravelloTheme.caption.copyWith(color: Colors.grey.shade600)),
                Text(_money(_total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18, color: _goldDark)),
              ],
            ),
          ),
          SizedBox(
            width: 160,
            height: 48,
            child: ElevatedButton(
              onPressed: _complete && !_navigating ? _continue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: _gold.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _navigating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Continue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
