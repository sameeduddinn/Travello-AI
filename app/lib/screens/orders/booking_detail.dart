import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/utils/booking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';
import 'package:flight_app/widgets/payment/complete_payment_sheet.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  🎫 PROFESSIONAL BOOKING DETAIL PAGE
//  Industry-Level Design - Consistent UI for Train & Flight Details
//  Inspired by: MakeMyTrip, Cleartrip, Emirates, Pakistan Railways
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BookingDetail extends StatefulWidget {
  const BookingDetail({super.key});

  @override
  State<BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends State<BookingDetail> {
  Map<String, dynamic> _booking = {};
  bool _downloadingPdf = false;
  bool _cancellingBooking = false;
  bool _removingBooking = false;
  bool _reviewSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  void _loadBooking() {
    final booking = Get.arguments as Map<String, dynamic>?;
    if (booking != null) {
      setState(() {
        _booking = booking;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingType = _booking['bookingType'] ?? 'flight';
    final isTrainBooking = bookingType == 'train';
    final isHotelBooking = bookingType == 'hotel';
    final isCarBooking = bookingType == 'car';

    if (isCarBooking) {
      return _buildCarDetailScaffold();
    }

    return Scaffold(
      backgroundColor: TravelloTheme.paperLightContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isTrainBooking ? const Color(0xFF059669) : const Color(0xFFD4AF37),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Booking Details',
          style: TravelloTheme.subtitle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ━━━ Header with Type & PNR ━━━
            _buildHeader(isTrainBooking, isHotelBooking),

            // ━━━ E-Ticket Section with QR/Barcode (Train/Flight only) ━━━
            if (!isHotelBooking) _buildETicketSection(isTrainBooking),

            // ━━━ Hotel Booking Card (Hotels only) ━━━
            if (isHotelBooking) _buildHotelBookingCard(),

            // ━━━ Journey Details (Train/Flight only) ━━━
            if (!isHotelBooking) _buildJourneySection(isTrainBooking),

            // ━━━ Guest/Passenger Details ━━━
            _buildPassengerSection(isHotelBooking),

            // ━━━ Payment Summary ━━━
            _buildPaymentSection(),

            // ━━━ Manage Extras (flight only — shown when return baggage is pending) ━━━
            if (!isHotelBooking && !isTrainBooking) _buildManageExtrasSection(),

            // ━━━ Important Information ━━━
            _buildInfoSection(isTrainBooking, isHotelBooking),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Car booking detail scaffold ──────────────────────────────────────────

  Widget _buildCarDetailScaffold() {
    final c = (_booking['carDetails'] as Map?)?.cast<String, dynamic>() ?? {};
    final driver = (c['driver'] as Map?)?.cast<String, dynamic>() ?? {};
    final status = (_booking['status'] ?? 'confirmed').toString();
    const accent = Color(0xFF1565C0);

    final pickup = c['pickup'] as String? ?? '—';
    final dropoff = c['dropoff'] as String? ?? '—';
    final vehicleType = c['vehicleType'] as String? ?? '—';
    final pickupDt = c['pickupDatetime'] as String? ?? '';
    final code = c['verificationCode'] as String? ?? '——';
    final amount = (_booking['total'] as num?)?.toDouble() ?? 0.0;

    String formattedDt = pickupDt;
    try {
      if (pickupDt.isNotEmpty) {
        final dt = DateTime.parse(pickupDt).toLocal();
        formattedDt = DateFormat('d MMM yyyy  •  HH:mm').format(dt);
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Car Booking Details',
          style: TravelloTheme.subtitle
              .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Status + Code header ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status == 'confirmed' ? 'Booking Confirmed' : status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VERIFICATION CODE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share this code with your driver to verify identity',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Route card ──────────────────────────────────────────────
            _carSection(
              title: 'Trip Route',
              icon: Icons.route,
              child: Column(
                children: [
                  _carRow(Icons.location_on, 'Pickup', pickup, Colors.green.shade600),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 2,
                          height: 6,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _carRow(Icons.location_on, 'Dropoff', dropoff, Colors.red.shade600),
                  if (formattedDt.isNotEmpty) ...[
                    const Divider(height: 20),
                    _carRow(Icons.schedule, 'Pickup Time', formattedDt, accent),
                  ],
                  const Divider(height: 20),
                  _carRow(Icons.directions_car, 'Vehicle', vehicleType, accent),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Driver card ──────────────────────────────────────────────
            _carSection(
              title: 'Driver Details',
              icon: Icons.person,
              child: Column(
                children: [
                  _carRow(Icons.person, 'Name', driver['name'] as String? ?? '—', accent),
                  const Divider(height: 16),
                  _carRow(Icons.phone, 'Phone', driver['phone'] as String? ?? '—', accent),
                  const Divider(height: 16),
                  _carRow(
                    Icons.directions_car,
                    'Vehicle',
                    '${driver['vehicleColor'] ?? ''} ${driver['vehicleMake'] ?? ''} ${driver['vehicleModel'] ?? ''}'.trim(),
                    accent,
                  ),
                  const Divider(height: 16),
                  _carRow(Icons.confirmation_number, 'Plate', driver['vehiclePlate'] as String? ?? '—', accent),
                  if ((driver['rating'] as num?) != null) ...[
                    const Divider(height: 16),
                    _carRow(Icons.star_rounded, 'Rating',
                        '${(driver['rating'] as num).toStringAsFixed(1)} ★',
                        Colors.amber.shade700),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Payment card ─────────────────────────────────────────────
            _carSection(
              title: 'Payment',
              icon: Icons.payments_outlined,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Fare',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600)),
                  Text(
                    'PKR ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('Done',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _carSection(
      {required String title,
      required IconData icon,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0))),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _carRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Cancel booking with confirmation dialog ──────────────────────────────

  Future<void> _showCancelDialog() async {
    final bookingRef = _booking['pnr'] ?? _booking['bookingId'] ?? '';
    final status = (_booking['status'] ?? '').toString().toLowerCase();
    final isConfirmed = status == 'confirmed' || status == 'paid';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your booking${bookingRef.isNotEmpty ? ' $bookingRef' : ''} will be cancelled.',
            ),
            if (isConfirmed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This booking is confirmed. Cancellation may be non-refundable depending on the provider\'s policy.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final bookingUuid =
        _booking['backendBookingId']?.toString() ?? _booking['id']?.toString() ?? '';
    if (bookingUuid.isEmpty) {
      Get.snackbar('Error', 'Booking ID not found.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return;
    }

    setState(() => _cancellingBooking = true);
    try {
      await ApiClient.cancelBooking(bookingUuid);
      setState(() => _booking = {..._booking, 'status': 'cancelled'});
      if (mounted) {
        Get.snackbar('Booking Cancelled', 'Your booking has been cancelled.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
        Get.back();
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Could not cancel booking. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP);
      }
    } finally {
      if (mounted) setState(() => _cancellingBooking = false);
    }
  }

  // ── Remove cancelled booking from history ────────────────────────────────

  Future<void> _showRemoveDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from History?'),
        content: const Text(
          'This will permanently remove this booking from your history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final bookingUuid =
        _booking['backendBookingId']?.toString() ?? _booking['id']?.toString() ?? '';
    if (bookingUuid.isEmpty) {
      Get.snackbar('Error', 'Booking ID not found.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return;
    }

    setState(() => _removingBooking = true);
    try {
      await ApiClient.deleteBooking(bookingUuid);
      if (mounted) {
        Get.back();
        Get.snackbar(
          'Removed',
          'Booking has been removed from your history.',
          backgroundColor: Colors.grey.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _removingBooking = false);
        Get.snackbar('Error', 'Could not remove booking. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            borderRadius: 12);
      }
    }
  }

  // ── Leave a review bottom sheet ──────────────────────────────────────────

  void _showReviewSheet() {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave a Review',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedRating = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            star <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            size: 40,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (submitting || selectedRating == 0)
                          ? null
                          : () async {
                              setSheet(() => submitting = true);
                              try {
                                final bookingUuid =
                                    _booking['backendBookingId']?.toString() ??
                                        _booking['id']?.toString() ?? '';
                                final navigator = Navigator.of(sheetCtx);
                                await ApiClient.submitReview(
                                  bookingId: bookingUuid,
                                  rating: selectedRating,
                                  comment: commentController.text.trim(),
                                );
                                if (mounted) {
                                  navigator.pop();
                                  setState(() => _reviewSubmitted = true);
                                  Get.snackbar(
                                    'Thank you!',
                                    'Your review has been submitted.',
                                    backgroundColor: Colors.green.shade600,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.TOP,
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  Get.snackbar(
                                    'Error',
                                    'Could not submit review. Please try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.TOP,
                                  );
                                }
                                setSheet(() => submitting = false);
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Review'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  🎨 UI COMPONENTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildHeader(bool isTrainBooking, bool isHotelBooking) {
    List<Color> gradientColors;
    IconData icon;
    String label;

    if (isHotelBooking) {
      gradientColors = [const Color(0xFFD4AF37), const Color(0xFFB8941F)];
      icon = Icons.hotel;
      label = 'HOTEL BOOKING';
    } else if (isTrainBooking) {
      gradientColors = [const Color(0xFF059669), const Color(0xFF047857)];
      icon = Icons.train;
      label = 'TRAIN BOOKING';
    } else {
      gradientColors = [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
      icon = Icons.flight;
      label = 'FLIGHT BOOKING';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5.6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TravelloTheme.subtitle2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(_booking['status'] ?? 'confirmed'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PNR: ',
                style: TravelloTheme.paragraph.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                _booking['pnr'] ?? 'N/A',
                style: TravelloTheme.title.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                onPressed: () => _copyPNR(),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'paid':
        bgColor = const Color(0xFF10B981);
        label = 'CONFIRMED';
        icon = Icons.check_circle;
        break;
      case 'canceled':
        bgColor = const Color(0xFFEF4444);
        label = 'CANCELED';
        icon = Icons.cancel;
        break;
      case 'completed':
        bgColor = Colors.white.withValues(alpha: 0.3);
        label = 'COMPLETED';
        icon = Icons.check_circle_outline;
        break;
      default:
        bgColor = const Color(0xFFF59E0B);
        label = 'PENDING';
        icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9.6,
        vertical: 4.8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TravelloTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildETicketSection(bool isTrainBooking) {
    // ━━━ Professional Barcode Data Format (IATA-Style) ━━━
    final pnr = _booking['pnr'] ?? 'N/A';
    final passengerName = _booking['passengerName'] ?? 'PASSENGER';
    final details = isTrainBooking
        ? _booking['trainDetails'] as Map<String, dynamic>?
        : _booking['flightDetails'] as Map<String, dynamic>?;

    String barcodeData = pnr;
    String qrData = pnr;

    if (details != null) {
      if (isTrainBooking) {
        // Train format: PNR|TRAIN|FROM-TO|DATE|PAX|CLASS
        final trainNum = details['trainNumber'] ?? 'N/A';
        final fromCode = details['fromCode'] ?? 'N/A';
        final toCode = details['toCode'] ?? 'N/A';
        final date = details['date'] ?? 'N/A';
        final trainClass = details['class'] ?? 'Economy';

        barcodeData =
            '$pnr/$trainNum/$fromCode-$toCode/${date.replaceAll(' ', '')}/$passengerName/$trainClass';
        qrData =
            'TRAVELLO|TYPE:TRAIN|PNR:$pnr|TRAIN:$trainNum|ROUTE:$fromCode-$toCode|DATE:$date|PAX:$passengerName|CLASS:$trainClass';
      } else {
        // Flight format (IATA-inspired): PNR|FLT|FROM-TO|DATE|PAX|CLASS
        final flightNum = details['flightNumber'] ?? 'N/A';
        final date = details['date'] ?? 'N/A';
        final flightClass = details['class'] ?? 'Economy';

        // Extract airport codes
        final fromStr = details['from'] ?? 'N/A';
        final toStr = details['to'] ?? 'N/A';
        final fromMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(fromStr);
        final toMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(toStr);
        final fromCode =
            fromMatch?.group(1) ?? fromStr.substring(0, 3).toUpperCase();
        final toCode = toMatch?.group(1) ?? toStr.substring(0, 3).toUpperCase();

        // Professional airline barcode format
        barcodeData =
            '$pnr/$flightNum/$fromCode-$toCode/${date.replaceAll(' ', '')}/$passengerName/${flightClass.isNotEmpty ? flightClass[0] : 'E'}';
        qrData =
            'TRAVELLO|TYPE:FLIGHT|PNR:$pnr|FLT:$flightNum|ROUTE:$fromCode-$toCode|DATE:$date|PAX:$passengerName|CLASS:$flightClass';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isTrainBooking ? 'RAILWAY E-TICKET' : 'BOARDING PASS',
            style: TravelloTheme.subtitle.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // QR Code (with comprehensive data)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // Professional Barcode (IATA-style format)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: barcodeData,
              height: 60,
              drawText: true,
              style: TravelloTheme.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'Show this to ${isTrainBooking ? 'railway staff' : 'airport staff'} for boarding',
            style: TravelloTheme.caption.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJourneySection(bool isTrainBooking) {
    final details = isTrainBooking
        ? _booking['trainDetails'] as Map<String, dynamic>?
        : _booking['flightDetails'] as Map<String, dynamic>?;

    if (details == null) return const SizedBox();

    final isRoundTrip = _booking['isRoundTrip'] == true;
    final returnDetails = isTrainBooking
        ? _booking['returnTrainDetails'] as Map<String, dynamic>?
        : _booking['returnFlightDetails'] as Map<String, dynamic>?;

    final accentColor =
        isTrainBooking ? const Color(0xFF059669) : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Icon(isTrainBooking ? Icons.train : Icons.flight,
                    color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'JOURNEY DETAILS',
                  style: TravelloTheme.subtitle
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (isRoundTrip)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 9.6, vertical: spacingUnit(0.4)),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.compare_arrows,
                            size: 14, color: accentColor),
                        SizedBox(width: spacingUnit(0.4)),
                        Text(
                          'ROUND TRIP',
                          style: TravelloTheme.caption.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Outbound Leg ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRoundTrip)
                  _buildLegLabel('OUTBOUND', Icons.flight_takeoff, accentColor),
                if (isRoundTrip) const SizedBox(height: 9.6),
                Text(
                  isTrainBooking
                      ? _buildTrainRouteText(details)
                      : _buildFlightRouteText(details),
                  style: TravelloTheme.subtitle
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                isTrainBooking
                    ? _buildTrainJourney(details)
                    : _buildFlightJourney(details),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 12),
                _buildLegInfoRow(details, isTrainBooking),
              ],
            ),
          ),

          // ── Return Leg (round trips only) ──
          if (isRoundTrip && returnDetails != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9.6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'RETURN FLIGHT',
                        style: TravelloTheme.caption.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegLabel('RETURN', Icons.flight_land, accentColor),
                  const SizedBox(height: 9.6),
                  Text(
                    isTrainBooking
                        ? _buildTrainRouteText(returnDetails)
                        : _buildFlightRouteText(returnDetails),
                    style: TravelloTheme.subtitle
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  isTrainBooking
                      ? _buildTrainJourney(returnDetails)
                      : _buildFlightJourney(returnDetails),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  _buildLegInfoRow(returnDetails, isTrainBooking),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLegLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4.8),
        Text(
          label,
          style: TravelloTheme.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildLegInfoRow(Map<String, dynamic> details, bool isTrainBooking) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                'Date',
                isTrainBooking
                    ? _getTrainDateDisplay(details)
                    : (details['date'] ?? 'N/A'),
                Icons.calendar_today,
              ),
            ),
            Expanded(
              child: _buildInfoTile(
                'Class',
                details['class'] ?? 'Economy',
                Icons.airline_seat_recline_extra,
              ),
            ),
            Expanded(
              child: _buildInfoTile(
                'Duration',
                details['duration'] ?? 'N/A',
                Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isTrainBooking)
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'Train',
                  details['trainName'] ?? 'N/A',
                  Icons.train,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Number',
                  details['trainNumber'] ?? 'N/A',
                  Icons.confirmation_number,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'Airline',
                  details['airline'] ?? 'N/A',
                  Icons.flight,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Flight',
                  details['flightNumber'] ?? 'N/A',
                  Icons.confirmation_number,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _getTrainDateDisplay(Map<String, dynamic> details) {
    String dateStr = details['date'] ?? 'N/A';

    // Check if train arrives next day
    bool arrivesNextDay = details['arrivesNextDay'] ?? false;

    // Fallback: detect next-day arrival by comparing times
    if (!arrivesNextDay) {
      final depTime = details['departure'] as String?;
      final arrTime = details['arrival'] as String?;
      if (depTime != null && arrTime != null) {
        try {
          final depParts = depTime.split(':');
          final arrParts = arrTime.split(':');
          if (depParts.length == 2 && arrParts.length == 2) {
            final depHour = int.parse(depParts[0]);
            final arrHour = int.parse(arrParts[0]);
            // If arrival hour is less than departure, it's next day
            if (arrHour < depHour ||
                (arrHour == depHour &&
                    details['duration']?.toString().contains('23h') == true)) {
              arrivesNextDay = true;
            }
          }
        } catch (e) {
          // Keep arrivesNextDay as false
        }
      }
    }

    // If next day arrival, show both dates
    if (arrivesNextDay) {
      // Format: "19 Mar - 20 Mar"
      String depDate = dateStr;
      if (depDate.contains(' ')) {
        final parts = depDate.split(' ');
        if (parts.length >= 2) {
          final day = int.tryParse(parts[0]);
          if (day != null) {
            final month = parts[1];
            final arrDay = day + 1;
            return '$day $month - $arrDay $month';
          }
        }
      }
    }

    return dateStr;
  }

  String _buildFlightRouteText(Map<String, dynamic> details) {
    // Get full airport strings (e.g., "Jinnah International Airport (KHI)")
    final fromStr = details['from'] ?? 'N/A';
    final toStr = details['to'] ?? 'N/A';

    // Extract airport codes using regex
    final fromMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(fromStr);
    final toMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(toStr);

    final fromCode = fromMatch?.group(1) ?? 'N/A';
    final toCode = toMatch?.group(1) ?? 'N/A';

    // Map airport codes to city names
    final fromCity = _getCityNameFromCode(fromCode);
    final toCity = _getCityNameFromCode(toCode);

    return '$fromCity($fromCode) - $toCity($toCode)';
  }

  String _buildTrainRouteText(Map<String, dynamic> details) {
    final fromStation = details['from'] ?? 'N/A';
    final fromCode = details['fromCode'] ?? '';
    final toStation = details['to'] ?? 'N/A';
    final toCode = details['toCode'] ?? '';
    final fromDisplay =
        fromCode.isNotEmpty ? '$fromStation($fromCode)' : fromStation;
    final toDisplay = toCode.isNotEmpty ? '$toStation($toCode)' : toStation;
    return '$fromDisplay - $toDisplay';
  }

  String _getCityNameFromCode(String airportCode) {
    // Airport code to city name mapping (Domestic Pakistan airports only)
    const Map<String, String> airportToCityMap = {
      'KHI': 'Karachi',
      'ISB': 'Islamabad',
      'LHE': 'Lahore',
      'PEW': 'Peshawar',
      'SKT': 'Sialkot',
      'MUX': 'Multan',
      'UET': 'Quetta',
      'RYK': 'Rahim Yar Khan',
      'BHV': 'Bahawalpur',
      'ATG': 'Attock',
      'LYP': 'Faisalabad',
      'GWD': 'Gwadar',
      'SBQ': 'Sibi',
      'PJG': 'Panjgur',
      'WAF': 'Wana',
      'KDD': 'Khuzdar',
      'CJL': 'Chitral',
      'GIL': 'Gilgit',
      'SKZ': 'Skardu',
      'SWN': 'Sahiwal',
    };

    return airportToCityMap[airportCode] ?? airportCode;
  }

  Widget _buildTrainJourney(Map<String, dynamic> details) {
    // Extract date from details
    String dateStr = details['date'] ?? '06 Mar';
    // Try to format date nicely (assuming format like "06 March 2026" or similar)
    if (dateStr.contains(' ')) {
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        dateStr = '${parts[0]} ${parts[1].substring(0, 3)}';
      }
    }

    // Calculate if train arrives next day
    bool arrivesNextDay = details['arrivesNextDay'] ?? false;

    // Fallback: detect next-day arrival by comparing times
    if (!arrivesNextDay) {
      final depTime = details['departure'] as String?;
      final arrTime = details['arrival'] as String?;
      if (depTime != null && arrTime != null) {
        try {
          final depParts = depTime.split(':');
          final arrParts = arrTime.split(':');
          if (depParts.length == 2 && arrParts.length == 2) {
            final depHour = int.parse(depParts[0]);
            final arrHour = int.parse(arrParts[0]);
            // If arrival hour is less than departure, it's next day
            if (arrHour < depHour ||
                (arrHour == depHour &&
                    details['duration']?.toString().contains('23h') == true)) {
              arrivesNextDay = true;
            }
          }
        } catch (e) {
          // Keep arrivesNextDay as false
        }
      }
    }

    // Calculate arrival date
    String arrivalDateStr = dateStr;
    if (arrivesNextDay) {
      // Parse the date and add 1 day
      try {
        final dateParts = dateStr.split(' ');
        if (dateParts.length >= 2) {
          final day = int.parse(dateParts[0]);
          final month = dateParts[1];
          final nextDay = day + 1;
          arrivalDateStr = '$nextDay $month';
        }
      } catch (e) {
        // If parsing fails, just use the same date
        arrivalDateStr = dateStr;
      }
    }

    return Column(
      children: [
        // Top row: Times with dates and duration
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Departure time and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details['departure'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: R.sp(context, 36),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Right: Arrival time, date, and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        details['duration'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details['arrival'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: R.sp(context, 36),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (arrivesNextDay)
                        Container(
                          margin: const EdgeInsets.only(left: 3, top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '+1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    arrivalDateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Middle row: Route visualization with code chips
        Row(
          children: [
            // FROM CODE in rounded chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6.4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                details['fromCode'] ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF059669),
                  letterSpacing: 1,
                ),
              ),
            ),

            // Journey Line with hollow and filled circles
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Hollow circle at start
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF059669),
                          width: 2,
                        ),
                      ),
                    ),
                    // Dashed line before icon
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              (constraints.constrainWidth() / 6).floor(),
                              (index) => Container(
                                width: 3,
                                height: 2,
                                color: const Color(0xFF059669)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Train icon
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.train_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    // Dashed line after icon
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              (constraints.constrainWidth() / 6).floor(),
                              (index) => Container(
                                width: 3,
                                height: 2,
                                color: const Color(0xFF059669)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Filled circle at end
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TO CODE in rounded chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6.4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                details['toCode'] ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF059669),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9.6),

        // Bottom row: Station names
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                details['from'] ?? 'N/A',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                details['to'] ?? 'N/A',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlightJourney(Map<String, dynamic> details) {
    // Extract airport codes
    String fromCode = 'N/A';
    String toCode = 'N/A';

    final fromStr = details['from'] ?? 'N/A';
    final toStr = details['to'] ?? 'N/A';

    final fromMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(fromStr);
    final toMatch = RegExp(r'\(([A-Z]{3})\)').firstMatch(toStr);

    if (fromMatch != null) fromCode = fromMatch.group(1)!;
    if (toMatch != null) toCode = toMatch.group(1)!;

    // Clean city names
    final fromCity = fromStr.replaceAll(RegExp(r'\s*\([A-Z]{3}\)'), '');
    final toCity = toStr.replaceAll(RegExp(r'\s*\([A-Z]{3}\)'), '');

    // Extract date from details
    String dateStr = details['date'] ?? '06 Mar';
    // Try to format date nicely (assuming format like "06 March 2026" or similar)
    if (dateStr.contains(' ')) {
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        dateStr = '${parts[0]} ${parts[1].substring(0, 3)}';
      }
    }

    return Column(
      children: [
        // Top row: Times with dates and duration
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Departure time and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details['departure'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: R.sp(context, 36),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Right: Arrival time, date, and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        details['duration'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details['arrival'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: R.sp(context, 36),
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Middle row: Route visualization with code chips
        Row(
          children: [
            // FROM CODE in rounded chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6.4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                fromCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF3B82F6),
                  letterSpacing: 1,
                ),
              ),
            ),

            // Journey Line with hollow and filled circles
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Hollow circle at start
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2,
                        ),
                      ),
                    ),
                    // Dashed line before icon
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              (constraints.constrainWidth() / 6).floor(),
                              (index) => Container(
                                width: 3,
                                height: 2,
                                color: const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Flight icon (rotated to face destination)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.rotate(
                        angle: 1.5708, // 90 degrees in radians (pi/2)
                        child: const Icon(
                          Icons.flight,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                      ),
                    ),
                    // Dashed line after icon
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              (constraints.constrainWidth() / 6).floor(),
                              (index) => Container(
                                width: 3,
                                height: 2,
                                color: const Color(0xFF3B82F6)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Filled circle at end
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TO CODE in rounded chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6.4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                toCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF3B82F6),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9.6),

        // Bottom row: City names
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                fromCity,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                toCity,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(height: 4),
        Text(
          label,
          style: TravelloTheme.caption.copyWith(
            color: Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
        SizedBox(height: spacingUnit(0.3)),
        Text(
          value,
          style: TravelloTheme.paragraph.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAmenityIcon(IconData icon, String label) {
    const goldColor = Color(0xFFD4AF37);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: goldColor, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TravelloTheme.caption.copyWith(
            fontSize: 10,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildHotelBookingCard() {
    final hotelDetails = _booking['hotelDetails'] as Map<String, dynamic>?;
    if (hotelDetails == null) return const SizedBox();

    final hotelName = hotelDetails['hotelName'] ?? 'Hotel';
    final city = hotelDetails['city'] ?? '';
    final address = hotelDetails['address'] ?? '';
    final checkIn = hotelDetails['checkIn'] ?? 'N/A';
    final checkOut = hotelDetails['checkOut'] ?? 'N/A';
    final roomType = hotelDetails['roomType'] ?? 'Standard Room';
    final nights = hotelDetails['nights'] ?? 1;
    final rating = (hotelDetails['rating'] ?? 0) as num;

    const goldColor = Color(0xFFD4AF37);
    const goldLight = Color(0xFFFFFBEB);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hotel Name & Rating
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hotel, color: goldColor, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotelName,
                      style: TravelloTheme.title.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          rating.toInt(),
                          (i) => const Icon(Icons.star,
                              size: 16, color: goldColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Address
          if (address.isNotEmpty || city.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address.isNotEmpty ? address : city,
                    style: TravelloTheme.paragraph.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),

          // Stay Details Grid (Like Train Booking)
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'Check-in',
                  checkIn,
                  Icons.calendar_today,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Check-out',
                  checkOut,
                  Icons.calendar_today,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Duration',
                  '$nights Night${nights > 1 ? 's' : ''}',
                  Icons.nights_stay,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'Room Type',
                  roomType,
                  Icons.bed_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Check-in Time',
                  '2:00 PM',
                  Icons.access_time,
                ),
              ),
              Expanded(
                child: _buildInfoTile(
                  'Check-out Time',
                  '12:00 PM',
                  Icons.access_time,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),

          // Amenities Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAmenityIcon(Icons.wifi, 'Free WiFi'),
              _buildAmenityIcon(Icons.pool, 'Pool'),
              _buildAmenityIcon(Icons.fitness_center, 'Gym'),
              _buildAmenityIcon(Icons.restaurant, 'Restaurant'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerSection(bool isHotelBooking) {
    final passengers = _booking['allPassengers'] as List<dynamic>?;
    if (passengers == null || passengers.isEmpty) return const SizedBox();

    final sectionLabel = isHotelBooking ? 'GUESTS' : 'PASSENGERS';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: TravelloTheme.primaryMain),
              const SizedBox(width: 8),
              Text(
                '$sectionLabel (${passengers.length})',
                style: TravelloTheme.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...passengers.asMap().entries.map((entry) {
            final index = entry.key;
            final passenger = entry.value as Map<String, dynamic>;
            return Column(
              children: [
                if (index > 0) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                ],
                _buildPassengerRow(passenger, index + 1, index),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPassengerRow(
      Map<String, dynamic> passenger, int number, int passengerIndex) {
    final firstName = passenger['firstName']?.toString() ?? '';
    final lastName = passenger['lastName']?.toString() ?? '';
    final salutation = passenger['salutation']?.toString() ?? '';
    final fullName = firstName.isNotEmpty && lastName.isNotEmpty
        ? '$firstName $lastName'
        : (passenger['name']?.toString() ?? 'N/A');
    final nameWithSalutation =
        salutation.isNotEmpty ? '$fullName ($salutation)' : fullName;

    // Get seat information
    final seatInfo = _getPassengerSeatInfo(passengerIndex);

    // Get baggage information
    final baggageInfo = _getPassengerBaggageInfo(passengerIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TravelloTheme.subtitle.copyWith(
                color: TravelloTheme.primaryMain,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameWithSalutation,
                style: TravelloTheme.subtitle2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: spacingUnit(0.3)),
              Text(
                _getPassengerDocumentInfo(passenger),
                style: TravelloTheme.caption.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              if (seatInfo.isNotEmpty) ...[
                SizedBox(height: spacingUnit(0.3)),
                Text(
                  seatInfo,
                  style: TravelloTheme.caption.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (baggageInfo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6.4,
                  runSpacing: spacingUnit(0.4),
                  children: baggageInfo
                      .map((info) => _buildBaggageChip(info))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBaggageChip(Map<String, String> info) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: spacingUnit(0.4)),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.luggage, size: 12, color: Color(0xFF3B82F6)),
          SizedBox(width: spacingUnit(0.4)),
          Text(
            info['label'] ?? '',
            style: TravelloTheme.caption.copyWith(
              color: const Color(0xFF3B82F6),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getPassengerBaggageInfo(int passengerIndex) {
    final bookingType = _booking['bookingType'] ?? 'flight';
    if (bookingType != 'flight') return [];

    final isRoundTrip = _booking['isRoundTrip'] == true;
    final List<Map<String, String>> chips = [];

    // Outbound baggage
    final baggageData = _booking['baggageData'] as List<dynamic>? ?? [];
    if (passengerIndex < baggageData.length) {
      final b = baggageData[passengerIndex] as Map<String, dynamic>;
      final kg = (b['totalKg'] as num?)?.toDouble() ?? 0;
      if (kg > 0) {
        final label = isRoundTrip
            ? 'Out: ${kg.toStringAsFixed(0)} kg'
            : '${kg.toStringAsFixed(0)} kg';
        chips.add({'label': label});
      }
    }

    // Return baggage (round trip)
    if (isRoundTrip) {
      final returnBaggageData =
          _booking['returnBaggageData'] as List<dynamic>? ?? [];
      if (passengerIndex < returnBaggageData.length) {
        final b = returnBaggageData[passengerIndex] as Map<String, dynamic>;
        final mode = b['mode']?.toString() ?? 'custom';
        final kg = (b['totalKg'] as num?)?.toDouble() ?? 0;
        if (mode == 'later') {
          chips.add({'label': 'Ret: Add at airport'});
        } else if (kg > 0) {
          chips.add({'label': 'Ret: ${kg.toStringAsFixed(0)} kg'});
        }
      }
    }

    return chips;
  }

  String _getPassengerSeatInfo(int passengerIndex) {
    final isRoundTrip = _booking['isRoundTrip'] == true;
    final bookingType = _booking['bookingType'] ?? 'flight';

    if (bookingType == 'train') {
      // For trains, seats are stored differently
      final seats = _booking['seats'] as List<dynamic>? ?? [];
      if (passengerIndex < seats.length) {
        final seat = seats[passengerIndex];
        if (seat is Map) {
          final seatNumber = seat['seatNumber'] ?? seat['seat'] ?? '';
          if (seatNumber.toString().isNotEmpty) {
            return 'Seat: $seatNumber';
          }
        } else if (seat.toString().isNotEmpty) {
          return 'Seat: $seat';
        }
      }
    } else {
      // For flights
      if (isRoundTrip) {
        final outboundSeats =
            _booking['outboundSeatSelections'] as List<dynamic>? ?? [];
        final returnSeats =
            _booking['returnSeatSelections'] as List<dynamic>? ?? [];

        String outboundSeat = '';
        String returnSeat = '';

        if (passengerIndex < outboundSeats.length) {
          final seatData =
              outboundSeats[passengerIndex] as Map<String, dynamic>;
          outboundSeat = seatData['seatName']?.toString() ?? '';
        }

        if (passengerIndex < returnSeats.length) {
          final seatData = returnSeats[passengerIndex] as Map<String, dynamic>;
          returnSeat = seatData['seatName']?.toString() ?? '';
        }

        if (outboundSeat.isNotEmpty && returnSeat.isNotEmpty) {
          return 'Seats: $outboundSeat (Out) | $returnSeat (Ret)';
        } else if (outboundSeat.isNotEmpty) {
          return 'Seat (Outbound): $outboundSeat';
        } else if (returnSeat.isNotEmpty) {
          return 'Seat (Return): $returnSeat';
        }
      } else {
        final seatSelections =
            _booking['seatSelections'] as List<dynamic>? ?? [];
        if (passengerIndex < seatSelections.length) {
          final seatData =
              seatSelections[passengerIndex] as Map<String, dynamic>;
          final seatName = seatData['seatName']?.toString() ?? '';
          if (seatName.isNotEmpty) {
            return 'Seat: $seatName';
          }
        }
      }
    }

    return '';
  }

  String _getPassengerDocumentInfo(Map<String, dynamic> passenger) {
    final documentType = passenger['documentType']?.toString() ?? '';

    // Check for CNIC
    final cnic = passenger['cnic']?.toString().trim();
    final nationalId = passenger['nationalId']?.toString().trim();
    if (documentType == 'CNIC' || (cnic != null && cnic.isNotEmpty)) {
      final cnicNumber = cnic ?? nationalId ?? '';
      return cnicNumber.isNotEmpty ? 'CNIC: $cnicNumber' : 'CNIC: N/A';
    }

    // Check for B-Form
    final bForm = passenger['bForm']?.toString().trim();
    if (documentType == 'B-Form' || (bForm != null && bForm.isNotEmpty)) {
      return 'B-Form: $bForm';
    }

    // Check for Passport
    final passport = passenger['passportNumber']?.toString().trim();
    if (documentType == 'Passport' ||
        (passport != null && passport.isNotEmpty)) {
      return 'Passport: $passport';
    }

    // Fallback to generic ID
    final passportOrId = passenger['passportOrId']?.toString().trim();
    if (passportOrId != null && passportOrId.isNotEmpty) {
      return 'ID: $passportOrId';
    }

    return 'ID: N/A';
  }

  Widget _buildPaymentSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: TravelloTheme.primaryMain),
              const SizedBox(width: 8),
              Text(
                'PAYMENT SUMMARY',
                style: TravelloTheme.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildFareRows(),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, thickness: 1.5),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TravelloTheme.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'PKR ${(_booking['total'] ?? 0).toStringAsFixed(0)}',
                style: TravelloTheme.title2.copyWith(
                  fontWeight: FontWeight.w900,
                  color: TravelloTheme.primaryMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPaymentStatusBanner(),
        ],
      ),
    );
  }

  /// Payment status line — reflects the real booking status instead of always
  /// claiming success. A pending (Pay-Later) booking shows an amber "amount due"
  /// prompt; paid/confirmed shows the green success line; cancelled shows red.
  Widget _buildPaymentStatusBanner() {
    final status = (_booking['status'] ?? 'confirmed').toString().toLowerCase();
    final isPaid = status == 'paid' || status == 'confirmed';
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final total = (_booking['total'] as num?)?.toDouble() ?? 0.0;

    if (isCancelled) {
      return _paymentBanner(
        bg: Colors.red.shade50,
        border: Colors.red.shade200,
        fg: Colors.red.shade700,
        icon: Icons.cancel_outlined,
        text: 'This booking was cancelled.',
      );
    }
    if (isPaid) {
      return _paymentBanner(
        bg: Colors.green.shade50,
        border: Colors.green.shade200,
        fg: Colors.green.shade700,
        icon: Icons.check_circle,
        text: 'Payment successful via ${_booking['paymentMethod'] ?? 'Card'}',
      );
    }
    return _paymentBanner(
      bg: Colors.amber.shade50,
      border: Colors.amber.shade200,
      fg: Colors.amber.shade900,
      icon: Icons.access_time_rounded,
      text: 'Payment pending — PKR ${total.toStringAsFixed(0)} due. '
          'Tap "Complete Payment" below to confirm this booking.',
    );
  }

  Widget _paymentBanner({
    required Color bg,
    required Color border,
    required Color fg,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(9.6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TravelloTheme.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rows above the Total in the payment summary.
  ///
  /// A booking stores one all-in figure (`total_amount`) — there is no base/tax
  /// split anywhere in the backend, so the old fixed "Base Fare" and
  /// "Taxes & Fees" rows read PKR 0 against a real total of PKR 148,578, which
  /// looks like a billing fault. Splitting the total by an invented tax rate
  /// would be worse: a made-up financial figure on a paid booking. So show only
  /// what is genuinely known — the per-traveller fare when it divides exactly,
  /// and taxes marked as included in the quoted price.
  List<Widget> _buildFareRows() {
    final baseFare = (_booking['amount'] as num?)?.toDouble() ?? 0.0;
    final taxes = (_booking['tax'] as num?)?.toDouble() ?? 0.0;
    final serviceFee = (_booking['serviceFee'] as num?)?.toDouble() ?? 0.0;

    // A real split exists (manual booking flow) — show it as before.
    if (baseFare > 0 || taxes > 0) {
      return [
        _buildPriceRow('Base Fare', baseFare),
        _buildPriceRow('Taxes & Fees', taxes),
        if (serviceFee > 0) _buildPriceRow('Service Fee', serviceFee),
      ];
    }

    final total = (_booking['total'] as num?)?.toDouble() ?? 0.0;
    final count = (_booking['passengerCount'] as num?)?.toInt() ?? 1;
    final rows = <Widget>[];
    if (total > 0 && count > 1 && (total / count) % 1 == 0) {
      rows.add(_buildPriceRow('Fare ($count travellers)', total));
      rows.add(_buildNoteRow(
          'Per traveller', 'PKR ${(total / count).toStringAsFixed(0)}'));
    } else if (total > 0) {
      rows.add(_buildPriceRow('Fare', total));
    }
    rows.add(_buildNoteRow('Taxes & Fees', 'Included'));
    if (serviceFee > 0) rows.add(_buildPriceRow('Service Fee', serviceFee));
    return rows;
  }

  /// A summary row whose value is a word rather than an amount.
  Widget _buildNoteRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TravelloTheme.paragraph.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TravelloTheme.paragraph.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic amount) {
    final value =
        (amount is double ? amount : (amount as num?)?.toDouble()) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TravelloTheme.paragraph.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            'PKR ${value.toStringAsFixed(0)}',
            style: TravelloTheme.paragraph.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isTrainBooking, bool isHotelBooking) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text(
                'IMPORTANT INFORMATION',
                style: TravelloTheme.subtitle2.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isHotelBooking) ...[
            _buildInfoPoint(
                'Check-in time: 2:00 PM | Check-out time: 12:00 PM'),
            _buildInfoPoint(
                'Carry valid CNIC/Passport matching booking details'),
            _buildInfoPoint('Show booking confirmation at reception'),
            _buildInfoPoint(
                'Cancellation allowed up to 24 hours before check-in'),
          ] else if (isTrainBooking) ...[
            _buildInfoPoint('Arrive at station 30 minutes before departure'),
            _buildInfoPoint(
                'Carry valid CNIC/Passport matching booking details'),
            _buildInfoPoint('Show QR code or PNR at entry gates'),
            _buildInfoPoint(
                'Cancellation allowed up to 2 hours before departure'),
          ] else ...[
            _buildInfoPoint('Check-in opens 3 hours before departure'),
            _buildInfoPoint('Carry valid passport and visa documents'),
            _buildInfoPoint('Arrive at airport 2 hours before departure'),
            _buildInfoPoint('Web check-in available 24 hours before flight'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TravelloTheme.paragraph.copyWith(
                color: Colors.amber.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the card sheet for a pending (Pay-Later) booking and, on success,
  /// flips this screen to the confirmed state. Reuses the existing
  /// `/payments/initiate` flow on the booking UUID — no re-booking.
  Future<void> _completePayment() async {
    final bookingId = (_booking['id'] ?? '').toString();
    final total = (_booking['total'] as num?)?.toDouble() ?? 0.0;
    if (bookingId.isEmpty || total <= 0) {
      Get.snackbar(
        'Payment unavailable',
        'This booking is missing the details needed to take a payment.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final email =
        (_booking['contact_email'] ?? _booking['contactEmail'] ?? '').toString();

    await showCompletePaymentSheet(
      context: context,
      bookingId: bookingId,
      amount: total,
      email: email.isNotEmpty ? email : null,
      onSuccess: (pnr, amount) {
        if (!mounted) return;
        setState(() {
          _booking = {
            ..._booking,
            'status': 'confirmed',
            if (pnr.isNotEmpty) 'pnr': pnr,
          };
        });
        Get.snackbar(
          'Payment successful',
          'Your booking is now confirmed.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final bookingType = _booking['bookingType'] ?? 'flight';
    final isTrainBooking = bookingType == 'train';
    final isHotelBooking = bookingType == 'hotel';

    Color primaryBtnColor;
    String downloadBtnText;
    VoidCallback? buttonAction;

    if (isHotelBooking) {
      primaryBtnColor = const Color(0xFFD4AF37); // Gold
      downloadBtnText = 'VIEW & DOWNLOAD INVOICE';
      buttonAction = _downloadHotelConfirmation;
    } else if (isTrainBooking) {
      primaryBtnColor = const Color(0xFF059669); // Green
      downloadBtnText = 'DOWNLOAD E-TICKET';
      buttonAction = _downloadETicket;
    } else {
      primaryBtnColor = const Color(0xFFD4AF37); // Gold (app primary)
      downloadBtnText = 'DOWNLOAD E-TICKET & BOARDING PASS';
      buttonAction = _downloadETicket;
    }

    final status = (_booking['status'] ?? '').toString().toLowerCase();
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final isPending = status == 'pending';
    final canCancel = !isCancelled;
    final canReview = status == 'paid' || status == 'confirmed';

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _completePayment,
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: Text(
                    'COMPLETE PAYMENT · PKR ${((_booking['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _downloadingPdf ? null : buttonAction,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBtnColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _downloadingPdf
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        downloadBtnText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            if (canReview || canCancel || isCancelled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (canReview)
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _reviewSubmitted ? null : _showReviewSheet,
                          icon: Icon(
                            _reviewSubmitted
                                ? Icons.check_circle
                                : Icons.star_outline,
                            size: 16,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _reviewSubmitted
                                  ? 'Review Submitted'
                                  : 'Leave a Review',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  if (canReview && canCancel) const SizedBox(width: 8),
                  if (canCancel)
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed:
                              _cancellingBooking ? null : _showCancelDialog,
                          icon: _cancellingBooking
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.red))
                              : const Icon(Icons.cancel_outlined, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cancel Booking',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  if (isCancelled)
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed:
                              _removingBooking ? null : _showRemoveDialog,
                          icon: _removingBooking
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey))
                              : const Icon(Icons.delete_outline_rounded,
                                  size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Remove from History',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  🧳 MANAGE EXTRAS — Add Return Baggage (Expedia / Wego standard)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // PKR per kg — matches booking_facilites.dart constant
  static const double _baggageRatePerKg = 200.0;

  Widget _buildManageExtrasSection() {
    final isRoundTrip = _booking['isRoundTrip'] == true;
    if (!isRoundTrip) return const SizedBox.shrink();

    final returnBaggageData =
        _booking['returnBaggageData'] as List<dynamic>? ?? [];

    // Detect pending: any entry has mode == 'later' OR top-level field == 'later'
    final hasPendingReturnBaggage = returnBaggageData.isNotEmpty
        ? returnBaggageData.any(
            (b) => (b as Map<String, dynamic>)['mode']?.toString() == 'later')
        : _booking['returnBaggageMode']?.toString() == 'later';

    final returnBaggageAdded =
        returnBaggageData.isNotEmpty && !hasPendingReturnBaggage;

    if (!hasPendingReturnBaggage && !returnBaggageAdded) {
      return const SizedBox.shrink();
    }

    final returnDateStr = _booking['returnDate']?.toString() ?? '';
    final returnDate = DateTime.tryParse(returnDateStr);
    final canModify = returnDate == null ||
        returnDate.isAfter(DateTime.now().add(const Duration(hours: 24)));

    // Total pending payment amount (if already added)
    double pendingPayment = 0;
    if (returnBaggageAdded) {
      for (final b in returnBaggageData) {
        pendingPayment +=
            ((b as Map<String, dynamic>)['extraPrice'] as num? ?? 0).toDouble();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPendingReturnBaggage
                ? TravelloTheme.primaryMain.withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: hasPendingReturnBaggage ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasPendingReturnBaggage
                    ? TravelloTheme.primaryMain.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: hasPendingReturnBaggage
                        ? TravelloTheme.primaryMain.withValues(alpha: 0.25)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.luggage_rounded,
                      color: TravelloTheme.primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Extras',
                          style: TravelloTheme.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: spacingUnit(0.3)),
                        Text(
                          hasPendingReturnBaggage
                              ? 'Return baggage not selected yet'
                              : 'Return baggage confirmed',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasPendingReturnBaggage
                                ? TravelloTheme.primaryDark
                                : Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPendingReturnBaggage
                          ? TravelloTheme.primaryMain.withValues(alpha: 0.12)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasPendingReturnBaggage
                            ? TravelloTheme.primaryMain.withValues(alpha: 0.4)
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      hasPendingReturnBaggage ? 'PENDING' : 'ADDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: hasPendingReturnBaggage
                            ? TravelloTheme.primaryDark
                            : Colors.green.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasPendingReturnBaggage) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: TravelloTheme.primaryDark),
                        const SizedBox(width: 5.6),
                        Expanded(
                          child: Text(
                            canModify
                                ? 'Select your return baggage allowance. Extra weight is charged at PKR 200/kg and collected at airport check-in.'
                                : 'Baggage selection window has closed (within 24 hours of departure).',
                            style: TextStyle(
                              fontSize: 12,
                              color: canModify
                                  ? Colors.grey.shade700
                                  : Colors.red.shade600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (canModify)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAddBaggageSheet,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Add Return Baggage',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                  ] else ...[
                    // Per-passenger summary
                    ...List.generate(returnBaggageData.length, (i) {
                      final b = returnBaggageData[i] as Map<String, dynamic>;
                      final totalKg = (b['totalKg'] as num?)?.toDouble() ?? 0;
                      final freeKg = (b['freeKg'] as num?)?.toDouble() ?? 20;
                      final extraKg = (totalKg - freeKg).clamp(0, 999);
                      final extraPrice =
                          (b['extraPrice'] as num?)?.toDouble() ?? 0;
                      return Padding(
                        padding: EdgeInsets.only(bottom: spacingUnit(0.75)),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: Colors.green.shade600),
                            SizedBox(width: spacingUnit(0.75)),
                            Expanded(
                              child: Text(
                                'Pax ${i + 1}: ${totalKg.toStringAsFixed(0)} kg total'
                                '${extraKg > 0 ? ' (+${extraKg.toStringAsFixed(0)} kg extra)' : ' (included)'}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black87),
                              ),
                            ),
                            if (extraPrice > 0)
                              Text(
                                'PKR ${extraPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: TravelloTheme.primaryDark,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    // Payment due note
                    if (pendingPayment > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payment_rounded,
                                size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PKR ${pendingPayment.toStringAsFixed(0)} payable at airport check-in',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (canModify)
                      TextButton.icon(
                        onPressed: _showAddBaggageSheet,
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: TravelloTheme.primaryMain),
                        label: const Text(
                          'Modify Return Baggage',
                          style: TextStyle(color: TravelloTheme.primaryMain),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBaggageSheet() {
    // Read free allowance from saved baggage data (matches the booking flow)
    final baggageData = _booking['baggageData'] as List<dynamic>? ?? [];
    final freeKg = baggageData.isNotEmpty
        ? ((baggageData.first as Map<String, dynamic>)['freeKg'] as num?)
                ?.toDouble() ??
            20.0
        : 20.0;
    const double ratePerKg = _baggageRatePerKg; // PKR 200/kg

    // Extra-kg tiers — price = extraKg × ratePerKg (consistent with booking flow)
    final List<int> extraTiers = [0, 5, 10, 15, 20, 30];
    final List<Map<String, dynamic>> options = extraTiers.map((extra) {
      final totalKg = freeKg + extra;
      final price = (extra * ratePerKg).toInt();
      return {
        'extraKg': extra,
        'totalKg': totalKg,
        'price': price,
      };
    }).toList();

    final passengers = _booking['passengers'] as List<dynamic>? ?? [];
    final passengerCount = passengers.length.clamp(1, 9);

    // Pre-fill with existing selections if modifying
    final existingData = _booking['returnBaggageData'] as List<dynamic>? ?? [];
    final List<int> selectedExtraKgs = List.generate(passengerCount, (i) {
      if (i < existingData.length) {
        final b = existingData[i] as Map<String, dynamic>;
        final savedTotal = (b['totalKg'] as num?)?.toDouble() ?? freeKg;
        final savedExtra = (savedTotal - freeKg).clamp(0, 9999).toInt();
        // snap to nearest tier
        return extraTiers.contains(savedExtra) ? savedExtra : 0;
      }
      return 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Compute total extra charge across all passengers
          int totalCharge = selectedExtraKgs.fold(
              0, (sum, extra) => sum + (extra * ratePerKg).toInt());

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              TravelloTheme.primaryMain.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.luggage_rounded,
                            color: TravelloTheme.primaryDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Return Baggage',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${freeKg.toStringAsFixed(0)} kg included in your fare · PKR 200/kg extra',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Free allowance chip
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.airplane_ticket_outlined,
                            size: 15, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${freeKg.toStringAsFixed(0)} kg checked baggage already included in your ticket price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Divider(
                    height: 24,
                    color: Colors.grey.shade200,
                    indent: 16,
                    endIndent: 16),

                // Per-passenger selection
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: passengerCount,
                    itemBuilder: (_, pIdx) {
                      final pList =
                          _booking['passengers'] as List<dynamic>? ?? [];
                      final p = pIdx < pList.length
                          ? pList[pIdx] as Map<String, dynamic>
                          : <String, dynamic>{};
                      final pName =
                          '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'
                              .trim();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: TravelloTheme.primaryMain
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${pIdx + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: TravelloTheme.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pName.isEmpty
                                      ? 'Passenger ${pIdx + 1}'
                                      : pName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...options.map((opt) {
                            final extraKg = opt['extraKg'] as int;
                            final totalKg = opt['totalKg'] as double;
                            final price = opt['price'] as int;
                            final isSelected =
                                selectedExtraKgs[pIdx] == extraKg;

                            return GestureDetector(
                              onTap: () => setSheet(
                                  () => selectedExtraKgs[pIdx] = extraKg),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? TravelloTheme.primaryMain
                                          .withValues(alpha: 0.07)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? TravelloTheme.primaryMain
                                        : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? TravelloTheme.primaryMain
                                          : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${totalKg.toStringAsFixed(0)} kg total',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            extraKg == 0
                                                ? 'Included in fare'
                                                : '+$extraKg kg extra (PKR 200/kg)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      price == 0
                                          ? 'FREE'
                                          : 'PKR ${_formatPKR(price)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: price == 0
                                            ? Colors.green.shade600
                                            : TravelloTheme.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (pIdx < passengerCount - 1)
                            Divider(height: 24, color: Colors.grey.shade200),
                        ],
                      );
                    },
                  ),
                ),

                // ── Footer: total + payment note + button ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade200)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Extra baggage charge',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                            Text(
                              totalCharge == 0
                                  ? 'PKR 0'
                                  : 'PKR ${_formatPKR(totalCharge)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: totalCharge == 0
                                    ? Colors.green.shade600
                                    : TravelloTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        // Payment note
                        if (totalCharge > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 5),
                              Text(
                                'This amount is collected at airport check-in',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          height: R.rh(context, 50),
                          child: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final sheetNavigator = Navigator.of(ctx);
                              final updated = List.generate(
                                passengerCount,
                                (i) {
                                  final extra = selectedExtraKgs[i];
                                  final total = freeKg + extra;
                                  final price = (extra * ratePerKg).toInt();
                                  return {
                                    'mode': extra == 0 ? 'none' : 'custom',
                                    'freeKg': freeKg,
                                    'extraKg': extra,
                                    'totalKg': total,
                                    'extraPrice': price.toDouble(),
                                  };
                                },
                              );

                              final bookingId =
                                  _booking['bookingId'] as String? ?? '';
                              if (bookingId.isNotEmpty) {
                                await BookingService.updateBookingField(
                                  bookingId,
                                  'returnBaggageData',
                                  updated,
                                );
                              }

                              setState(() {
                                _booking['returnBaggageData'] = updated;
                              });

                              if (mounted) sheetNavigator.pop();

                              if (mounted) {
                                final chargeMsg = totalCharge > 0
                                    ? 'PKR ${_formatPKR(totalCharge)} payable at check-in.'
                                    : 'No extra charge — included in fare.';
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Baggage added. $chargeMsg',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TravelloTheme.primaryMain,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Add to Booking',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatPKR(int amount) {
    // Format with comma separator: 3200 → 3,200
    final s = amount.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(s[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  🎯 ACTIONS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _copyPNR() async {
    await Clipboard.setData(ClipboardData(text: _booking['pnr'] ?? 'N/A'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('PNR copied to clipboard!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _downloadETicket() async {
    final bookingType = _booking['bookingType'] as String? ?? 'flight';

    if (bookingType == 'hotel') {
      await _downloadHotelConfirmation();
    } else if (bookingType == 'train') {
      await _downloadRailwayTicket();
    } else {
      await _downloadFlightTicket();
    }
  }

  Future<void> _downloadFlightTicket() async {
    // Navigate to the full airline-grade e-ticket screen (same as payment success)
    Get.toNamed(AppLink.eTicket, arguments: _booking);
  }

  Future<void> _downloadRailwayTicket() async {
    setState(() => _downloadingPdf = true);
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
      );

      final td = _booking['trainDetails'] as Map<String, dynamic>?;
      final returnTd = _booking['returnTrainDetails'] as Map<String, dynamic>?;
      final isRoundTrip = _booking['isRoundTrip'] == true && returnTd != null;
      final passengers = _booking['allPassengers'] as List<dynamic>? ?? [];
      final rawSeats = _booking['seatNumbers'] as List<dynamic>? ?? [];
      final rawTickets = _booking['ticketNumbers'] as List<dynamic>? ?? [];
      final coach = _booking['coach'] as String? ?? 'B-1';
      final pnr = _booking['pnr'] as String? ?? 'N/A';
      final grandTotal = _booking['total'] as double? ?? 0.0;
      final baseFare = _booking['amount'] as double? ?? 0.0;
      final paxCount = passengers.isEmpty ? 1 : passengers.length;
      final farePerPax = paxCount > 0 ? baseFare / paxCount : baseFare;
      const rabta = 10.0;

      // Get seat selections for both journeys
      final outboundSeats = isRoundTrip
          ? (_booking['outboundSeatSelections'] as List<dynamic>? ?? [])
          : (_booking['seatSelections'] as List<dynamic>? ?? []);
      final returnSeats = isRoundTrip
          ? (_booking['returnSeatSelections'] as List<dynamic>? ?? [])
          : [];

      // Generate outbound tickets for all passengers
      for (int i = 0; i < passengers.length; i++) {
        final pax = passengers[i] as Map<String, dynamic>;
        final paxName = pax['name'] as String? ?? 'Passenger ${i + 1}';
        final rawCnic = pax['cnic'] as String? ?? '';
        final cnic = rawCnic.isNotEmpty
            ? rawCnic.replaceAll('-', '').replaceAll(' ', '')
            : (pax['passportOrId'] as String?)
                    ?.replaceAll('-', '')
                    .replaceAll(' ', '') ??
                '--';
        final phone = pax['phone'] as String? ?? '--';
        // Calculate age from DOB if age field is missing
        String age = pax['age'] as String? ?? '';
        if (age.isEmpty) {
          final dobStr = pax['dateOfBirth'] as String? ?? '';
          if (dobStr.isNotEmpty) {
            try {
              final dob = DateTime.parse(dobStr);
              final now = DateTime.now();
              int ageNum = now.year - dob.year;
              if (now.month < dob.month ||
                  (now.month == dob.month && now.day < dob.day)) {
                ageNum--;
              }
              age = ageNum.toString();
            } catch (_) {
              age = '--';
            }
          } else {
            age = '--';
          }
        }
        final gender = pax['gender'] as String? ?? 'Male';
        final rawType = pax['concessionType'] as String? ?? 'ADULT';
        final paxType = rawType == 'CHILD_3_10'
            ? 'CHILD'
            : rawType == 'INFANT'
                ? 'INFANT'
                : 'ADULT';

        // Get seat and coach from actual selections (outbound)
        String seat = '${i + 1}'; // fallback
        String seatCoach = coach; // fallback
        if (i < outboundSeats.length) {
          final seatData = outboundSeats[i] as Map<String, dynamic>;
          final seatName = (seatData['seatName'] ?? '').toString();
          if (seatName.isNotEmpty) {
            seat = seatName;
            seatCoach = (seatData['coach'] ?? coach).toString();
          }
        } else if (i < rawSeats.length) {
          seat = rawSeats[i].toString();
        }

        final ticketNo = i < rawTickets.length ? rawTickets[i].toString() : pnr;

        final double thisFare = rawType == 'CHILD_3_10'
            ? farePerPax * 0.5
            : rawType == 'INFANT'
                ? 0.0
                : farePerPax;
        final double thisTotal = thisFare + (rawType == 'ADULT' ? rabta : 0.0);

        _addRailwayTicketPage(
          doc,
          td: td,
          pnr: pnr,
          coach: seatCoach,
          seat: seat,
          ticketNo: ticketNo,
          paxName: paxName,
          phone: phone,
          cnic: cnic,
          age: age,
          gender: gender,
          paxType: paxType,
          fare: thisFare,
          rabta: rawType == 'ADULT' ? rabta : 0.0,
          total: thisTotal,
          grandTotal: grandTotal,
          paxIndex: i,
          paxCount: passengers.length,
          isReturn: false,
        );
      }

      if (passengers.isEmpty) {
        _addRailwayTicketPage(
          doc,
          td: td,
          pnr: pnr,
          coach: coach,
          seat: '1',
          ticketNo: pnr,
          paxName: _booking['passengerName'] as String? ?? 'Passenger',
          phone: _booking['phone'] as String? ?? '--',
          cnic: '--',
          age: '--',
          gender: 'Male',
          paxType: 'ADULT',
          fare: baseFare,
          rabta: rabta,
          total: baseFare + rabta,
          grandTotal: grandTotal,
          paxIndex: 0,
          paxCount: 1,
          isReturn: false,
        );
      }

      // Generate return tickets if round trip
      if (isRoundTrip) {
        for (int i = 0; i < passengers.length; i++) {
          final pax = passengers[i] as Map<String, dynamic>;
          final paxName = pax['name'] as String? ?? 'Passenger ${i + 1}';
          final rawCnic = pax['cnic'] as String? ?? '';
          final cnic = rawCnic.isNotEmpty
              ? rawCnic.replaceAll('-', '').replaceAll(' ', '')
              : (pax['passportOrId'] as String?)
                      ?.replaceAll('-', '')
                      .replaceAll(' ', '') ??
                  '--';
          final phone = pax['phone'] as String? ?? '--';
          // Calculate age from DOB if age field is missing
          String age = pax['age'] as String? ?? '';
          if (age.isEmpty) {
            final dobStr = pax['dateOfBirth'] as String? ?? '';
            if (dobStr.isNotEmpty) {
              try {
                final dob = DateTime.parse(dobStr);
                final now = DateTime.now();
                int ageNum = now.year - dob.year;
                if (now.month < dob.month ||
                    (now.month == dob.month && now.day < dob.day)) {
                  ageNum--;
                }
                age = ageNum.toString();
              } catch (_) {
                age = '--';
              }
            } else {
              age = '--';
            }
          }
          final gender = pax['gender'] as String? ?? 'Male';
          final rawType = pax['concessionType'] as String? ?? 'ADULT';
          final paxType = rawType == 'CHILD_3_10'
              ? 'CHILD'
              : rawType == 'INFANT'
                  ? 'INFANT'
                  : 'ADULT';

          // Get seat and coach from actual selections (return)
          String seat = '${i + 1}'; // fallback
          String seatCoach = coach; // fallback
          if (i < returnSeats.length) {
            final seatData = returnSeats[i] as Map<String, dynamic>;
            final seatName = (seatData['seatName'] ?? '').toString();
            if (seatName.isNotEmpty) {
              seat = seatName;
              seatCoach = (seatData['coach'] ?? coach).toString();
            }
          } else if (i < rawSeats.length) {
            seat = rawSeats[i].toString();
          }

          final ticketNo =
              i < rawTickets.length ? rawTickets[i].toString() : pnr;

          final double thisFare = rawType == 'CHILD_3_10'
              ? farePerPax * 0.5
              : rawType == 'INFANT'
                  ? 0.0
                  : farePerPax;
          final double thisTotal =
              thisFare + (rawType == 'ADULT' ? rabta : 0.0);

          _addRailwayTicketPage(
            doc,
            td: returnTd,
            pnr: pnr,
            coach: seatCoach,
            seat: seat,
            ticketNo: ticketNo,
            paxName: paxName,
            phone: phone,
            cnic: cnic,
            age: age,
            gender: gender,
            paxType: paxType,
            fare: thisFare,
            rabta: rawType == 'ADULT' ? rabta : 0.0,
            total: thisTotal,
            grandTotal: grandTotal,
            paxIndex: i,
            paxCount: passengers.length,
            isReturn: true,
          );
        }

        if (passengers.isEmpty) {
          _addRailwayTicketPage(
            doc,
            td: returnTd,
            pnr: pnr,
            coach: coach,
            seat: '1',
            ticketNo: pnr,
            paxName: _booking['passengerName'] as String? ?? 'Passenger',
            phone: _booking['phone'] as String? ?? '--',
            cnic: '--',
            age: '--',
            gender: 'Male',
            paxType: 'ADULT',
            fare: baseFare,
            rabta: rabta,
            total: baseFare + rabta,
            grandTotal: grandTotal,
            paxIndex: 0,
            paxCount: 1,
            isReturn: true,
          );
        }
      }

      await Printing.layoutPdf(
          name: 'Railway-Ticket-${_booking['pnr']}.pdf',
          onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _downloadHotelConfirmation() async {
    setState(() => _downloadingPdf = true);
    try {
      final fontRegular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Regular.ttf'));
      final fontBold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Bold.ttf'));
      final fontMedium =
          pw.Font.ttf(await rootBundle.load('assets/fonts/Ubuntu-Medium.ttf'));

      final hotelDetails = _booking['hotelDetails'] as Map<String, dynamic>?;
      final hotelName = hotelDetails?['hotelName'] as String? ?? 'Hotel';
      final city = hotelDetails?['city'] as String? ?? '';
      final address = hotelDetails?['address'] as String? ?? '';
      final checkIn = hotelDetails?['checkIn'] as String? ?? 'N/A';
      final checkOut = hotelDetails?['checkOut'] as String? ?? 'N/A';
      final roomType = hotelDetails?['roomType'] as String? ?? 'Standard Room';
      final nights = (hotelDetails?['nights'] as num?)?.toInt() ?? 1;
      final rating = (hotelDetails?['rating'] as num?)?.toDouble() ?? 0.0;
      final pnr = _booking['pnr'] as String? ?? 'N/A';
      final guests = (_booking['passengerCount'] as num?)?.toInt() ?? 1;
      final passengers = _booking['allPassengers'] as List<dynamic>? ?? [];
      final basePrice = (_booking['amount'] as num?)?.toDouble() ?? 0.0;
      final total = (_booking['total'] as num?)?.toDouble() ?? 0.0;
      final serviceCharge = basePrice * 0.05;
      final tourismTax = basePrice * 0.03;
      final gstVal = basePrice * 0.16;
      final issuedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

      final fmtPkr = NumberFormat('#,##,###', 'en_PK');
      String pkr(double v) => 'PKR ${fmtPkr.format(v.round())}';

      // First guest details
      final firstPax = passengers.isNotEmpty
          ? passengers[0] as Map<String, dynamic>
          : <String, dynamic>{};
      final guestName = (firstPax['name'] as String?)?.toUpperCase() ?? 'GUEST';
      final guestCnic = firstPax['cnic'] as String? ?? '';
      final guestPhone = firstPax['phone'] as String? ?? '';
      final guestGender = firstPax['gender'] as String? ?? 'Male';

      // ── PDF Color Palette (matches image 2) ──────────────────
      const pdfGold = PdfColor(0.831, 0.686, 0.216); // #D4AF37
      const pdfGreen = PdfColor(0.063, 0.725, 0.506);
      const pdfSurface = PdfColor(0.98, 0.98, 0.98);
      const pdfBorderLight = PdfColor(0.878, 0.878, 0.878);
      const pdfTxtPri = PdfColor(0.1, 0.1, 0.1);
      const pdfTxtSec = PdfColor(0.35, 0.35, 0.35);

      // ── Section header ────────────────────────────────────────
      pw.Widget secHeader(String title) => pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
                color: pdfGold,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
            child: pw.Row(children: [
              pw.Container(width: 3, height: 12, color: PdfColors.white),
              pw.SizedBox(width: 8),
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      font: fontBold,
                      letterSpacing: 0.6)),
            ]),
          );

      pw.Widget kvRow(String k, String v, {bool bold = false}) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(k,
                      style: pw.TextStyle(
                          fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                  pw.Text(v,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight:
                              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: pdfTxtPri,
                          font: bold ? fontBold : fontMedium)),
                ]),
          );

      pw.Widget thinDiv() => pw.Divider(color: pdfBorderLight, thickness: 0.5);

      final doc =
          pw.Document(title: 'Hotel Tax Invoice — $pnr', author: 'Travello AI');

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 38, vertical: 30),
        build: (pw.Context ctx) => [
          // ── HEADER ─────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: const pw.BoxDecoration(
                color: pdfGold,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 52,
                    height: 52,
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(8))),
                    child: pw.Center(
                        child: pw.Text('H',
                            style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfGold,
                                font: fontBold))),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Travello AI',
                              style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold)),
                          pw.Text('Hotel Tax Invoice & Stay Receipt',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColors.white,
                                  font: fontMedium)),
                          pw.SizedBox(height: 4),
                          pw.Text('NTN: 1234567-8  |  STRN: SC-01234-56789',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.white,
                                  font: fontRegular)),
                        ]),
                  ),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  color: PdfColors.white, width: 2),
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4))),
                          child: pw.Text(pnr,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold,
                                  letterSpacing: 2)),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(issuedAt,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.white,
                                font: fontRegular)),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: const pw.BoxDecoration(
                              color: pdfGreen,
                              borderRadius:
                                  pw.BorderRadius.all(pw.Radius.circular(4))),
                          child: pw.Text('CONFIRMED',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  font: fontBold,
                                  letterSpacing: 0.5)),
                        ),
                      ]),
                ]),
          ),
          pw.SizedBox(height: 12),

          // ── ISSUED BY / BILL TO ─────────────────────────────────
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: pdfSurface,
                    border: pw.Border.all(color: pdfBorderLight),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ISSUED BY',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfGold,
                              font: fontBold,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 5),
                      pw.Text('Travello AI (Pvt.) Ltd.',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTxtPri,
                              font: fontBold)),
                      pw.SizedBox(height: 2),
                      pw.Text('15-B, Clifton Block 5, Karachi, Pakistan',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('support@travelloai.com',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('+92 300 1234567',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('www.travelloai.com',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                    ]),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: pdfSurface,
                    border: pw.Border.all(color: pdfBorderLight),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO (GUEST)',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfGold,
                              font: fontBold,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 5),
                      pw.Text(guestName,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfTxtPri,
                              font: fontBold)),
                      pw.SizedBox(height: 2),
                      if (guestCnic.isNotEmpty)
                        pw.Text('CNIC: $guestCnic',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      if (guestPhone.isNotEmpty)
                        pw.Text('Phone: $guestPhone',
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      pw.Text('Gender: $guestGender',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                      pw.Text('Total Guests: $guests',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfTxtSec,
                              font: fontRegular)),
                    ]),
              ),
            ),
          ]),
          pw.SizedBox(height: 12),

          // ── HOTEL INFORMATION ───────────────────────────────────
          secHeader('HOTEL INFORMATION'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: pdfSurface,
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(hotelName,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfTxtPri,
                          font: fontBold)),
                  pw.SizedBox(height: 4),
                  if (rating > 0)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: const pw.BoxDecoration(
                          color: pdfGold,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Text('${rating.toInt()}-Star',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              font: fontBold)),
                    ),
                  pw.SizedBox(height: 6),
                  if (address.isNotEmpty)
                    pw.Text(address,
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                  if (city.isNotEmpty)
                    pw.Text('$city, Pakistan',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtSec, font: fontRegular)),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text('Check-In',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                          pw.Text(checkIn,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTxtPri,
                                  font: fontBold)),
                          pw.Text('2:00 PM',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                        ])),
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text('Check-Out',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                          pw.Text(checkOut,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTxtPri,
                                  font: fontBold)),
                          pw.Text('12:00 PM',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                        ])),
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text('Nights',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfTxtSec,
                                  font: fontRegular)),
                          pw.Text('$nights',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTxtPri,
                                  font: fontBold)),
                        ])),
                  ]),
                ]),
          ),
          pw.SizedBox(height: 12),

          // ── STAY SUMMARY STRIP ──────────────────────────────────
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const pw.BoxDecoration(
                color: pdfGold,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('NIGHTS',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.white,
                                font: fontRegular,
                                letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('$nights',
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: fontBold)),
                      ]),
                  pw.Container(width: 1, height: 30, color: PdfColors.white),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('ROOM TYPE',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.white,
                                font: fontRegular,
                                letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text(roomType,
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: fontBold)),
                      ]),
                  pw.Container(width: 1, height: 30, color: PdfColors.white),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('GUESTS',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.white,
                                font: fontRegular,
                                letterSpacing: 0.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('$guests',
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: fontBold)),
                      ]),
                ]),
          ),
          pw.SizedBox(height: 12),

          // ── SERVICES & CHARGES ──────────────────────────────────
          secHeader('SERVICES & CHARGES  (FBR Tax Invoice)'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: pdfBorderLight, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdfSurface),
                children: ['#', 'DESCRIPTION', 'UNIT PRICE', 'QTY', 'AMOUNT']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfTxtPri,
                                  font: fontBold,
                                  letterSpacing: 0.4)),
                        ))
                    .toList(),
              ),
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('1',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontRegular))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$roomType — Hotel Accommodation',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfTxtPri,
                                font: fontBold)),
                        pw.SizedBox(height: 2),
                        pw.Text('Check-In: $checkIn',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                color: pdfTxtSec,
                                font: fontRegular)),
                        pw.Text('Check-Out: $checkOut',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      ]),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                        nights > 0 ? pkr(basePrice / nights) : pkr(basePrice),
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontRegular))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${nights}N x 1 Rm',
                        style: pw.TextStyle(
                            fontSize: 9, color: pdfTxtPri, font: fontRegular))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(pkr(basePrice),
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfTxtPri,
                            font: fontBold))),
              ]),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── FARE BREAKDOWN ──────────────────────────────────────
          secHeader('FARE BREAKDOWN'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: pdfSurface,
                border: pw.Border.all(color: pdfBorderLight),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: [
              kvRow('Base Accommodation', pkr(basePrice)),
              thinDiv(),
              kvRow('Service Charge (5%)', pkr(serviceCharge)),
              kvRow('Tourism / FED Tax (3%)', pkr(tourismTax)),
              kvRow('GST @ 16% (FBR)', pkr(gstVal)),
              pw.SizedBox(height: 6),
              pw.Divider(color: pdfGold, thickness: 1.5),
              pw.SizedBox(height: 6),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL PAYABLE',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfTxtPri,
                            font: fontBold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: const pw.BoxDecoration(
                          color: pdfGold,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(4))),
                      child: pw.Text(pkr(total),
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              font: fontBold)),
                    ),
                  ]),
            ]),
          ),
          pw.SizedBox(height: 12),

          // ── GUEST LIST ──────────────────────────────────────────
          if (passengers.isNotEmpty) ...[
            secHeader('GUEST DETAILS'),
            pw.SizedBox(height: 8),
            ...passengers.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value as Map<String, dynamic>;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    color: pdfSurface,
                    border: pw.Border.all(color: pdfBorderLight),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    decoration: const pw.BoxDecoration(
                        color: pdfGold, shape: pw.BoxShape.circle),
                    child: pw.Center(
                        child: pw.Text('${i + 1}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                font: fontBold))),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                        pw.Text((p['name'] as String? ?? 'N/A').toUpperCase(),
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfTxtPri,
                                font: fontBold)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                            'CNIC: ${p['cnic'] as String? ?? '—'}  |  Phone: ${p['phone'] as String? ?? '—'}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: pdfTxtSec,
                                font: fontRegular)),
                      ])),
                ]),
              );
            }),
            pw.SizedBox(height: 12),
          ],

          // ── IMPORTANT INFO ──────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: const PdfColor(1.0, 0.98, 0.9),
                border: pw.Border.all(color: const PdfColor(0.95, 0.85, 0.5)),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('IMPORTANT INFORMATION',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfGold,
                          font: fontBold,
                          letterSpacing: 0.5)),
                  pw.SizedBox(height: 6),
                  for (final tip in [
                    'Check-in time: 2:00 PM | Check-out time: 12:00 PM',
                    'Carry valid CNIC/Passport matching booking details',
                    'Show booking confirmation at reception',
                    'Cancellation allowed up to 24 hours before check-in',
                    'Please check with hotel for restrictions. This invoice is FBR-compliant.',
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 4,
                              height: 4,
                              margin:
                                  const pw.EdgeInsets.only(top: 3, right: 6),
                              decoration: const pw.BoxDecoration(
                                  color: pdfGold, shape: pw.BoxShape.circle),
                            ),
                            pw.Expanded(
                                child: pw.Text(tip,
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        color: pdfTxtSec,
                                        font: fontRegular))),
                          ]),
                    ),
                ]),
          ),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Hotel_Invoice_$pnr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _addRailwayTicketPage(
    pw.Document doc, {
    required Map<String, dynamic>? td,
    required String pnr,
    required String coach,
    required String seat,
    required String ticketNo,
    required String paxName,
    required String phone,
    required String cnic,
    required String age,
    required String gender,
    required String paxType,
    required double fare,
    required double rabta,
    required double total,
    required double grandTotal,
    required int paxIndex,
    required int paxCount,
    required bool isReturn,
  }) {
    const pgGreen = PdfColor(0.114, 0.388, 0.114);
    const pgGreenLight = PdfColor(0.882, 0.961, 0.878);
    const pgText = PdfColor(0.1, 0.1, 0.1);
    const pgGrey = PdfColor(0.45, 0.45, 0.45);
    const pgBorder = PdfColor(0.82, 0.82, 0.82);

    final trainName = td?['trainName'] as String? ?? 'Pakistan Express';
    final trainNumber = td?['trainNumber'] as String? ?? '45UP';
    final fromStation = td?['from'] as String? ?? 'N/A';
    final toStation = td?['to'] as String? ?? 'N/A';
    final fromCode = td?['fromCode'] as String? ?? '';
    final toCode = td?['toCode'] as String? ?? '';
    final depTime = td?['departure'] as String? ?? '--:--';
    final classType = td?['class'] as String? ?? 'Economy';
    final date = td?['date'] as String? ?? '--';

    final fromLabel =
        fromCode.isNotEmpty ? '${fromCode.toUpperCase()} JN.' : fromStation;
    final toLabel =
        toCode.isNotEmpty ? '${toCode.toUpperCase()} JN.' : toStation;
    final coachSeat = '$seat/$coach';
    final qrData =
        'PR|PNR:$pnr|TRN:$trainNumber|PAX:$paxName|SEAT:$coachSeat|DT:$date';

    pw.Widget row(String labelEn, String value, {bool bold = false}) {
      return pw.Container(
        decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: pgBorder, width: 0.5))),
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 4,
              child: pw.Text(labelEn,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: pgText,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: pgText,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ],
        ),
      );
    }

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const pw.BoxDecoration(
              color: pgGreen,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PAKISTAN RAILWAYS',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Online Ticket',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                    if (paxCount > 1)
                      pw.Text('${paxIndex + 1} of $paxCount',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('Pakistan Railway Ticket',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: pgText)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: pw.BoxDecoration(
                color: isReturn ? const PdfColor(0.9, 0.5, 0.2) : pgGreen,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                isReturn ? 'RETURN JOURNEY' : 'OUTBOUND JOURNEY',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Column(children: [
              pw.Text('$trainNumber/$trainName',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: pgText)),
              pw.Text('$fromLabel to $toLabel',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: pgText)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pgBorder),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Column(children: [
              row('Departure Date', '$date $depTime'),
              row('Class', classType),
              row('Coach/Seat', coachSeat, bold: true),
              row('Name', paxName, bold: true),
              row('CNIC', cnic),
              row('Age', age),
              row('Gender', gender),
              row('Phone', phone),
              row('Type', paxType),
              pw.SizedBox(height: 2),
              row('Fare', 'Rs.${fare.toStringAsFixed(2)}'),
              if (rabta > 0)
                row('RABTA (Database)', 'Rs.${rabta.toStringAsFixed(2)}'),
              row('Reservation (Online)', 'Rs.0.00'),
              pw.SizedBox(height: 2),
              pw.Container(
                color: pgGreenLight,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: pw.Row(children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Total:',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: pgText)),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Rs.${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: pgGreen)),
                  ),
                ]),
              ),
              row('Voucher', '--'),
            ]),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: pgGreenLight,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    'A traveler must provide his/her original Name, CNIC No and Mobile No.',
                    style: const pw.TextStyle(fontSize: 9, color: pgText)),
                pw.SizedBox(height: 3),
                pw.Text(
                    'Traveling with fake information on Ticket is not allowed.',
                    style: const pw.TextStyle(fontSize: 9, color: pgText)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 90,
                height: 90,
                color: pgGreen,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(ticketNo,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: pgGrey,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Online Ticket',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: pgGreen,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Pakistan Railways Official',
                        style: const pw.TextStyle(fontSize: 8, color: pgGrey)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
