// FILE: screens/trip_package/trip_package_review_screen.dart
// PURPOSE: Step 4 (Review) through Step 6 (My Bookings) of the native Trip
// Package flow, in one screen — mirroring how the AI Assistant chat flow
// already sequences these same steps (package_choice -> passenger form ->
// CardPaymentSheet -> My Bookings), just triggered by a button instead of a
// chat reply. On load, calls POST /trip-packages/confirm, which drives the
// SAME deterministic verification/repricing engine
// (agents.master_agent.complete_trip_planner_confirmation) the chat flow
// uses — the total shown here is never computed on this screen, only
// displayed. Passenger collection reuses the existing agentMode forms via
// the shared widgets/booking/card_payment_sheet.dart helpers; payment reuses
// the exact same CardPaymentSheet chat already uses — no second booking or
// payment implementation.

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/widgets/booking/card_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFEF9EC);
const _goldDark = Color(0xFFB8935C);
final _moneyFmt = NumberFormat('#,##0', 'en_US');

String _money(num v) => 'PKR ${_moneyFmt.format(v)}';

class TripPackageReviewScreen extends StatefulWidget {
  const TripPackageReviewScreen({super.key});

  @override
  State<TripPackageReviewScreen> createState() => _TripPackageReviewScreenState();
}

class _TripPackageReviewScreenState extends State<TripPackageReviewScreen> {
  late final String _conversationId;
  late final Map<String, int> _picks;
  String? _pickupLocation;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _bookingData;

  List<Map<String, dynamic>>? _agentPassengers;
  Map<String, dynamic>? _agentContact;
  bool _collectingPassengers = false;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _conversationId = (args['conversationId'] as String?) ?? '';
    _picks = Map<String, int>.from((args['picks'] as Map?) ?? const {});
    _pickupLocation = args['pickupLocation'] as String?;
    _confirm();
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient.confirmTripPackage(
        conversationId: _conversationId,
        picks: _picks,
        pickupLocation: _pickupLocation,
      );
      if (!mounted) return;
      setState(() {
        _bookingData = Map<String, dynamic>.from(result['booking_data'] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _components =>
      ((_bookingData?['components'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// Same sequence _AIAssistantScreenState uses: collect passengers via the
  /// existing agentMode form for the identity-heavy component (flight, then
  /// train, then hotel), then open the shared payment sheet.
  Future<void> _confirmAndPay() async {
    final data = _bookingData;
    if (data == null || _collectingPassengers) return;
    final primary = primaryComponent(data);
    final type = primary['booking_type'] as String? ?? 'flight';
    // This screen only exists for a Trip Package (2+ components: transport
    // + hotel, plus an optional transfer and/or return leg), so the
    // passenger form should show the real trip total, not just the primary
    // component's own price.
    final packageTotal = (data['total_price_pkr'] as num?)?.toDouble();

    setState(() => _collectingPassengers = true);
    dynamic result;
    try {
      switch (type) {
        case 'train':
          result = await Get.toNamed('/train-passengers',
              arguments: trainFormArgs(primary, packageTotalPkr: packageTotal));
          break;
        case 'hotel':
          result = await Get.toNamed(AppLink.hotelGuestForm,
              arguments: hotelFormArgs(primary, packageTotalPkr: packageTotal));
          break;
        default:
          result = await Get.toNamed(AppLink.bookingStep1,
              arguments: flightFormArgs(primary, packageTotalPkr: packageTotal));
      }
    } finally {
      if (mounted) setState(() => _collectingPassengers = false);
    }

    if (!mounted || result is! Map) return;
    final res = Map<String, dynamic>.from(result);
    final passengers = List<Map<String, dynamic>>.from(
      (res['passengers'] as List? ?? const [])
          .map((p) => Map<String, dynamic>.from(p as Map)),
    );
    if (passengers.isEmpty) return;

    setState(() {
      _agentPassengers = passengers;
      _agentContact = {
        for (final k in [
          'contactName', 'contactEmail', 'contactPhone',
          'emergencyName', 'emergencyEmail', 'emergencyPhone', 'emergencyRelation',
        ])
          if ((res[k] as String?)?.isNotEmpty ?? false) k: res[k],
      };
    });

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardPaymentSheet(
        bookingData: data,
        conversationId: _conversationId,
        passengers: _agentPassengers,
        contact: _agentContact,
        onSuccess: (pnr, amount) {
          // AppLink.myTicket -> MyBookings(), the screen with package
          // grouping (Phase 1). AppLink.orderHistory is a different, legacy
          // screen (routes_booking.dart -> OrderHistory()) left over from
          // the purchased UI kit -- it crashes on real data (confirmed: a
          // RangeError from its own mock bookingList()/passengerList()/
          // userList() generators), which is what the user hit.
          Get.offAllNamed(AppLink.myTicket);
          Get.snackbar(
            'Package Confirmed!',
            'PNR: $pnr · Paid ${_money(amount)}. A confirmation email is on its way.',
            backgroundColor: _gold,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        },
        onCancel: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5E8),
      appBar: AppBar(
        backgroundColor: _gold,
        elevation: 0,
        title: const Text('Review Your Trip',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _gold),
            SizedBox(height: 16),
            Text('Verifying your package with the latest prices…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.until(
                    (r) => r.settings.name == AppLink.tripPackageRequirements || r.isFirst),
                style: ElevatedButton.styleFrom(backgroundColor: _gold),
                child: const Text('Search Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _bookingData!;
    final total = (data['total_price_pkr'] as num?) ?? 0;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _goldLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.verified, color: _goldDark, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prices verified just now — this is exactly what you will pay.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            ..._components.map(_componentTile),
            const SizedBox(height: 8),
          ],
        ),
      ),
      _bottomBar(total),
    ]);
  }

  Widget _componentTile(Map<String, dynamic> c) {
    final type = c['booking_type'] as String? ?? '';
    IconData icon;
    String title;
    String subtitle;
    switch (type) {
      case 'hotel':
        icon = Icons.hotel;
        title = (c['hotel_name'] as String?) ?? 'Hotel';
        subtitle = '${c['check_in'] ?? ''} → ${c['check_out'] ?? ''}';
        break;
      case 'train':
        icon = Icons.train;
        title = (c['train_name'] as String?) ?? 'Train';
        subtitle = '${c['origin'] ?? ''} → ${c['destination'] ?? ''}';
        break;
      default:
        icon = Icons.flight;
        title = (c['flight_number'] as String?) ?? 'Flight';
        subtitle = '${c['origin'] ?? ''} → ${c['destination'] ?? ''}';
    }
    final transferVehicle = c['transfer_vehicle_type'] as String?;
    final transferFare = (c['transfer_pkr'] as num?) ?? 0;
    final totalPrice = (c['total_price_pkr'] as num?) ?? 0;
    // total_price_pkr already has the transfer fare folded in (see backend
    // agent_tools._add_transfer_fare) -- the actual charge is unaffected by
    // this screen either way. Subtract it back out ONLY for display, so this
    // line shows what the flight/train alone costs and the transfer gets its
    // own priced line below, mirroring format_package_summary's
    // _component_amount() split in the chat flow exactly, instead of
    // silently folding the transfer's cost into the flight line.
    final componentPrice = totalPrice - transferFare;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _goldLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _goldDark, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                if (subtitle.trim().isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(_money(componentPrice), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        if (transferVehicle != null) ...[
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.directions_car, size: 16, color: _goldDark),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$transferVehicle transfer: ${c['transfer_pickup_location'] ?? ''} → ${c['transfer_dropoff_location'] ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Text(_money(transferFare),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ],
      ]),
    );
  }

  Widget _bottomBar(num total) {
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
                Text('Package Total', style: TravelloTheme.caption.copyWith(color: Colors.grey.shade600)),
                Text(_money(total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _goldDark)),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            height: 48,
            child: ElevatedButton(
              onPressed: _collectingPassengers ? null : _confirmAndPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: _gold.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _collectingPassengers
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Confirm & Pay',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
