import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Booking.com-style range date picker shown as a modal bottom sheet.
///
/// Usage – range mode (hotel / round-trip):
/// ```dart
/// final range = await RangeDatePickerSheet.show(
///   context,
///   startLabel: 'Check-in',
///   endLabel: 'Check-out',
///   initialStart: _checkInDate,
///   initialEnd: _checkOutDate,
///   firstDate: DateTime.now(),
///   lastDate: DateTime.now().add(const Duration(days: 365)),
/// );
/// if (range != null) { ... }
/// ```
///
/// Usage – single mode (one-way flight/train):
/// ```dart
/// final range = await RangeDatePickerSheet.show(
///   context,
///   startLabel: 'Departure',
///   singleDate: true,
///   initialStart: _departureDate,
///   firstDate: DateTime.now(),
///   lastDate: DateTime.now().add(const Duration(days: 365)),
/// );
/// if (range != null) { _departureDate = range.start; }
/// ```
class RangeDatePickerSheet extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final String startLabel;
  final String endLabel;
  final bool singleDate;

  const RangeDatePickerSheet({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    this.startLabel = 'Start',
    this.endLabel = 'End',
    this.singleDate = false,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
    required DateTime firstDate,
    required DateTime lastDate,
    String startLabel = 'Start',
    String endLabel = 'End',
    bool singleDate = false,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RangeDatePickerSheet(
        initialStart: initialStart,
        initialEnd: initialEnd,
        firstDate: firstDate,
        lastDate: lastDate,
        startLabel: startLabel,
        endLabel: endLabel,
        singleDate: singleDate,
      ),
    );
  }

  @override
  State<RangeDatePickerSheet> createState() => _RangeDatePickerSheetState();
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM STATE
// ─────────────────────────────────────────────────────────────────────────────
class _RangeDatePickerSheetState extends State<RangeDatePickerSheet>
    with TickerProviderStateMixin {
  // ── palette ────────────────────────────────────────────────────────────────
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFFFFFFFF);

  static const _weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // ── date state ─────────────────────────────────────────────────────────────
  DateTime? _start;
  DateTime? _end;
  bool _selectingEnd = false;
  late DateTime _displayMonth;

  // ── animation controllers ──────────────────────────────────────────────────
  late AnimationController _slideCtrl;
  int _slideDir = 1; // +1 = forward (next), -1 = back (prev)

  // tracks last tapped day for scale bounce
  DateTime? _lastTapped;
  late AnimationController _tapCtrl;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.singleDate ? null : widget.initialEnd;
    _selectingEnd = _start != null && _end == null && !widget.singleDate;

    final anchor = _start ?? DateTime.now();
    _displayMonth = DateTime(anchor.year, anchor.month, 1);
    _clampDisplayMonth();

    // Month slide animation
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideCtrl.value = 1.0; // start fully visible

    // Tap bounce animation
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  void _clampDisplayMonth() {
    final fm = DateTime(widget.firstDate.year, widget.firstDate.month, 1);
    final lm = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    if (_displayMonth.isBefore(fm)) _displayMonth = fm;
    if (_displayMonth.isAfter(lm)) _displayMonth = lm;
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isDisabled(DateTime d) {
    final n = _normalize(d);
    return n.isBefore(_normalize(widget.firstDate)) ||
        n.isAfter(_normalize(widget.lastDate));
  }

  bool _isStart(DateTime d) =>
      _start != null && _normalize(d) == _normalize(_start!);
  bool _isEnd(DateTime d) => _end != null && _normalize(d) == _normalize(_end!);
  bool _isInRange(DateTime d) {
    if (_start == null || _end == null) return false;
    final n = _normalize(d);
    return n.isAfter(_normalize(_start!)) && n.isBefore(_normalize(_end!));
  }

  // ── interaction ────────────────────────────────────────────────────────────
  void _onDayTap(DateTime day) {
    if (_isDisabled(day)) return;
    HapticFeedback.selectionClick();
    final d = _normalize(day);
    setState(() {
      _lastTapped = d;
      if (widget.singleDate) {
        _start = d;
      } else if (!_selectingEnd) {
        _start = d;
        _end = null;
        _selectingEnd = true;
      } else {
        if (d.isBefore(_normalize(_start!))) {
          _start = d;
          _end = null;
          _selectingEnd = true;
        } else if (d == _normalize(_start!)) {
          _start = null;
          _end = null;
          _selectingEnd = false;
        } else {
          _end = d;
          _selectingEnd = false;
        }
      }
    });
    _tapCtrl.forward(from: 0);
  }

  Future<void> _switchMonth(int dir) async {
    if (dir == 1 && !_canGoNext) return;
    if (dir == -1 && !_canGoPrev) return;
    _slideDir = dir;
    _slideCtrl.value = 0;
    setState(() {
      _displayMonth =
          DateTime(_displayMonth.year, _displayMonth.month + dir, 1);
    });
    await _slideCtrl.forward();
  }

  void _apply() {
    if (_start == null) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      DateTimeRange(start: _start!, end: _end ?? _start!),
    );
  }

  bool get _canApply =>
      widget.singleDate ? _start != null : (_start != null && _end != null);

  DateTime get _firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month, 1);
  DateTime get _lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month, 1);
  bool get _canGoPrev => _displayMonth.isAfter(_firstMonth);
  bool get _canGoNext {
    final next = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    return !next.isAfter(_lastMonth);
  }

  String _nightsLabel() {
    if (_start == null || _end == null) return '';
    final n = _end!.difference(_start!).inDays;
    if (n == 0) return '(same day)';
    return '($n night${n == 1 ? '' : 's'})';
  }

  String _fmt(DateTime? d) => d == null
      ? '-'
      : '${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildTitle(),
              _buildBadges(),
              const SizedBox(height: 8),
              _buildDivider(),
              const SizedBox(height: 4),
              _buildWeekRow(),
              _buildAnimatedGrid(),
              const SizedBox(height: 4),
              _buildApplyButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── handle ─────────────────────────────────────────────────────────────────
  Widget _buildHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCCCCCC), Color(0xFFE0E0E0)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ── header ─────────────────────────────────────────────────────────────────
  Widget _buildTitle() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            _PremiumNavBtn(
              icon: Icons.chevron_left_rounded,
              enabled: _canGoPrev,
              onTap: () => _switchMonth(-1),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(_slideDir * 0.3, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  '${_monthNames[_displayMonth.month - 1]} ${_displayMonth.year}',
                  key: ValueKey(_displayMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            _PremiumNavBtn(
              icon: Icons.chevron_right_rounded,
              enabled: _canGoNext,
              onTap: () => _switchMonth(1),
            ),
          ],
        ),
      );

  // ── date badges ────────────────────────────────────────────────────────────
  Widget _buildBadges() {
    if (widget.singleDate) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _PremiumBadge(
          icon: Icons.flight_takeoff_rounded,
          label: widget.startLabel,
          value: _fmt(_start),
          active: _start != null,
          pulsing: _start == null,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _PremiumBadge(
              icon: Icons.flight_takeoff_rounded,
              label: widget.startLabel,
              value: _fmt(_start),
              active: _start != null && !_selectingEnd,
              pulsing: !_selectingEnd && _start == null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 1,
                  color: _gold.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 3),
                Icon(Icons.arrow_forward_rounded,
                    color: _gold.withValues(alpha: 0.7), size: 14),
                const SizedBox(height: 3),
                Container(
                  width: 24,
                  height: 1,
                  color: _gold.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          Expanded(
            child: _PremiumBadge(
              icon: Icons.flight_land_rounded,
              label: widget.endLabel,
              value: _fmt(_end),
              active: _end != null,
              pulsing: _selectingEnd,
            ),
          ),
        ],
      ),
    );
  }

  // ── divider ────────────────────────────────────────────────────────────────
  Widget _buildDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _gold.withValues(alpha: 0.25),
              Colors.transparent,
            ],
          ),
        ),
      );

  // ── weekday row ────────────────────────────────────────────────────────────
  Widget _buildWeekRow() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: _weekDays
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          color: _gold.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );

  // ── animated calendar grid ─────────────────────────────────────────────────
  Widget _buildAnimatedGrid() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(_slideDir * 0.15, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      child: _buildGrid(key: ValueKey(_displayMonth)),
    );
  }

  Widget _buildGrid({Key? key}) {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    final cells = <Widget>[];
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isTapped =
          _lastTapped != null && _normalize(date) == _normalize(_lastTapped!);
      cells.add(_PremiumDayCell(
        key: ValueKey('${date.year}-${date.month}-$day'),
        date: date,
        isDisabled: _isDisabled(date),
        isStart: _isStart(date),
        isEnd: _isEnd(date),
        isInRange: _isInRange(date),
        isToday: _normalize(date) == _normalize(DateTime.now()),
        singleDate: widget.singleDate,
        hasRangeLeft: _isInRange(date) || (_isEnd(date) && _start != null),
        hasRangeRight: _isInRange(date) || (_isStart(date) && _end != null),
        isTapped: isTapped,
        tapAnim: isTapped ? _tapScale : null,
        onTap: () => _onDayTap(date),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GridView.count(
            key: key,
            primary: false,
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: cells,
          ),
        ),
      ),
    );
  }

  // ── apply button ───────────────────────────────────────────────────────────
  Widget _buildApplyButton() {
    final label = _canApply
        ? (widget.singleDate ? 'Confirm Date' : 'Apply ${_nightsLabel()}')
        : (widget.singleDate
            ? 'Select a date'
            : (_start == null
                ? 'Select ${widget.startLabel}'
                : 'Select ${widget.endLabel}'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: _PremiumApplyButton(
        label: label,
        enabled: _canApply,
        onTap: _apply,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM NAV BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumNavBtn extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PremiumNavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  @override
  State<_PremiumNavBtn> createState() => _PremiumNavBtnState();
}

class _PremiumNavBtnState extends State<_PremiumNavBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) async {
              await _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color:
                widget.enabled ? const Color(0xFFF0F0F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  widget.enabled ? const Color(0xFFDDDDDD) : Colors.transparent,
              width: 1,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            widget.icon,
            color: widget.enabled
                ? const Color(0xFF111111)
                : const Color(0xFFCCCCCC),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM BADGE (glassmorphism card)
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final bool pulsing;
  final IconData icon;

  const _PremiumBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.active = false,
    this.pulsing = false,
  });

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: pulsing
            ? const Color(0xFFFFF8E1)
            : active
                ? const Color(0xFFFFF9E6)
                : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pulsing
              ? _gold
              : active
                  ? _gold.withValues(alpha: 0.55)
                  : const Color(0xFFE0E0E0),
          width: pulsing ? 1.5 : 1,
        ),
        boxShadow: pulsing || active
            ? [
                BoxShadow(
                  color: _gold.withValues(alpha: pulsing ? 0.18 : 0.10),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(icon,
              color: (active || pulsing) ? _gold : const Color(0xFFAAAAAA),
              size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: (active || pulsing)
                        ? _gold.withValues(alpha: 0.85)
                        : const Color(0xFFAAAAAA),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF111111)
                        : pulsing
                            ? _gold
                            : const Color(0xFFAAAAAA),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM DAY CELL
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumDayCell extends StatelessWidget {
  final DateTime date;
  final bool isDisabled;
  final bool isStart;
  final bool isEnd;
  final bool isInRange;
  final bool isToday;
  final bool singleDate;
  final bool hasRangeLeft;
  final bool hasRangeRight;
  final bool isTapped;
  final Animation<double>? tapAnim;
  final VoidCallback onTap;

  const _PremiumDayCell({
    super.key,
    required this.date,
    required this.isDisabled,
    required this.isStart,
    required this.isEnd,
    required this.isInRange,
    required this.isToday,
    required this.singleDate,
    required this.hasRangeLeft,
    required this.hasRangeRight,
    required this.isTapped,
    required this.tapAnim,
    required this.onTap,
  });

  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFE6C86A);

  @override
  Widget build(BuildContext context) {
    final isSelected = isStart || isEnd;

    Widget cell = SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── selected circle (start / end) ─────────────────────────────────
          if (isSelected)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_goldLight, _gold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.40),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

          // ── in-range node: subtle gold ring + warm circle ─────────────────
          if (isInRange && !isSelected)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.13),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
            ),

          // ── today outline (when not selected) ────────────────────────────
          if (isToday && !isSelected && !isInRange)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: 0.65),
                  width: 1.5,
                ),
              ),
            ),

          // ── day number ────────────────────────────────────────────────────
          Text(
            '${date.day}',
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isDisabled
                      ? const Color(0xFFCCCCCC)
                      : isInRange
                          ? _gold
                          : isToday
                              ? _gold
                              : const Color(0xFF000000),
              fontSize: 13,
              fontWeight: isSelected
                  ? FontWeight.w800
                  : isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    // Wrap with scale animation if this was last tapped
    if (isTapped && tapAnim != null) {
      cell = ScaleTransition(scale: tapAnim!, child: cell);
    }

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: cell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM APPLY BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumApplyButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PremiumApplyButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_PremiumApplyButton> createState() => _PremiumApplyButtonState();
}

class _PremiumApplyButtonState extends State<_PremiumApplyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFE8C84A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) async {
              await _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, Color(0xFFB8900A)],
                    stops: [0.0, 0.5, 1.0],
                  )
                : const LinearGradient(
                    colors: [Color(0xFFEEEEEE), Color(0xFFE5E5E5)],
                  ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: widget.enabled
                    ? const Color(0xFF111111)
                    : const Color(0xFFAAAAAA),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
