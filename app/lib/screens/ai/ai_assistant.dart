import 'dart:async';
import 'dart:convert';

import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/models/ai_chat.dart';
import 'package:flight_app/models/notification.dart' show NotificationModel;
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/services/location_service.dart';
import 'package:flight_app/services/notification_service.dart';
import 'package:flight_app/widgets/booking/card_payment_sheet.dart';
import 'package:flight_app/widgets/booking/flight_seat_picker.dart';
import 'package:flight_app/widgets/railway/train_seat_picker.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' show Get, GetNavigation, Inst;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Send button with hover scale effect
// ─────────────────────────────────────────────────────────────────────────────
class _SendButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final bool enabled;
  const _SendButton(
      {required this.onPressed,
      required this.backgroundColor,
      required this.iconColor,
      this.enabled = true});
  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = enabled),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: (_hovered && enabled) ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37)
                      .withValues(alpha: _hovered ? 0.4 : 0.2),
                  blurRadius: _hovered ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: enabled ? widget.onPressed : null,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small frosted-glass circular icon button used in the AI chat header
// ─────────────────────────────────────────────────────────────────────────────
class _GlassHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  const _GlassHeaderButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 17,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white70, size: size),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late AnimationController _entryController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // ── Hover state ────────────────────────────────────────────────────────────
  int _hoveredSuggestion = -1;

  // ── Chat state ─────────────────────────────────────────────────────────────
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String? _conversationId;
  String? _pendingAction;
  Map<String, dynamic>? _pendingBookingData;
  bool _savingForLater = false;
  bool _confirmingCar = false;

  // Passenger details collected via the native form (agent mode). Payment is
  // hard-gated on this being non-null — chat never collects identity fields.
  List<Map<String, dynamic>>? _agentPassengers;
  Map<String, dynamic>? _agentContact;
  bool _collectingPassengers = false;

  static const _kConvIdKey = 'ai_conversation_id';

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _loadConversationState();
  }

  // ── Conversation persistence ───────────────────────────────────────────────

  Future<void> _loadConversationState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kConvIdKey);

    if (savedId == null) {
      _addWelcomeMessage();
      return;
    }

    setState(() => _isLoadingHistory = true);
    try {
      final msgs = await ApiClient.getAgentMessages(savedId);
      if (!mounted) return;
      if (msgs.isEmpty) {
        _addWelcomeMessage();
      } else {
        setState(() {
          _conversationId = savedId;
          for (final m in msgs) {
            final role = m['role'] as String? ?? 'assistant';
            final content = m['content'] as String? ?? '';
            if (content.isEmpty) continue;
            _messages.add(ChatMessage(
              id: m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
              message: content,
              isUser: role == 'user',
              timestamp: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
            ));
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) _addWelcomeMessage();
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _addWelcomeMessage() {
    if (_messages.isNotEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: '1',
        message: "Hello! 👋 I'm your AI Travel Assistant for Pakistan. How can I help you plan your journey today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _fetchAndShowProactiveAlert();
  }

  Future<void> _fetchAndShowProactiveAlert() async {
    try {
      final data = await ApiClient.getProactiveAlert();
      if (!mounted || data == null) return;
      final alert = data['alert'] as String;

      // File the same alert in the notifications panel. The chat card is only
      // seen by someone who opens the assistant, so a trip reminder used to
      // vanish the moment they navigated away — the panel is where it belongs.
      // Deduped on trip_key so reopening the chat can't stack duplicates.
      _fileTripAlertNotification(data, alert);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          message: alert,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  /// Best-effort — a notification failure must never disturb the chat.
  void _fileTripAlertNotification(Map<String, dynamic> data, String alert) {
    try {
      final tripKey = (data['trip_key'] as String?) ?? '';
      if (tripKey.isEmpty) return;
      final title = (data['title'] as String?)?.trim();
      final category = (data['category'] as String?) ?? 'ai';
      Get.find<NotificationController>().addNotificationOnce(
        tripKey,
        NotificationModel(
          type: 'info',
          category: category.isNotEmpty ? category : 'ai',
          tag: 'AI Trip',
          title: (title != null && title.isNotEmpty)
              ? title
              : 'Upcoming trip reminder',
          subtitle: alert,
          date: 'Just now',
          isRead: false,
        ),
      );
    } catch (_) {}
  }

  /// Mirror the manual flows: a confirmed booking files a notification — plus
  /// its check-in and leave-home reminders — into the notifications panel.
  /// Agent bookings were silent here; NotificationService was only ever called
  /// from the manual confirmation screens, so a trip booked through chat left
  /// no trace in the panel at all.
  ///
  /// Best-effort: a notification failure must never disturb a paid booking.
  void _fileBookingNotification(Map<String, dynamic> data, String pnr) {
    try {
      final svc = NotificationService.instance;
      final type = (data['booking_type'] as String?) ?? 'flight';
      final from = (data['origin'] as String?) ?? '';
      final to = (data['destination'] as String?) ?? '';
      final date = _fmtNotifDate(data['travel_date'] as String?);
      final departure = (data['departure_time'] as String?) ?? 'N/A';

      if (type == 'train') {
        svc.trainBooked(
          trainName: (data['train_name'] as String?) ??
              (data['airline_or_train_name'] as String?) ??
              'Pakistan Railways',
          fromStation: from,
          toStation: to,
          date: date,
          departure: departure,
          seatClass: (data['train_class'] as String?) ?? 'Economy',
          // coach/seat deliberately omitted — assigned at the station, and a
          // guessed seat number would be a fabricated ticket detail.
          pnr: pnr,
        );
      } else if (type == 'hotel') {
        svc.hotelBooked(
          hotelName: (data['hotel_name'] as String?) ?? 'Hotel',
          city: to.isNotEmpty ? to : from,
          roomType: (data['room_type'] as String?) ?? 'Standard Room',
          checkIn: _fmtNotifDate(data['check_in'] as String?),
          checkOut: _fmtNotifDate(data['check_out'] as String?),
          bookingRef: pnr,
        );
      } else {
        svc.flightBooked(
          airline: (data['airline_or_train_name'] as String?) ?? 'Flight',
          flightNumber: (data['flight_number'] as String?) ?? '',
          fromCode: from,
          toCode: to,
          date: date,
          departure: departure,
          pnr: pnr,
          seatClass: _prettyCabin(data['cabin_class'] as String?),
        );
      }
    } catch (_) {}
  }

  /// 'YYYY-MM-DD' → '22 Jul 2026', matching how the manual flows label dates.
  static String _fmtNotifDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    final d = DateTime.tryParse(raw);
    return d != null ? DateFormat('d MMM yyyy').format(d) : raw;
  }

  /// 'ECONOMY' → 'Economy'. Only flight cabins arrive shouted; train classes
  /// come through pre-formatted ('AC Business') and are used as-is.
  static String _prettyCabin(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return 'Economy';
    return c
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _saveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConvIdKey, id);
  }

  Future<void> _startNewChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConvIdKey);
    setState(() {
      _conversationId = null;
      _messages.clear();
      // Drop any half-finished booking bar so a fresh chat starts on the text
      // input, never a leftover "Add Passenger Details" from the old chat.
      _pendingAction = null;
      _pendingBookingData = null;
      _agentPassengers = null;
      _agentContact = null;
    });
    _addWelcomeMessage();
  }

  // Append a booking milestone card AND persist it to the conversation.
  // These cards are built here after a real success (passenger form returned,
  // payment went through), so nothing on the server had written them — which is
  // why reopening the chat used to drop them and leave the thread ending at the
  // booking summary. Saving is best-effort and never blocks the UI.
  void _addMilestoneMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
    final convId = _conversationId;
    if (convId != null) ApiClient.saveAgentNote(convId, text);
  }

  // ── Payment choice handlers ────────────────────────────────────────────────

  void _clearPendingAction() => setState(() {
        _pendingAction = null;
        _pendingBookingData = null;
        _agentPassengers = null;
        _agentContact = null;
      });

  /// Dismissing the card sheet must NOT throw away the booking. Cancelling card
  /// entry means "not by card right now", not "abandon everything" — wiping
  /// _pendingBookingData here discarded the booking, the passenger details, and
  /// the chosen seat, and removed the buttons, leaving the user stranded on the
  /// text box (where a typed "pay" only makes the agent fake a confirmation).
  /// So keep the payment_choice state intact and just reassure them.
  void _onCardSheetCancelled() {
    if (!mounted) return;
    _addMilestoneMessage(
      'No problem — your booking is still here. Tap **Pay with Card** or '
      "**Pay Later** below whenever you're ready.",
    );
  }

  void _showCardPaymentSheet() {
    if (_pendingBookingData == null || _conversationId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardPaymentSheet(
        bookingData: _pendingBookingData!,
        conversationId: _conversationId!,
        passengers: _agentPassengers,
        contact: _agentContact,
        onSuccess: (pnr, amount) {
          // Capture before _clearPendingAction() nulls _pendingBookingData.
          final booked = _pendingBookingData;
          final isPackage = booked?['booking_type'] == 'package';
          _clearPendingAction();
          if (booked != null) {
            // The notification describes a trip (route/dates), so a package hands
            // it the first real component rather than the wrapper, which carries
            // no route of its own.
            _fileBookingNotification(packageComponents(booked).first, pnr);
          }
          // Multi-part trip: carry the outstanding pieces onto the confirmation
          // so the package doesn't dead-end here. The agent gets no turn between
          // the summary and this card, so this is the handoff. A package just
          // paid for everything at once, so there is nothing left to hand off.
          final next =
              isPackage ? '' : (booked?['next_step'] as String?)?.trim() ?? '';
          _addMilestoneMessage(
            '${isPackage ? '✅ **Package Confirmed!**' : '✅ **Booking Confirmed!**'}\n\n'
            '**PNR:** $pnr\n'
            '**Amount Paid:** PKR ${amount.toStringAsFixed(0)}\n\n'
            'A confirmation email has been sent to you. '
            'You can view your ${isPackage ? 'bookings' : 'booking'} in **My Bookings**.'
            '${next.isEmpty ? '' : '\n\n➡️ **Next up:** $next\n\nJust say the word and I\'ll set it up.'}',
          );
        },
        onCancel: _onCardSheetCancelled,
      ),
    );
  }

  Future<void> _saveBookingForLater() async {
    final data = _pendingBookingData;
    if (data == null || _conversationId == null || _savingForLater) return;

    final amount = (data['total_price_pkr'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: "This option doesn't have a confirmed price yet, so I can't "
              'save it. Ask me to show the exact fare first, then try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() => _savingForLater = true);
    try {
      // Same flattening as the payment path: a package saves each piece as its own
      // pending booking, a single booking is a one-item list. Nothing is charged.
      // Linked by the SAME shared packageId the card-payment path uses (see
      // mintPackageId) — without it My Bookings can't group a saved package
      // back into one card, and each piece shows up as its own separate
      // pending booking instead of the whole trip.
      final components = packageComponents(data);
      final isPackage = components.length > 1;
      final packageId = isPackage ? mintPackageId() : null;
      final saved = <String>[];
      double dueTotal = 0.0;

      for (final component in components) {
        final componentAmount =
            (component['total_price_pkr'] as num?)?.toDouble() ?? 0.0;
        if (componentAmount <= 0) continue;

        final booking = await createAgentBooking(
          data: component,
          conversationId: _conversationId!,
          amount: componentAmount,
          passengerName: _agentContact?['contactName'] as String?,
          contactPhone: _agentContact?['contactPhone'] as String?,
          packageId: packageId,
        );
        final pnr = booking['pnr'] as String? ?? '';

        // Persist the passengers collected via the native form onto the pending
        // booking, so a saved-for-later booking carries real traveler rows too.
        final bookingId = booking['booking_id'] as String?;
        if (bookingId != null &&
            _agentPassengers != null &&
            _agentPassengers!.isNotEmpty) {
          await ApiClient.addPassengers(
            bookingId: bookingId,
            passengers: _agentPassengers!,
          );
        }
        dueTotal += componentAmount;
        saved.add(components.length > 1
            ? '${componentLabel(component)} — $pnr'
            : pnr);
      }

      if (!mounted) return;
      _clearPendingAction();
      setState(() => _savingForLater = false);
      _addMilestoneMessage(
        '📌 **Booking Saved!**\n\n'
        '**PNR:** ${saved.join('\n**PNR:** ')}\n'
        '**Amount Due:** PKR ${dueTotal.toStringAsFixed(0)}\n\n'
        "It's saved as pending — you can pay anytime from **My Bookings**.",
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingForLater = false;
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: "I couldn't save that booking (${e.toString().replaceFirst('Exception: ', '')}). "
              'Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  // ── Agent-mode passenger collection (native form handoff) ──────────────────
  //
  // Identity fields (CNIC, passport, DOB, emergency contact) are never typed
  // into chat. The same validated native forms the manual flow uses are opened
  // with agentMode: true, and hand their data back here via Get.back(result:).

  Widget _buildAddPassengerBar() {
    const gold = Color(0xFFD4AF37);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 1 of 2 — traveler information:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _collectingPassengers ? null : _openPassengerForm,
                  icon: _collectingPassengers
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded,
                          size: 18, color: Colors.white),
                  label: const Text(
                    'Add Passenger Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _collectingPassengers ? null : _cancelPassengerFlow,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // User backed out of the booking before entering traveler details. Drop the
  // pending booking so the text input returns, and leave a short note so the
  // chat clearly reflects the cancellation and the user can carry on.
  void _cancelPassengerFlow() {
    if (_collectingPassengers) return;
    _clearPendingAction();
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: "No problem — I've set that booking aside. "
            "Just tell me what you'd like to do next.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  Future<void> _openPassengerForm() async {
    final pending = _pendingBookingData;
    if (pending == null || _collectingPassengers) return;
    // For a package this resolves to its flight/train/hotel piece — the wrapper
    // itself carries no route or dates to build a form from, and the travelers
    // collected here are reused for every other piece in the package.
    final data = primaryComponent(pending);
    final type = data['booking_type'] as String? ?? 'flight';

    setState(() => _collectingPassengers = true);
    dynamic result;
    try {
      switch (type) {
        case 'train':
          result = await Get.toNamed('/train-passengers',
              arguments: trainFormArgs(data));
          break;
        case 'hotel':
          result = await Get.toNamed(AppLink.hotelGuestForm,
              arguments: hotelFormArgs(data));
          break;
        default:
          result = await Get.toNamed(AppLink.bookingStep1,
              arguments: flightFormArgs(data));
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
          'contactName',
          'contactEmail',
          'contactPhone',
          'emergencyName',
          'emergencyEmail',
          'emergencyPhone',
          'emergencyRelation',
        ])
          if ((res[k] as String?)?.isNotEmpty ?? false) k: res[k],
      };
    });

    // Free-seat classes (premium flight cabins + every train class) get to pick
    // their seat, reusing the manual flow's exact seat maps. Best-effort: the
    // user can skip and have a seat assigned at the desk, and any hiccup here
    // must never block a booking that already has its passengers.
    final seatNote = await _collectAgentSeats(data, passengers);

    _addMilestoneMessage(
      '✅ Passenger details saved for '
      '${passengers.length} traveler(s).$seatNote Now choose how you\'d like to pay.',
    );
  }

  /// Free-seat scope only: premium flight cabins (Business/Premium/First) and
  /// every train class select seats at no charge, so nothing here changes the
  /// amount charged. Economy flights are intentionally excluded — their front /
  /// exit rows carry a fee that would touch the payment pipeline (deferred).
  bool _seatSelectionEligible(Map<String, dynamic> data) {
    final type = data['booking_type'] as String? ?? '';
    if (type == 'train') return true;
    if (type == 'flight') {
      final cabin = (data['cabin_class'] as String? ?? 'Economy').toLowerCase();
      return cabin.contains('business') ||
          cabin.contains('premium') ||
          cabin.contains('first');
    }
    return false;
  }

  /// Open the seat map (if eligible), write each chosen seat onto the matching
  /// passenger as `seat_number` so the existing POST /passengers call persists
  /// it, and return a short note for the milestone message ('' if none picked).
  Future<String> _collectAgentSeats(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> passengers,
  ) async {
    if (!_seatSelectionEligible(data)) return ' ';
    List<Map<String, dynamic>> chosen = const [];
    try {
      final result = await Get.to<List<Map<String, dynamic>>>(
        () => _AgentSeatPickerScreen(bookingData: data, passengers: passengers),
      );
      if (result != null) chosen = result;
    } catch (_) {
      return ' ';
    }
    if (chosen.isEmpty || _agentPassengers == null) return ' ';

    final labels = <String>[];
    setState(() {
      for (final s in chosen) {
        final idx = (s['passengerIndex'] as num?)?.toInt() ?? -1;
        final seat = (s['seatName'] as String? ?? '').trim();
        if (seat.isEmpty || idx < 0 || idx >= _agentPassengers!.length) continue;
        // Trains number seats within a coach, so keep the coach for an
        // unambiguous ticket value ('Coach#2 · 03B'); flights need only '12A'.
        final coach = (s['coach'] as String? ?? '').trim();
        final label = coach.isEmpty ? seat : '$coach · $seat';
        _agentPassengers![idx]['seat_number'] = label;
        labels.add(label);
      }
    });
    if (labels.isEmpty) return ' ';
    return '\n🪑 Seats: ${labels.join(', ')}\n\n';
  }

  Widget _buildPaymentButtons() {
    const gold = Color(0xFFD4AF37);
    // One payment covers every piece of a package, so say so on the button.
    final isPackage = _pendingBookingData?['booking_type'] == 'package';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPackage
                ? 'One payment for your whole package:'
                : 'Choose payment method:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savingForLater ? null : _showCardPaymentSheet,
                  icon: const Icon(Icons.credit_card_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    isPackage ? 'Pay for Package' : 'Pay with Card',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savingForLater ? null : _saveBookingForLater,
                  icon: _savingForLater
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.grey.shade700),
                        )
                      : Icon(Icons.bookmark_added_outlined,
                          size: 18, color: Colors.grey.shade700),
                  label: Text(
                    _savingForLater ? 'Saving...' : 'Pay Later',
                    style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Standalone car booking (Phase 3) ───────────────────────────────────────
  //
  // The backend gate has already validated the request and returned
  // action == 'car_booking_choice' with booking_data. This is the single
  // human tap that commits it: no committing tool ever ran in the agent loop.
  // A standalone car has NO card step — the fare is paid to the driver — so
  // this calls ApiClient.bookCar directly (unlike the flight/train/hotel path).

  Future<void> _confirmCarBooking() async {
    final data = _pendingBookingData;
    if (data == null || _confirmingCar) return;

    final pickup = (data['pickup_location'] as String?)?.trim() ?? '';
    final dropoff = (data['dropoff_location'] as String?)?.trim() ?? '';
    final vehicle = (data['vehicle_type'] as String?)?.trim() ?? '';
    final pickupDt = (data['pickup_datetime'] as String?)?.trim() ?? '';
    if (pickup.isEmpty ||
        dropoff.isEmpty ||
        vehicle.isEmpty ||
        pickupDt.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: "I'm missing some ride details. Please tell me the pickup, "
              'drop-off, vehicle and time again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() => _confirmingCar = true);
    try {
      // contactEmail omitted — the backend falls back to the account email.
      final res = await ApiClient.bookCar(
        pickupLocation: pickup,
        dropoffLocation: dropoff,
        vehicleType: vehicle,
        pickupDatetime: pickupDt,
      );
      if (!mounted) return;
      final driver = (res['driver'] as Map?)?.cast<String, dynamic>() ?? {};
      final driverName = (driver['name'] as String?) ?? 'your driver';
      final driverPhone = (driver['phone'] as String?) ?? '';
      final plate = (driver['vehicle_plate'] as String?) ?? '';
      final code = (res['verification_code'] as String?) ?? '';
      final fare = (res['total_amount'] as num?)?.toStringAsFixed(0) ?? '';

      _clearPendingAction();
      setState(() {
        _confirmingCar = false;
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: '✅ **Car Booked!**\n\n'
              '**Driver:** $driverName${driverPhone.isNotEmpty ? ' · $driverPhone' : ''}\n'
              '**Vehicle:** $vehicle${plate.isNotEmpty ? ' · $plate' : ''}\n'
              '**Verification code:** $code\n'
              '**Fare:** PKR $fare (paid to the driver)\n\n'
              'Show the code to your driver at pickup. You can see this ride any '
              'time under **My Bookings → Car**.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Keep the confirm bar so the user can retry (e.g. no driver available yet).
      setState(() {
        _confirmingCar = false;
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: "I couldn't book that ride "
              '(${e.toString().replaceFirst('Exception: ', '')}). '
              'Please try again in a moment.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  Widget _buildCarConfirmBar() {
    const gold = Color(0xFFD4AF37);
    final fare = (_pendingBookingData?['price_pkr'] as num?)?.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fare != null
                ? 'Confirm your ride · PKR $fare (paid to driver)'
                : 'Confirm your ride',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmingCar ? null : _confirmCarBooking,
                  icon: _confirmingCar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.directions_car_rounded,
                          size: 18, color: Colors.white),
                  label: Text(
                    _confirmingCar ? 'Booking...' : 'Confirm Car Booking',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _confirmingCar ? null : _clearPendingAction,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConversationsSheet() async {
    List<Map<String, dynamic>> conversations = [];
    try {
      conversations = await ApiClient.getAgentConversations();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConversationsSheet(
        conversations: conversations,
        currentId: _conversationId,
        onSelect: (id) async {
          Navigator.pop(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kConvIdKey, id);
          setState(() {
            _conversationId = null;
            _messages.clear();
            // Never carry a pending booking bar from the previous chat.
            _pendingAction = null;
            _pendingBookingData = null;
            _agentPassengers = null;
            _agentContact = null;
          });
          await _loadConversationState();
        },
        onDelete: (id) async {
          await ApiClient.deleteAgentConversation(id);
          if (id == _conversationId) await _startNewChat();
        },
        onNewChat: () {
          Navigator.pop(context);
          _startNewChat();
        },
      ),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    _entryController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: Column(
        children: [
          // ── Header: rounded glass-dark card with a floating gold orb ────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF120C00),
                  Color(0xFF2E2000),
                  Color(0xFF574000),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  // Purely decorative soft glow accent — no state, no logic.
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFD4AF37).withValues(alpha: 0.25),
                            const Color(0xFFD4AF37).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 16, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          _GlassHeaderButton(
                            icon: Icons.arrow_back_ios_new,
                            size: 15,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          // Animated AI logo — gold-ringed orb
                          SlideTransition(
                            position: _headerSlide,
                            child: FadeTransition(
                              opacity: _headerFade,
                              child: Container(
                                width: 46,
                                height: 46,
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFE8C76A),
                                      Color(0xFFD4AF37),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 14,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1A1400),
                                  ),
                                  child: Icon(Icons.smart_toy_rounded,
                                      color: Color(0xFFE8C76A), size: 22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Title
                          Expanded(
                            child: SlideTransition(
                              position: _headerSlide,
                              child: FadeTransition(
                                opacity: _headerFade,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (rect) =>
                                          const LinearGradient(
                                        colors: [
                                          Color(0xFFF3DFA0),
                                          Color(0xFFD4AF37),
                                        ],
                                      ).createShader(rect),
                                      child: const Text(
                                        'Travello AI',
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.14)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4ADE80),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                          0xFF4ADE80)
                                                      .withValues(alpha: 0.7),
                                                  blurRadius: 5,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Online',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white
                                                  .withValues(alpha: 0.65),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // History + New Chat buttons
                          _GlassHeaderButton(
                            icon: Icons.history_rounded,
                            tooltip: 'Conversation History',
                            onTap: _showConversationsSheet,
                          ),
                          const SizedBox(width: 8),
                          _GlassHeaderButton(
                            icon: Icons.add_comment_outlined,
                            tooltip: 'New Chat',
                            onTap: _startNewChat,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildChatTab()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildChatTab() {
    final showSuggestions = _messages.length == 1 && !_isTyping;
    return Column(
      children: [
        if (_isLoadingHistory)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: Color(0xFFD4AF37),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length +
                (_isTyping ? 1 : 0) +
                (showSuggestions ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _messages.length) {
                return _buildMessageBubble(_messages[index]);
              }
              if (_isTyping && index == _messages.length) {
                return _buildTypingIndicator();
              }
              if (showSuggestions) {
                return _buildSuggestions();
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // A package uses the identical two-step bar: collect travelers once, then
        // pay once — the only difference is that the payment covers every piece.
        if (_pendingAction == 'payment_choice' ||
            _pendingAction == 'package_choice')
          _agentPassengers == null
              ? _buildAddPassengerBar()
              : _buildPaymentButtons()
        else if (_pendingAction == 'car_booking_choice')
          _buildCarConfirmBar()
        else
          _buildInputField(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isFirst = _messages.indexOf(message) == 0 && !message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(isFirst ? 16 : 13),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF2D2000)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isUser
                  ? Text(
                      message.message,
                      style: TravelloTheme.paragraph.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : MarkdownBody(
                      data: message.message,
                      styleSheet: MarkdownStyleSheet(
                        p: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: isFirst ? 14.5 : 14,
                          height: 1.5,
                        ),
                        strong: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: isFirst ? 14.5 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                        em: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 14,
                        ),
                        // Tables (e.g. flight results) must size columns to their
                        // content, not divide the narrow bubble width evenly — the
                        // flex default crushed cells to ~1 char ("P K 4 4 8"). With
                        // IntrinsicColumnWidth, flutter_markdown also wraps the table
                        // in a horizontal scroll view, so wide tables stay readable.
                        tableColumnWidth: const IntrinsicColumnWidth(),
                        tableCellsPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        tableHead: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        tableBody: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        tableBorder: TableBorder.all(
                          color: const Color(0xFFE5E0D0),
                          width: 1,
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 8),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFD4AF37),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      shrinkWrap: true,
                    ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2D2000),
              child: Icon(Icons.person, color: Color(0xFFD4AF37), size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 5),
                _buildDot(1),
                const SizedBox(width: 5),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        final double phase = (_dotController.value - index / 3.0 + 1.0) % 1.0;
        final double opacity = phase < 0.5 ? phase * 2 : (1.0 - phase) * 2;
        return Opacity(
          opacity: 0.3 + opacity * 0.7,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: TravelloTheme.primaryMain, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    final suggestions = AIAssistantData.getSuggestions();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 6),
                Text('Try asking:',
                    style: TravelloTheme.caption.copyWith(
                        color: TravelloTheme.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 10),
            ...suggestions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isHovered = _hoveredSuggestion == i;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 350 + i * 60),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - v), 0),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) =>
                        setState(() => _hoveredSuggestion = i),
                    onExit: (_) =>
                        setState(() => _hoveredSuggestion = -1),
                    child: GestureDetector(
                      onTap: () => _sendMessage(s.title),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? const Color(0xFFFFF8E7)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHovered
                                ? const Color(0xFFD4AF37)
                                : Colors.grey.shade200,
                            width: isHovered ? 1.5 : 1,
                          ),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFFF5F0E6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(s.icon,
                                  size: 16,
                                  color: const Color(0xFFD4AF37)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: isHovered
                                      ? const Color(0xFF2D2000)
                                      : TravelloTheme.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 12,
                                color: isHovered
                                    ? const Color(0xFFD4AF37)
                                    : Colors.grey.shade300),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me about your trip...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SendButton(
                  onPressed: () => _sendMessage(_messageController.text.trim()),
                  backgroundColor: const Color(0xFFD4AF37),
                  iconColor: Colors.white,
                  enabled: !_isTyping,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Only reach for device GPS when the message is plausibly location-relevant, so
  // an unrelated message ("book a flight") never triggers a permission prompt. The
  // backend still decides whether to actually use the coordinates — a named city
  // always wins over "near me".
  static final RegExp _locationCueRe = RegExp(
    r'near\s*me|nearby|around\s+me|closest|nearest|my\s+location|current\s+location|'
    r'where\s+i\s+am|right\s+here|over\s+here|\bhere\b|hospital|clinic|pharmac|'
    r'chemist|doctor|emergency|injur|weather|mere\s+paas|meri\s+location|yahan|idhar',
    caseSensitive: false,
  );

  bool _mightNeedLocation(String text) => _locationCueRe.hasMatch(text);

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // A reply is still generating — ignore this submit. Firing a second agent
    // request while the first is in flight raced two responses onto the same
    // state and could crash the screen. One turn at a time.
    if (_isTyping) return;

    // Require a logged-in session before hitting the authenticated agent endpoint,
    // so the user sees a clear prompt instead of a generic connection error.
    if (!ApiClient.isLoggedIn) {
      setState(() {
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Please log in to chat with the travel assistant.',
            isUser: false,
            timestamp: DateTime.now()));
      });
      _scrollToBottom();
      return;
    }

    // While a booking sits on the summary awaiting payment, a typed payment word
    // must drive the REAL action (open the card sheet / save for later) — never
    // the agent. The agent has no booking-creation tool, so it would only fake a
    // "reservation saved" reply for a booking that was never actually created.
    if ((_pendingAction == 'payment_choice' ||
            _pendingAction == 'package_choice') &&
        _pendingBookingData != null) {
      final intent = _paymentIntent(text);
      if (intent != _PayIntent.none) {
        setState(() {
          _messages.add(ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              message: text,
              isUser: true,
              timestamp: DateTime.now()));
        });
        _messageController.clear();
        _scrollToBottom();
        switch (intent) {
          case _PayIntent.card:
            _showCardPaymentSheet();
            break;
          case _PayIntent.later:
            _saveBookingForLater();
            break;
          case _PayIntent.ambiguous:
            _addMilestoneMessage(
              'To finish this booking, tap **Pay with Card** or **Pay Later** '
              'below 👇',
            );
            break;
          case _PayIntent.none:
            break;
        }
        return;
      }
    }

    setState(() {
      _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: text,
          isUser: true,
          timestamp: DateTime.now()));
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final coords =
          _mightNeedLocation(text) ? await LocationService.getCoords() : null;
      final result = await ApiClient.agentChat(
        message: text,
        conversationId: _conversationId,
        lat: coords?.lat,
        lng: coords?.lng,
      );
      if (!mounted) return;
      final newConvId = result['conversation_id'] as String?;
      if (newConvId != null && newConvId != _conversationId) {
        _conversationId = newConvId;
        _saveConversationId(newConvId);
      }
      setState(() {
        _pendingAction = result['action'] as String?;
        _pendingBookingData = result['booking_data'] != null
            ? Map<String, dynamic>.from(result['booking_data'] as Map)
            : null;
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: result['response'] as String? ?? 'Sorry, I could not process that.',
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: _messageForApiException(e),
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'The assistant is taking longer than usual to respond. Please try again in a moment.',
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Something went wrong. Please check your connection and try again.',
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  /// The backend's own error `detail` text, parsed out of an ApiException's
  /// raw "HTTP 429 — {...}" body, or null if it isn't JSON with a `detail`
  /// string. Same extraction as trip_package_requirements_screen.dart's
  /// _friendlyError, kept local since each caller's fallback text differs.
  String? _apiDetail(ApiException e) {
    final raw = e.message;
    final braceIndex = raw.indexOf('{');
    if (braceIndex == -1) return null;
    try {
      final parsed = jsonDecode(raw.substring(braceIndex));
      if (parsed is Map && parsed['detail'] is String) {
        return parsed['detail'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Maps a backend HTTP failure to a message that tells the user what
  /// actually happened (daily limit vs. server timeout) instead of a single
  /// generic "something went wrong" for every case.
  String _messageForApiException(ApiException e) {
    switch (e.statusCode) {
      case 429:
        // The real limit (routers/agent.py's AGENT_DAILY_MESSAGE_LIMIT) is
        // config, not a constant — a hardcoded number here silently drifted
        // from it before. The backend's own detail text always states the
        // real configured limit, so prefer that over any fixed string.
        return _apiDetail(e) ??
            "You've reached today's message limit. Please try again tomorrow.";
      case 504:
        return 'The assistant is taking longer than usual to respond. Please try again in a moment.';
      default:
        return 'Something went wrong. Please check your connection and try again.';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Past conversations bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final String? currentId;
  final void Function(String id) onSelect;
  final void Function(String id) onDelete;
  final VoidCallback onNewChat;

  const _ConversationsSheet({
    required this.conversations,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
    required this.onNewChat,
  });

  @override
  State<_ConversationsSheet> createState() => _ConversationsSheetState();
}

class _ConversationsSheetState extends State<_ConversationsSheet> {
  late List<Map<String, dynamic>> _convs;

  @override
  void initState() {
    super.initState();
    _convs = List.from(widget.conversations);
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM  HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Icon(Icons.history_rounded, color: gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Conversation History',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add, size: 16, color: gold),
                label: const Text('New Chat',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_convs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No past conversations',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _convs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final c = _convs[i];
                  final id = c['id'] as String? ?? '';
                  final title = c['title'] as String? ?? 'Conversation';
                  final date = _fmtDate(c['updated_at'] as String?);
                  final isCurrent = id == widget.currentId;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? gold.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: isCurrent ? gold : Colors.grey.shade400,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: date.isNotEmpty
                        ? Text(date,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400))
                        : null,
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle_rounded,
                            color: gold, size: 18)
                        : IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red.shade300),
                            onPressed: () {
                              widget.onDelete(id);
                              setState(() => _convs.removeAt(i));
                            },
                          ),
                    onTap: isCurrent ? null : () => widget.onSelect(id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// A typed payment command, classified only while a booking awaits payment.
enum _PayIntent { card, later, ambiguous, none }

/// Classify a SHORT, command-like message typed while a booking sits on the
/// summary awaiting payment. Tight and length-capped so a normal sentence that
/// merely mentions "pay" isn't hijacked — only consulted when the pending action
/// is 'payment_choice'. `card` opens the card sheet, `later` saves for later,
/// `ambiguous` nudges the user to the buttons, `none` falls through to the agent.
_PayIntent _paymentIntent(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return _PayIntent.none;
  // Only brief, imperative messages count as payment commands ("pay with card"
  // is the longest real one, at 3 words).
  if (t.split(RegExp(r'\s+')).length > 4) return _PayIntent.none;
  // A question is asking about payment, not issuing it — let the agent answer.
  if (t.endsWith('?') ||
      RegExp(r'^(what|how|why|when|where|which|who|is|are|do|does|can|could|should|would|will)\b')
          .hasMatch(t)) {
    return _PayIntent.none;
  }

  final isCard = RegExp(r'pay\s*(with|by)?\s*card|\bcard\b|pay\s*now|pay\s*online|credit')
      .hasMatch(t);
  final isLater = RegExp(r'pay\s*later|\blater\b|save(\s*(it|this|for\s*later|booking))?|\bhold\b|reserve')
      .hasMatch(t);
  if (isCard && !isLater) return _PayIntent.card;
  if (isLater && !isCard) return _PayIntent.later;
  if (isCard && isLater) return _PayIntent.ambiguous;
  // Bare "pay" / "proceed" / "confirm" — real intent to pay, but which way is
  // unclear, so point them at the buttons instead of guessing.
  if (RegExp(r'\bpay\b|\bpayment\b|proceed|checkout|check\s*out|confirm|book\s*it')
      .hasMatch(t)) {
    return _PayIntent.ambiguous;
  }
  return _PayIntent.none;
}

// ─────────────────────────────────────────────────────────────────────────────
// Agent seat picker — hosts the manual flow's FlightSeatPicker / TrainSeatPicker
// in a simple confirm screen for the chat booking flow. Scope is free-seat
// classes only (premium flight cabins + every train class), so there is no seat
// fee and nothing here changes the charged total. Returns the per-passenger
// selections via Get.back, or null when the user skips / backs out.
// ─────────────────────────────────────────────────────────────────────────────
class _AgentSeatPickerScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final List<Map<String, dynamic>> passengers;
  const _AgentSeatPickerScreen({
    required this.bookingData,
    required this.passengers,
  });

  @override
  State<_AgentSeatPickerScreen> createState() => _AgentSeatPickerScreenState();
}

class _AgentSeatPickerScreenState extends State<_AgentSeatPickerScreen> {
  List<Map<String, dynamic>> _selections = const [];

  int get _total => widget.passengers.length;

  int get _chosenCount => _selections
      .where((s) => (s['seatName'] as String? ?? '').isNotEmpty)
      .length;

  bool get _allChosen => _total > 0 && _chosenCount >= _total;

  void _onSeats(List<Map<String, dynamic>> selections) {
    setState(() => _selections = selections);
  }

  // 'BUSINESS' → 'Business'. The seat map shows this label; the widget itself
  // matches on lower-case, so casing only affects display.
  static String _prettyCabin(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return 'Economy';
    return c
        .split(RegExp(r'[ _]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final isTrain = (widget.bookingData['booking_type'] as String?) == 'train';

    final picker = isTrain
        ? TrainSeatPicker(
            trainClass:
                (widget.bookingData['train_class'] as String?) ?? 'Economy',
            totalPassengers: _total,
            passengers: widget.passengers,
            onSeatsSelected: _onSeats,
          )
        : FlightSeatPicker(
            totalPassengers: _total,
            passengers: widget.passengers,
            cabinClass:
                _prettyCabin(widget.bookingData['cabin_class'] as String?),
            onSeatsSelected: _onSeats,
          );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Choose your seat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: picker,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Get.back<List<Map<String, dynamic>>>(),
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _allChosen
                      ? () => Get.back<List<Map<String, dynamic>>>(
                          result: _selections)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _allChosen
                        ? 'Confirm seats'
                        : 'Select $_chosenCount / $_total seats',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
