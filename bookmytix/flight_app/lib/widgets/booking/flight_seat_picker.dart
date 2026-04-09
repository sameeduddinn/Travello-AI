import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Flight Seat Picker - Pakistan Domestic Standards (Updated March 2026)
//  - Standard aircraft: A320/Boeing 737 (6-column: A-B-C | D-E-F)
//  - Rows: 22 typical for domestic flights
//
//  PRICING MODEL (Pakistan Domestic Standard):
//  - Economy Class:
//    • Regular seats (rows 4-11, 14-22): FREE ✅
//    • Front rows (1-3): PKR 1,500 (quick boarding, extra legroom)
//    • Exit rows (12-13): PKR 2,000 (maximum legroom, premium)
//  - Business/Premium Economy/First Class:
//    • All seats: FREE ✅ (included in ticket price)
// ─────────────────────────────────────────────────────────────────────────────

class FlightSeatPicker extends StatefulWidget {
  const FlightSeatPicker({
    super.key,
    required this.totalPassengers,
    required this.passengers,
    required this.onSeatsSelected,
    this.initialSelections,
    this.journeyLabel,
    this.cabinClass = 'Economy',
  });

  final int totalPassengers;
  final List<Map<String, dynamic>> passengers;
  final Function(List<Map<String, dynamic>>) onSeatsSelected;
  final List<Map<String, dynamic>>? initialSelections;
  final String? journeyLabel; // e.g., "OUTBOUND" or "RETURN"
  final String cabinClass; // Economy, Business, Premium Economy, First

  @override
  State<FlightSeatPicker> createState() => _FlightSeatPickerState();
}

class _FlightSeatPickerState extends State<FlightSeatPicker> {
  static const int _totalRows = 22; // 22 rows typical for domestic A320
  static const List<String> _columns = ['A', 'B', 'C', 'D', 'E', 'F'];

  // Premium seat rows (Pakistan domestic standard)
  static const List<int> _frontRows = [
    1,
    2,
    3
  ]; // Quick boarding, extra legroom
  static const List<int> _exitRows = [12, 13]; // Maximum legroom, premium

  // Pricing (Economy class only)
  static const double _frontRowPrice = 1500.0; // PKR 1,500
  static const double _exitRowPrice = 2000.0; // PKR 2,000
  static const double _regularSeatPrice = 0.0; // FREE

  // Reserved/unavailable seats (simulating already booked seats)
  static const List<String> _reservedSeats = [
    'A1',
    'B1',
    'D2',
    'E5',
    'F7',
    'C10',
    'A15',
    'E18'
  ];

  // Current passenger selection index
  int _currentPassengerIndex = 0;

  // Selected seats for each passenger
  List<Map<String, dynamic>> _seatSelections = [];

  @override
  void initState() {
    super.initState();

    // Initialize seat selections
    if (widget.initialSelections != null &&
        widget.initialSelections!.isNotEmpty) {
      _seatSelections =
          List<Map<String, dynamic>>.from(widget.initialSelections!);
    } else {
      _seatSelections = List.generate(
        widget.totalPassengers,
        (i) => {
          'passengerIndex': i,
          'passengerName': _passengerName(i),
          'seatName': '',
          'price': 0.0,
        },
      );
    }

    // Find first passenger without seat
    for (int i = 0; i < _seatSelections.length; i++) {
      if (_seatSelections[i]['seatName'] == '') {
        _currentPassengerIndex = i;
        break;
      }
    }
  }

  String _passengerName(int index) {
    if (index >= widget.passengers.length) return 'Passenger ${index + 1}';
    final p = widget.passengers[index];
    final first = (p['firstName'] ?? '').toString().trim();
    final last = (p['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Passenger ${index + 1}' : full;
  }

  bool _isSeatSelected(String seatName) {
    return _seatSelections.any((s) => s['seatName'] == seatName);
  }

  bool _isSeatReserved(String seatName) {
    return _reservedSeats.contains(seatName);
  }

  String _getSeatStatus(String seatName) {
    if (_isSeatReserved(seatName)) return 'reserved';
    if (_isSeatSelected(seatName)) {
      final selection =
          _seatSelections.firstWhere((s) => s['seatName'] == seatName);
      if (selection['passengerIndex'] == _currentPassengerIndex) {
        return 'current';
      }
      return 'selected';
    }
    return 'available';
  }

  // Calculate seat price based on cabin class and row number
  double _calculateSeatPrice(String seatName) {
    // Business/Premium Economy/First Class: All seats FREE
    if (widget.cabinClass.toLowerCase().contains('business') ||
        widget.cabinClass.toLowerCase().contains('premium') ||
        widget.cabinClass.toLowerCase().contains('first')) {
      return 0.0;
    }

    // Economy class: Tiered pricing
    final rowNum = int.tryParse(seatName.substring(1)) ?? 0;

    if (_exitRows.contains(rowNum)) {
      return _exitRowPrice; // PKR 2,000 for exit rows
    } else if (_frontRows.contains(rowNum)) {
      return _frontRowPrice; // PKR 1,500 for front rows
    } else {
      return _regularSeatPrice; // FREE for regular seats
    }
  }

  // Get seat type label for display
  String _getSeatTypeLabel(String seatName) {
    final rowNum = int.tryParse(seatName.substring(1)) ?? 0;

    if (_exitRows.contains(rowNum)) {
      return 'Exit Row';
    } else if (_frontRows.contains(rowNum)) {
      return 'Front Row';
    } else {
      return 'Standard';
    }
  }

  void _selectSeat(String seatName) {
    if (_isSeatReserved(seatName)) return;

    setState(() {
      // If this seat is already selected by current passenger, deselect it
      if (_seatSelections[_currentPassengerIndex]['seatName'] == seatName) {
        _seatSelections[_currentPassengerIndex]['seatName'] = '';
        _seatSelections[_currentPassengerIndex]['price'] = 0.0;
      } else {
        // Assign seat to current passenger with appropriate price
        _seatSelections[_currentPassengerIndex]['seatName'] = seatName;
        _seatSelections[_currentPassengerIndex]['price'] =
            _calculateSeatPrice(seatName);

        // Auto-advance to next passenger if not the last one
        if (_currentPassengerIndex < widget.totalPassengers - 1) {
          // Find next passenger without a seat
          for (int i = _currentPassengerIndex + 1;
              i < _seatSelections.length;
              i++) {
            if (_seatSelections[i]['seatName'] == '') {
              _currentPassengerIndex = i;
              break;
            }
          }
        }
      }

      widget.onSeatsSelected(_seatSelections);
    });
  }

  void _changeCurrentPassenger(int index) {
    setState(() {
      _currentPassengerIndex = index;
    });
  }

  int get _selectedCount {
    return _seatSelections
        .where((s) => (s['seatName'] as String).isNotEmpty)
        .length;
  }

  double get _totalCost {
    return _seatSelections.fold(
        0.0, (sum, s) => sum + (s['price'] as double? ?? 0.0));
  }

  // Get count of free seats selected
  int get _freeSeatsCount {
    return _seatSelections.where((s) {
      final seatName = s['seatName'] as String;
      if (seatName.isEmpty) return false;
      final price = s['price'] as double? ?? 0.0;
      return price == 0.0;
    }).length;
  }

  // Get count of front row seats selected
  int get _frontRowSeatsCount {
    return _seatSelections.where((s) {
      final seatName = s['seatName'] as String;
      if (seatName.isEmpty) return false;
      final price = s['price'] as double? ?? 0.0;
      return price == _frontRowPrice;
    }).length;
  }

  // Get count of exit row seats selected
  int get _exitRowSeatsCount {
    return _seatSelections.where((s) {
      final seatName = s['seatName'] as String;
      if (seatName.isEmpty) return false;
      final price = s['price'] as double? ?? 0.0;
      return price == _exitRowPrice;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: ThemeRadius.medium,
        border: Border.all(color: colorScheme(context).outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with journey label if provided
          if (widget.journeyLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMainContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.journeyLabel!,
                style: TravelloTheme.caption.copyWith(
                  color: colorScheme(context).onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Passenger selector tabs
          Text(
            'Select seat for:',
            style: TravelloTheme.subtitle2.copyWith(
              color: colorScheme(context).onSurface,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.totalPassengers, (i) {
              final isSelected = i == _currentPassengerIndex;
              final hasSeat =
                  (_seatSelections[i]['seatName'] as String).isNotEmpty;

              return InkWell(
                onTap: () => _changeCurrentPassenger(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TravelloTheme.primaryMain
                        : hasSeat
                            ? TravelloTheme.secondaryMainContainer
                            : TravelloTheme.paperLightContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? TravelloTheme.primaryMain
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasSeat)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isSelected
                              ? colorScheme(context).onPrimary
                              : colorScheme(context).onSecondaryContainer,
                        ),
                      if (hasSeat) const SizedBox(width: 4),
                      Text(
                        _passengerName(i),
                        style: TravelloTheme.caption.copyWith(
                          color: isSelected
                              ? colorScheme(context).onPrimary
                              : hasSeat
                                  ? colorScheme(context).onSecondaryContainer
                                  : colorScheme(context).onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasSeat) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${_seatSelections[i]['seatName']})',
                          style: TravelloTheme.caption.copyWith(
                            color: isSelected
                                ? colorScheme(context).onPrimary
                                : colorScheme(context).onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Legend
          Column(
            children: [
              // Status legend
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _legendItem('Available', Colors.white,
                      colorScheme(context).outlineVariant),
                  _legendItem('Your Seat', TravelloTheme.primaryMain,
                      Colors.transparent),
                  _legendItem(
                      'Other Pax',
                      TravelloTheme.secondaryMainContainer,
                      Colors.transparent),
                  _legendItem(
                      'Reserved', Colors.grey.shade300, Colors.transparent),
                ],
              ),
              // Pricing info for Economy class
              if (widget.cabinClass.toLowerCase() == 'economy') ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme(context)
                        .surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: TravelloTheme.primaryMain),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Rows 4-11, 14-22: FREE  •  Rows 1-3: ₨1,500  •  Rows 12-13: ₨2,000',
                          style: TravelloTheme.caption.copyWith(
                            color: colorScheme(context).onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Info for Business/Premium/First class
              if (widget.cabinClass.toLowerCase().contains('business') ||
                  widget.cabinClass.toLowerCase().contains('premium') ||
                  widget.cabinClass.toLowerCase().contains('first')) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        TravelloTheme.primaryMainContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: TravelloTheme.primaryMain),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'All seats included FREE with your ${widget.cabinClass} ticket',
                          style: TravelloTheme.caption.copyWith(
                            color: colorScheme(context).onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Aircraft structure
          LayoutBuilder(
            builder: (context, constraints) {
              // Available content width = container width minus:
              //   - container padding: 12*2 ≈ 24px
              //   - row number column + aisle column: each = rowNumWidth
              // We solve iteratively: rowNumWidth = seatCell*0.7
              // seatCell = (avail - 24 - 2*rowNumWidth) / 6
              //          = (avail - 24 - 2*seatCell*0.7) / 6
              // 6*seatCell + 1.4*seatCell = avail - 24
              // seatCell = (avail - 24) / 7.4
              final contentWidth = constraints.maxWidth - 24;
              final seatCell = (contentWidth / 7.4).clamp(26.0, 40.0);
              final seatSize = seatCell - 4;
              final rowNumWidth = seatCell * 0.7;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: ThemeRadius.medium,
                  border:
                      Border.all(color: TravelloTheme.primaryMain, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Cockpit icon
                    const SizedBox(
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.flight_rounded,
                          color: TravelloTheme.primaryMain,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Column headers
                    _buildColumnHeaders(seatCell, rowNumWidth),
                    const SizedBox(height: 4),

                    // Seat grid
                    SizedBox(
                      height: 400,
                      child: ListView.builder(
                        itemCount: _totalRows,
                        itemBuilder: (context, rowIndex) {
                          final rowNum = rowIndex + 1;
                          final isExitRow = _exitRows.contains(rowNum);
                          return Column(
                            children: [
                              if (isExitRow && rowNum == _exitRows.first)
                                _buildExitRowMarker(),
                              _buildSeatRow(rowNum, isExitRow, seatCell,
                                  seatSize, rowNumWidth),
                              if (isExitRow && rowNum == _exitRows.last)
                                _buildExitRowMarker(),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '— TAIL —',
                      textAlign: TextAlign.center,
                      style: TravelloTheme.caption.copyWith(
                        color: TravelloTheme.primaryMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Selection summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMainContainer.withOpacity(0.3),
              borderRadius: ThemeRadius.small,
              border: Border.all(color: TravelloTheme.primaryMain),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seats Selected:',
                      style: TravelloTheme.subtitle2.copyWith(
                        color: colorScheme(context).onSurface,
                      ),
                    ),
                    Text(
                      '$_selectedCount / ${widget.totalPassengers}',
                      style: TravelloTheme.subtitle.copyWith(
                        color: TravelloTheme.primaryMain,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Show breakdown if seats are selected
                if (_selectedCount > 0 &&
                    widget.cabinClass.toLowerCase() == 'economy') ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Free seats
                  if (_freeSeatsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '  Standard seats (FREE):',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$_freeSeatsCount × ₨0',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Front row seats
                  if (_frontRowSeatsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '  Front rows (1-3):',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$_frontRowSeatsCount × ₨${_frontRowPrice.toStringAsFixed(0)}',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Exit row seats
                  if (_exitRowSeatsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '  Exit rows (12-13):',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$_exitRowSeatsCount × ₨${_exitRowPrice.toStringAsFixed(0)}',
                            style: TravelloTheme.caption.copyWith(
                              color: colorScheme(context).onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seat Selection Fee:',
                      style: TravelloTheme.subtitle2.copyWith(
                        color: colorScheme(context).onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'PKR ${_totalCost.toStringAsFixed(0)}',
                      style: TravelloTheme.subtitle.copyWith(
                        color: _totalCost > 0
                            ? TravelloTheme.primaryMain
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_selectedCount < widget.totalPassengers) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap on seats in the map to select',
                    style: TravelloTheme.caption.copyWith(
                      color: colorScheme(context).onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(double seatCell, double rowNumWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: rowNumWidth), // Row number space
        ..._columns.take(3).map((col) => _columnHeader(col, seatCell)),
        SizedBox(width: rowNumWidth), // Aisle space
        ..._columns.skip(3).map((col) => _columnHeader(col, seatCell)),
      ],
    );
  }

  Widget _columnHeader(String col, double seatCell) {
    return SizedBox(
      width: seatCell,
      child: Text(
        col,
        textAlign: TextAlign.center,
        style: TravelloTheme.caption.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFFB3B3B3),
        ),
      ),
    );
  }

  Widget _buildSeatRow(int rowNum, bool isExitRow, double seatCell,
      double seatSize, double rowNumWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isExitRow ? 4 : 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Row number
          SizedBox(
            width: rowNumWidth,
            child: Text(
              '$rowNum',
              textAlign: TextAlign.center,
              style: TravelloTheme.caption.copyWith(
                color: const Color(0xFFB3B3B3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Left side seats (A, B, C)
          ..._columns
              .take(3)
              .map((col) => _buildSeat('$col$rowNum', isExitRow, seatSize)),
          // Aisle
          SizedBox(width: rowNumWidth),
          // Right side seats (D, E, F)
          ..._columns
              .skip(3)
              .map((col) => _buildSeat('$col$rowNum', isExitRow, seatSize)),
        ],
      ),
    );
  }

  Widget _buildSeat(String seatName, bool isExitRow, double seatSize) {
    final status = _getSeatStatus(seatName);
    final isDisabled = status == 'reserved';
    final seatPrice = _calculateSeatPrice(seatName);
    final isPremiumSeat =
        seatPrice > 0 && widget.cabinClass.toLowerCase() == 'economy';

    Color getSeatColor() {
      switch (status) {
        case 'current':
          return TravelloTheme.primaryMain;
        case 'selected':
          return TravelloTheme.secondaryMainContainer;
        case 'reserved':
          return Colors.grey.shade300;
        default:
          return Colors.white;
      }
    }

    Color getBorderColor() {
      if (status == 'available') {
        // Highlight premium seats with different border color
        if (isPremiumSeat) {
          return Colors.orange.shade300;
        }
        return colorScheme(context).outlineVariant;
      }
      return Colors.transparent;
    }

    return InkWell(
      onTap: isDisabled ? null : () => _selectSeat(seatName),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            width: seatSize,
            height: isExitRow ? seatSize * 1.15 : seatSize * 0.9,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: getSeatColor(),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: getBorderColor(),
                width: isPremiumSeat && status == 'available' ? 1.5 : 1,
              ),
              boxShadow: status == 'current'
                  ? [
                      BoxShadow(
                        color: TravelloTheme.primaryMain.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: status == 'reserved'
                  ? Icon(Icons.close, size: 14, color: Colors.grey.shade500)
                  : status == 'current' || status == 'selected'
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: status == 'current'
                              ? colorScheme(context).onPrimary
                              : colorScheme(context).onSecondaryContainer,
                        )
                      : Text(
                          seatName.substring(0, 1),
                          style: TravelloTheme.caption.copyWith(
                            fontSize: 10,
                            color: const Color(0xFFB3B3B3),
                          ),
                        ),
            ),
          ),
          // Price badge for premium seats (only when available and Economy class)
          if (isPremiumSeat && status == 'available')
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '₨${(seatPrice / 1000).toStringAsFixed(0)}k',
                    style: const TextStyle(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExitRowMarker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.exit_to_app, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text(
            'EXIT',
            style: TravelloTheme.caption.copyWith(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.exit_to_app, size: 14, color: Colors.orange.shade700),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor == Colors.transparent ? color : borderColor,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TravelloTheme.caption.copyWith(
            fontSize: 11,
            color: const Color(0xFFB3B3B3),
          ),
        ),
      ],
    );
  }
}

// Custom painter for aircraft nose cone
class _NoseConePainter extends CustomPainter {
  final Color color;

  _NoseConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0); // Top point
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height / 2,
      size.width / 2,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height / 2,
      size.width / 2,
      0,
    );

    canvas.drawPath(path, paint);

    // Outline
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for aircraft wings
class _WingPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  _WingPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isLeft) {
      // Left wing
      path.moveTo(size.width, size.height * 0.3);
      path.lineTo(0, size.height * 0.4);
      path.lineTo(0, size.height * 0.6);
      path.lineTo(size.width, size.height * 0.7);
      path.close();
    } else {
      // Right wing (mirrored)
      path.moveTo(0, size.height * 0.3);
      path.lineTo(size.width, size.height * 0.4);
      path.lineTo(size.width, size.height * 0.6);
      path.lineTo(0, size.height * 0.7);
      path.close();
    }

    canvas.drawPath(path, paint);

    // Wing outline
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, outlinePaint);

    // Wing details (lines)
    final detailPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (isLeft) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.35),
        Offset(size.width * 0.3, size.height * 0.45),
        detailPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.65),
        Offset(size.width * 0.3, size.height * 0.55),
        detailPaint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.35),
        Offset(size.width * 0.7, size.height * 0.45),
        detailPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.65),
        Offset(size.width * 0.7, size.height * 0.55),
        detailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for aircraft tail
class _TailPainter extends CustomPainter {
  final Color color;

  _TailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Vertical stabilizer (tail fin)
    final verticalPath = Path();
    verticalPath.moveTo(size.width / 2 - 15, size.height);
    verticalPath.lineTo(size.width / 2 - 10, 0);
    verticalPath.lineTo(size.width / 2 + 10, 0);
    verticalPath.lineTo(size.width / 2 + 15, size.height);
    verticalPath.close();

    canvas.drawPath(verticalPath, paint);

    // Horizontal stabilizers (left and right)
    final horizontalPath = Path();
    horizontalPath.moveTo(size.width * 0.3, size.height * 0.6);
    horizontalPath.lineTo(size.width * 0.35, size.height * 0.5);
    horizontalPath.lineTo(size.width * 0.65, size.height * 0.5);
    horizontalPath.lineTo(size.width * 0.7, size.height * 0.6);
    horizontalPath.close();

    canvas.drawPath(horizontalPath, paint);

    // Outlines
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(verticalPath, outlinePaint);
    canvas.drawPath(horizontalPath, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
