// FILE: widgets/booking/card_payment_sheet.dart
// PURPOSE: The one card-payment implementation for an agent-created booking
// or package (flight/train/hotel/+car-transfer), shared between the AI
// Assistant chat flow and the Trip Package UI. Extracted out of
// ai_assistant.dart so there is exactly one payment engine, not one per
// entry point — both callers end up on the same POST /payments/initiate,
// package-aware backend path.

import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/hotel.dart' show Hotel;
import 'package:flight_app/screens/flight/flight_results_screen.dart' show FlightResult;
import 'package:flight_app/screens/railway/train_results_screen.dart' show TrainResult;
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Builds the /agent/book `facilities` map from a verified booking_data's
/// transfer fields, using the SAME key names the manual booking forms use
/// (transferAdded / transferVehicleType / transferPickupLocation) so the
/// backend's post-payment book_car_transfers task confirms the driver exactly
/// as it does for a manual booking. Returns null when no transfer was accepted.
Map<String, dynamic>? agentTransferFacilities(Map<String, dynamic> data) {
  final vehicle = (data['transfer_vehicle_type'] as String?)?.trim();
  final pickup = (data['transfer_pickup_location'] as String?)?.trim();
  if (vehicle == null || vehicle.isEmpty || pickup == null || pickup.isEmpty) {
    return null;
  }
  final dropoff = (data['transfer_dropoff_location'] as String?)?.trim();
  return {
    'transferAdded': true,
    'transferVehicleType': vehicle,
    'transferPickupLocation': pickup,
    if (dropoff != null && dropoff.isNotEmpty) 'transferDropoffLocation': dropoff,
  };
}

/// The bookable pieces inside a `package_choice` payload, or the payload itself
/// when it's an ordinary single booking.
///
/// A package arrives as {booking_type: 'package', components: [...]} where every
/// component was already gated and server-repriced exactly like a standalone
/// booking. Flattening to a list here means the commit path is ONE loop that
/// behaves identically for both shapes — a single booking is just a package of
/// one — so the proven create -> passengers -> pay sequence is never duplicated.
List<Map<String, dynamic>> packageComponents(Map<String, dynamic> data) {
  final raw = data['components'];
  if (raw is List) {
    final parsed = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (parsed.isNotEmpty) return parsed;
  }
  return [data];
}

/// The component whose form should collect the travelers for a whole package.
///
/// Travelers are entered ONCE, on the form belonging to the most identity-heavy
/// piece: a flight (then a train) needs full passenger identity, and those same
/// people are then reused for the hotel and the car transfer. Returns the payload
/// itself for an ordinary single booking.
Map<String, dynamic> primaryComponent(Map<String, dynamic> data) {
  final components = packageComponents(data);
  if (components.length == 1) return components.first;
  for (final type in const ['flight', 'train', 'hotel']) {
    for (final c in components) {
      if (c['booking_type'] == type) return c;
    }
  }
  return components.first;
}

/// Short human label for a component, used in the multi-PNR confirmation.
String componentLabel(Map<String, dynamic> c) {
  switch (c['booking_type'] as String?) {
    case 'flight':
      return 'Flight';
    case 'train':
      return 'Train';
    case 'hotel':
      return 'Hotel';
    default:
      return 'Booking';
  }
}

/// How many of a count field a component carries, defaulting when absent.
int countOf(Map<String, dynamic> data, String key, int fallback) =>
    (data[key] as num?)?.toInt() ?? fallback;

/// Per-person fare for the native passenger/checkout screens.
///
/// Those screens treat a flight/train price as PER-PERSON and multiply it by
/// the passenger count (booking_passengers `_calculateTotalPrice`,
/// booking_payment `_baseFare`, the train form's per-passenger loop). A
/// verified component's `total_price_pkr` is already the WHOLE-PARTY total,
/// so passing it in raw made those screens show — and would charge — it × pax:
/// a PKR 29,116 fare for 2 adults rendered as PKR 58,232. Divide it back to
/// per-person so the screen's multiply reconciles to the real total. The
/// actual charge (CardPaymentSheet, above) uses `total_price_pkr` directly and
/// is unaffected by this.
double perSeatFromTotal(Map<String, dynamic> data) {
  final pax = (countOf(data, 'adults', 1) +
          countOf(data, 'children', 0) +
          countOf(data, 'infants', 0))
      .clamp(1, 99);
  return (((data['total_price_pkr'] as num?) ?? 0).toDouble()) / pax;
}

/// Args for booking_passengers.dart's agentMode hand-off, built from one
/// verified flight component — the SAME map shape a prepare_booking gate
/// verifies and reprice_booking returns, whether it arrived via the AI
/// Assistant chat flow or the Trip Package UI's /trip-packages/confirm.
Map<String, dynamic> flightFormArgs(Map<String, dynamic> data) {
  Airport lookup(String city, String fallbackCode) => airportList.firstWhere(
        (a) =>
            a.location.toLowerCase() == city.toLowerCase() ||
            a.code.toLowerCase() == city.toLowerCase(),
        orElse: () =>
            Airport(id: '0', code: fallbackCode, name: city, location: city),
      );
  final flight = FlightResult(
    id: (data['flight_number'] as String?) ?? 'AGENT',
    airlineName: (data['airline_or_train_name'] as String?) ??
        (data['selected_option'] as String?) ??
        'Selected Flight',
    airlineCode: '',
    airlineLogo: '',
    departureTime: (data['departure_time'] as String?) ?? '--:--',
    arrivalTime: (data['arrival_time'] as String?) ?? '--:--',
    duration: '--',
    stops: 0,
    stopCities: const [],
    price: perSeatFromTotal(data),
    isRefundable: false,
    cabinClass: (data['cabin_class'] as String?) ?? 'Economy',
    flightNumber: data['flight_number'] as String?,
  );
  return {
    'agentMode': true,
    'flight': flight,
    'searchParams': {
      'fromAirport': lookup((data['origin'] as String?) ?? '', 'DEP'),
      'toAirport': lookup((data['destination'] as String?) ?? '', 'ARR'),
      'departureDate':
          DateTime.tryParse((data['travel_date'] as String?) ?? '') ??
              DateTime.now(),
      'adults': countOf(data, 'adults', 1),
      'children': countOf(data, 'children', 0),
      'infants': countOf(data, 'infants', 0),
    },
  };
}

/// Args for train_passenger_form.dart's agentMode hand-off — see flightFormArgs.
Map<String, dynamic> trainFormArgs(Map<String, dynamic> data) {
  final cls = (data['train_class'] as String?) ?? 'Economy';
  final train = TrainResult(
    id: 'AGENT',
    trainName: (data['train_name'] as String?) ??
        (data['airline_or_train_name'] as String?) ??
        'Selected Train',
    trainNumber: '',
    departureTime: (data['departure_time'] as String?) ?? '--:--',
    arrivalTime: (data['arrival_time'] as String?) ?? '--:--',
    duration: '--',
    classSeats: {cls: null},
    classPrices: {cls: perSeatFromTotal(data)},
    availableClasses: [cls],
  );
  return {
    'agentMode': true,
    'train': train,
    'selectedClass': cls,
    'searchParams': {
      'adults': countOf(data, 'adults', 1),
      'children': countOf(data, 'children', 0),
      'infants': countOf(data, 'infants', 0),
      'departureDate':
          DateTime.tryParse((data['travel_date'] as String?) ?? '') ??
              DateTime.now(),
    },
  };
}

/// Args for hotel_guest_form_screen.dart's agentMode hand-off — see flightFormArgs.
Map<String, dynamic> hotelFormArgs(Map<String, dynamic> data) {
  final total = ((data['total_price_pkr'] as num?) ?? 0).toDouble();
  final rooms = countOf(data, 'rooms', 1);
  final checkIn = DateTime.tryParse((data['check_in'] as String?) ?? '');
  final checkOut = DateTime.tryParse((data['check_out'] as String?) ?? '');
  final nights = (checkIn != null && checkOut != null)
      ? checkOut.difference(checkIn).inDays.clamp(1, 365)
      : 1;
  final hotel = Hotel(
    id: 'AGENT',
    name: (data['hotel_name'] as String?) ?? 'Selected Hotel',
    address: (data['destination'] as String?) ?? '',
    city: (data['destination'] as String?) ?? '',
    rating: 0,
    totalReviews: 0,
    images: const [],
    amenities: const [],
    pricePerNight: rooms > 0 ? total / (nights * rooms) : total,
    category: '',
    isRefundable: false,
    hasBreakfast: false,
    hasFreeWifi: false,
    hasParking: false,
    hasPool: false,
    description: '',
    distanceFromCenter: 0,
  );
  return {
    'agentMode': true,
    'hotel': hotel,
    'checkInDate': checkIn,
    'checkOutDate': checkOut,
    'rooms': rooms,
    'guests': countOf(data, 'guests', 1),
    'totalPrice': total,
  };
}

String mintPackageId() =>
    'PKG-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';


Future<Map<String, dynamic>> createAgentBooking({
  required Map<String, dynamic> data,
  required String conversationId,
  required double amount,
  String? passengerName,
  String? contactPhone,
  String? packageId,
}) {
  return ApiClient.agentBook(
    bookingType: data['booking_type'] as String? ?? 'flight',
    conversationId: conversationId,
    packageId: packageId,
    origin: data['origin'] as String?,
    destination: data['destination'] as String?,
    travelDate: data['travel_date'] as String?,
    departureTime: data['departure_time'] as String?,
    arrivalTime: data['arrival_time'] as String?,
    flightNumber: data['flight_number'] as String?,
    trainName: data['train_name'] as String?,
    trainNumber: data['train_number'] as String?,
    checkIn: data['check_in'] as String?,
    checkOut: data['check_out'] as String?,
    travelers: (data['travelers'] as num?)?.toInt() ?? 1,
    totalAmount: amount,
    hotelName: data['hotel_name'] as String?,
    passengerName: passengerName,
    contactPhone: contactPhone,
    adults: (data['adults'] as num?)?.toInt(),
    children: (data['children'] as num?)?.toInt(),
    infants: (data['infants'] as num?)?.toInt(),
    rooms: (data['rooms'] as num?)?.toInt(),
    cabinClass: data['cabin_class'] as String?,
    trainClass: data['train_class'] as String?,
    roomType: data['room_type'] as String?,
    hotelStars: (data['hotel_stars'] as num?)?.toInt(),
    hotelAddress: data['hotel_address'] as String?,
    facilities: agentTransferFacilities(data),
    description: data['selected_option'] as String? ?? 'Agent booking',
  );
}

class CardPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String conversationId;
  final void Function(String pnr, double amount) onSuccess;
  final VoidCallback onCancel;
  // Passengers + contact collected via the native form (agentMode handoff).
  // Attached to the booking before payment, mirroring the manual flow's
  // create -> POST /passengers -> POST /payments sequence.
  final List<Map<String, dynamic>>? passengers;
  final Map<String, dynamic>? contact;

  const CardPaymentSheet({
    super.key,
    required this.bookingData,
    required this.conversationId,
    required this.onSuccess,
    required this.onCancel,
    this.passengers,
    this.contact,
  });

  @override
  State<CardPaymentSheet> createState() => _CardPaymentSheetState();
}

class _CardPaymentSheetState extends State<CardPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _processing = false;
  String? _errorMsg;

  static const _gold = Color(0xFFD4AF37);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatExpiry(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      return '${digits.substring(0, 2)}/${digits.substring(2).padRight(0)}';
    }
    return digits;
  }

  Future<void> _processPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _processing = true; _errorMsg = null; });

    try {
      final data = widget.bookingData;
      final amount = (data['total_price_pkr'] as num?)?.toDouble() ?? 0.0;

      // Guard: never create a booking with a missing/zero price.
      if (amount <= 0) {
        setState(() {
          _processing = false;
          _errorMsg = 'This option has no confirmed price yet. Please ask the '
              'assistant to show the exact fare before booking.';
        });
        return;
      }

      final contactName = (widget.contact?['contactName'] as String?)?.trim();
      final passengerName = (contactName != null && contactName.isNotEmpty)
          ? contactName
          : (_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null);

      // A package creates each of its pieces through the SAME proven sequence a
      // single booking uses (create -> /passengers), so tickets, PNRs and My
      // Bookings keep behaving exactly as before. What differs is the money: a
      // multi-piece package is linked by ONE packageId and then charged in a
      // SINGLE payment for the whole trip, rather than one payment per piece.
      // A single booking has no packageId and takes the unchanged path.
      final components = packageComponents(data);
      final confirmations = <String>[];
      double paidTotal = 0.0;
      final isPackage = components.length > 1;
      // The component the single package payment is filed against, and the one
      // book_car_transfers is handed after payment. It MUST be the transport
      // leg: the hub transfer rides in the flight/train booking's raw_payload,
      // so handing the hotel's uuid instead would silently assign no driver.
      // `components` arrives in whatever order the model prepared the pieces,
      // so "the first one created" is not the transport leg — this picks it by
      // TYPE, reusing the same flight→train→hotel precedence the traveler form
      // already uses.
      // Selected FROM `components` itself, so it is the same object the loop
      // below iterates — packageComponents() rebuilds its maps on every call,
      // so a component taken from a second call could never match by identity.
      final transportComponent = components.firstWhere(
        (c) => c['booking_type'] == 'flight',
        orElse: () => components.firstWhere(
          (c) => c['booking_type'] == 'train',
          orElse: () => components.first,
        ),
      );
      // Minted per checkout, so two packages never collide. The server links
      // the component rows by this and verifies the total against them before
      // charging anything.
      final packageId = isPackage ? mintPackageId() : null;
      String? primaryBookingId;

      for (final component in components) {
        final componentAmount =
            (component['total_price_pkr'] as num?)?.toDouble() ?? 0.0;
        // Never create a zero-priced booking; skip rather than charge nothing.
        if (componentAmount <= 0) continue;

        // Step 1: Create booking via agent endpoint
        final booking = await createAgentBooking(
          data: component,
          conversationId: widget.conversationId,
          amount: componentAmount,
          passengerName: passengerName,
          contactPhone: widget.contact?['contactPhone'] as String?,
          packageId: packageId,
        );

        final bookingId = booking['booking_id'] as String;
        final pnr = booking['pnr'] as String;

        // Step 2: Attach the passengers collected via the native form, before
        // payment — same order as the manual flow (create -> /passengers -> pay).
        // The same travelers apply to every piece, which is the whole point of
        // collecting them once for the package.
        if (widget.passengers != null && widget.passengers!.isNotEmpty) {
          await ApiClient.addPassengers(
            bookingId: bookingId,
            passengers: widget.passengers!,
          );
        }

        // Step 3: Pay. A package defers this until every component exists, so
        // the whole trip is charged ONCE below; a single booking pays here
        // exactly as it always has.
        if (isPackage) {
          // Identity, not creation order: only the transport component may
          // carry the package payment and the transfer.
          if (identical(component, transportComponent)) {
            primaryBookingId = bookingId;
          }
          primaryBookingId ??= bookingId;   // fallback: no transport in package
        } else {
          await ApiClient.initiatePayment(
            bookingId: bookingId,
            method: 'card',
            amount: componentAmount,
          );
        }

        paidTotal += componentAmount;
        confirmations.add(components.length > 1
            ? '${componentLabel(component)} — $pnr'
            : pnr);
      }

      if (confirmations.isEmpty) {
        setState(() {
          _processing = false;
          _errorMsg = 'Nothing in this booking had a confirmed price. Please ask '
              'the assistant to show the exact fare and try again.';
        });
        return;
      }

      // ONE payment for the entire package. The server re-derives the total
      // from the component rows it wrote and refuses the charge if this amount
      // doesn't match, so nothing is confirmed on a mismatch. It also sends the
      // single consolidated confirmation email instead of one per component.
      if (isPackage && primaryBookingId != null) {
        await ApiClient.initiatePayment(
          bookingId: primaryBookingId,
          method: 'card',
          amount: paidTotal,
          packageId: packageId,
        );
      }

      if (mounted) Navigator.pop(context);
      widget.onSuccess(confirmations.join('\n**PNR:** '), paidTotal);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.bookingData['total_price_pkr'] as num?)?.toInt() ?? 0;
    final fmt = NumberFormat('#,##0', 'en_US');

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card_rounded,
                        color: _gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Card Payment',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Total: PKR ${fmt.format(amount)}',
                          style: const TextStyle(
                          fontSize: 13,
                              color: _gold,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Cardholder name
              _CardField(
                controller: _nameCtrl,
                label: 'Cardholder Name',
                hint: 'As printed on card',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: DSValidators.cardholderName,
              ),
              const SizedBox(height: 14),

              // Card number
              _CardField(
                controller: _cardCtrl,
                label: 'Card Number',
                hint: '1234 5678 9012 3456',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                maxLength: 19,
                onChanged: (v) {
                  final formatted = _formatCardNumber(v);
                  if (formatted != v) {
                    _cardCtrl.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                // Full validation incl. the Luhn checksum — rejects a mistyped or
                // made-up 16-digit number that isn't a real card. Same validator
                // the manual booking payment screen uses.
                validator: DSValidators.cardNumber,
              ),
              const SizedBox(height: 14),

              // Expiry + CVV row
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      controller: _expiryCtrl,
                      label: 'Expiry',
                      hint: 'MM/YY',
                      icon: Icons.calendar_month_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      onChanged: (v) {
                        final formatted = _formatExpiry(v);
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                      // Rejects a bad month (00, 13+) and an already-expired card.
                      validator: DSValidators.cardExpiry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      controller: _cvvCtrl,
                      label: 'CVV',
                      hint: '•••',
                      icon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      validator: DSValidators.cvv,
                    ),
                  ),
                ],
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Pay button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    disabledBackgroundColor: _gold.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          amount > 0
                              ? 'Pay PKR ${fmt.format(amount)}'
                              : 'Confirm Booking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                ),
              ),

              // Security note
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Secured by 256-bit encryption',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card form field helper ────────────────────────────────────────────────────
class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
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
              borderSide:
                  const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ),
      ],
    );
  }
}
