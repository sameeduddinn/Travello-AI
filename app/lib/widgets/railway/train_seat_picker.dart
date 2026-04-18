import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  TRAIN SEAT PICKER - Pakistan Railways Professional Design
// ═════════════════════════════════════════════════════════════════════════════

class TrainSeatPicker extends StatefulWidget {
  final String trainClass;
  final int totalPassengers;
  final List<Map<String, dynamic>> passengers;
  final Function(List<Map<String, dynamic>>) onSeatsSelected;

  const TrainSeatPicker({
    super.key,
    required this.trainClass,
    required this.totalPassengers,
    required this.passengers,
    required this.onSeatsSelected,
  });

  @override
  State<TrainSeatPicker> createState() => _TrainSeatPickerState();
}

class _TrainSeatPickerState extends State<TrainSeatPicker> {
  String _selectedCoach = 'Coach#2';
  int _currentPassengerIndex = 0;
  List<Map<String, dynamic>> _seatSelections = [];

  // Coach availability (dummy data based on 72-seat economy coaches)
  final Map<String, int> _coachVacancy = {
    'Coach#2': 24,
    'Coach#3': 31,
    'Coach#4': 18,
    'Coach#5': 27,
    'Coach#6': 0,
    'Coach#11': 0,
    'Coach#12': 12,
    'Coach#13': 0,
    'Coach#14': 0,
    'Coach#15': 8,
    'Coach#16': 0,
    'Coach#17': 0,
  };

  // Pre-booked seats (dummy data - varies by coach)
  late Set<String> _bookedSeats;

  @override
  void initState() {
    super.initState();
    _initializeBookedSeats();
    _seatSelections = List.generate(
      widget.totalPassengers,
      (i) => {
        'passengerIndex': i,
        'passengerName': _getPassengerName(i),
        'seatName': '',
        'coach': '',
        'price': 0.0, // Seat selection is FREE - included in ticket price
      },
    );
  }

  void _initializeBookedSeats() {
    // Simulate booked seats based on vacancy
    _bookedSeats = {};
    final vacancy = _coachVacancy[_selectedCoach] ?? 0;
    final totalSeats = _getTotalSeatsInCoach();
    final bookedCount = totalSeats - vacancy;

    // Book seats in a realistic pattern (mixed distribution)
    final allSeats = _generateAllSeats();
    final occupied = <String>{};

    // Book seats with some clustering pattern for realism
    int booked = 0;
    final step = allSeats.length > bookedCount
        ? (allSeats.length / bookedCount).ceil()
        : 1;

    for (int i = 0; i < allSeats.length && booked < bookedCount; i += step) {
      if (i < allSeats.length) {
        occupied.add(allSeats[i]);
        booked++;
      }
      // Add some adjacent seats for clustering
      if (i + 1 < allSeats.length && booked < bookedCount && i % 3 == 0) {
        occupied.add(allSeats[i + 1]);
        booked++;
      }
    }

    _bookedSeats = occupied;
  }

  int _getTotalSeatsInCoach() {
    // Pakistan Railways Standard: Economy 72 seats (24 rows × 3), AC Sleeper 48, First AC 24
    if (widget.trainClass.contains('First')) return 24;
    if (widget.trainClass.contains('AC')) return 48;
    return 72; // 24 rows with 3 berths each
  }

  List<String> _generateAllSeats() {
    List<String> seats = [];
    if (widget.trainClass.contains('First')) {
      // First AC: 24 berths (8 compartments × 3 berths)
      for (int i = 1; i <= 24; i++) {
        seats.add('${i.toString().padLeft(2, '0')}B');
      }
    } else if (widget.trainClass.contains('AC')) {
      // AC Sleeper: 48 berths (16 compartments × 3 berths)
      for (int i = 1; i <= 48; i++) {
        seats.add('${i.toString().padLeft(2, '0')}B');
      }
    } else {
      // Economy: Pakistan Railways standard - 24 rows, 3 seats per row = 72 seats
      // Sequential seat numbering: 01B, 02B, 03B... up to 72B
      for (int i = 1; i <= 72; i++) {
        seats.add('${i.toString().padLeft(2, '0')}B');
      }
    }
    return seats;
  }

  String _getPassengerName(int index) {
    if (index < widget.passengers.length) {
      final p = widget.passengers[index];
      final first = (p['firstName'] ?? '').toString().trim();
      final last = (p['lastName'] ?? '').toString().trim();
      return '$first $last'.trim().isNotEmpty
          ? '$first $last'.trim()
          : 'Passenger ${index + 1}';
    }
    return 'Passenger ${index + 1}';
  }

  bool _isSeatSelected(String seatName) {
    return _seatSelections
        .any((s) => s['seatName'] == seatName && s['coach'] == _selectedCoach);
  }

  bool _isSeatBooked(String seatName) {
    return _bookedSeats.contains(seatName);
  }

  bool _isSeatRecommended(String seatName) {
    // Only recommend a few specific good seats (window/aisle positions)
    // Don't over-recommend - just highlight best seats
    if (_isSeatBooked(seatName) || _isSeatSelected(seatName)) {
      return false;
    }

    if (widget.trainClass != 'Economy') {
      // For AC/First: Recommend only lower berths in first few compartments
      final seatNum = int.tryParse(seatName.substring(0, 2)) ?? 0;
      return seatNum <= 6 && seatName.endsWith('B');
    }

    // For Economy: Only recommend a few window/aisle seats (seats 03B, 06B, 09B)
    final seatNum = int.tryParse(seatName.substring(0, 2)) ?? 0;
    return (seatNum == 3 || seatNum == 6 || seatNum == 9) &&
        seatName.endsWith('B');
  }

  void _selectSeat(String seatName) {
    if (_isSeatBooked(seatName)) return;

    setState(() {
      // Check if this seat is already selected by ANY passenger
      final existingSelection = _seatSelections.indexWhere(
          (s) => s['seatName'] == seatName && s['coach'] == _selectedCoach);

      if (existingSelection != -1) {
        // Seat is already selected - deselect it and switch to that passenger
        _seatSelections[existingSelection]['seatName'] = '';
        _seatSelections[existingSelection]['coach'] = '';
        _currentPassengerIndex = existingSelection;
      } else {
        // Seat is not selected - select it for current passenger
        _seatSelections[_currentPassengerIndex]['seatName'] = seatName;
        _seatSelections[_currentPassengerIndex]['coach'] = _selectedCoach;

        // Auto-advance to next passenger if available
        if (_currentPassengerIndex < widget.totalPassengers - 1) {
          _currentPassengerIndex++;
        }
      }

      widget.onSeatsSelected(_seatSelections);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildCoachSelector(),
          _buildLegend(),
          const SizedBox(height: 12),
          // Scrollable seat layout section
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSeatLayout(),
            ),
          ),
          const Divider(height: 1),
          _buildPassengerList(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFC6A75E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_seat,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Your Seat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pakistan Railways · ${widget.trainClass}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_seatSelections.where((s) => s['seatName'].toString().isNotEmpty).length}/${widget.totalPassengers} Selected',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
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

  Widget _buildCoachSelector() {
    final availableCoaches = _coachVacancy.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Coach',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableCoaches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final coach = availableCoaches[index];
                final vacancy = _coachVacancy[coach] ?? 0;
                final isSelected = _selectedCoach == coach;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCoach = coach;
                      _initializeBookedSeats();
                    });
                  },
                  child: Container(
                    width: 85,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD4AF37)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          coach,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vacant: $vacancy',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFFD4AF37),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem('Available', Colors.grey.shade300),
          _buildLegendItem('Recommend', Colors.orange.shade100),
          _buildLegendItem('Select', const Color(0xFF2196F3)),
          _buildLegendItem('Booked', Colors.grey.shade500),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color:
                  color == Colors.grey.shade300 ? Colors.grey.shade400 : color,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatLayout() {
    if (widget.trainClass.contains('First') ||
        widget.trainClass.contains('AC')) {
      return _buildBerthLayout();
    }
    return _buildRegularSeatLayout();
  }

  Widget _buildBerthLayout() {
    // AC/First AC Berth layout - Pakistan Railways sleeper coaches
    final berths = widget.trainClass.contains('First')
        ? List.generate(24, (i) => (i + 1).toString().padLeft(2, '0'))
        : List.generate(48, (i) => (i + 1).toString().padLeft(2, '0'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Compartment layout - 3 berths per row
          ...List.generate((berths.length / 3).ceil(), (rowIndex) {
            final startIndex = rowIndex * 3;
            final endIndex = (startIndex + 3).clamp(0, berths.length);
            final rowBerths = berths.sublist(startIndex, endIndex);

            return Column(
              children: [
                if (rowIndex > 0 && rowIndex % 4 == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left TABLE marker
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'TABLE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        // Right TABLE marker
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'TABLE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: rowBerths.map((berth) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildSeatButton('${berth}B'),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRegularSeatLayout() {
    // Pakistan Railways Economy: 24 rows, odd numbering (61S, 62S, 63S...)
    final rows = List.generate(24, (i) => 61 + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ...List.generate(rows.length, (rowIndex) {
            final rowNum = rows[rowIndex];
            // Calculate sequential seat numbers for this row (3 seats per row)
            final seatBase = (rowIndex * 3) + 1;
            final seat1 = seatBase.toString().padLeft(2, '0');
            final seat2 = (seatBase + 1).toString().padLeft(2, '0');
            final seat3 = (seatBase + 2).toString().padLeft(2, '0');

            // Check if this row has any selected seats
            final hasSelection = _isSeatSelected('${seat3}B') ||
                _isSeatSelected('${seat2}B') ||
                _isSeatSelected('${seat1}B');

            return Column(
              children: [
                if (rowIndex > 0 && rowIndex % 6 == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left TABLE marker
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'TABLE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        // Right TABLE marker
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'TABLE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Row number indicator with colored background
                    Container(
                      width: 90,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: hasSelection
                            ? const Color(0xFFEF5350) // Red for selected row
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${rowNum}S',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hasSelection ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Three berths in this row - using sequential seat numbers
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildSeatButton('${seat3}B')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSeatButton('${seat2}B')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSeatButton('${seat1}B')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSeatButton(String seatName) {
    final isSelected = _isSeatSelected(seatName);
    final isBooked = _isSeatBooked(seatName);
    final isRecommended = _isSeatRecommended(seatName);

    Color bgColor;
    Color? borderColor;
    double borderWidth;
    Color textColor;

    if (isBooked) {
      bgColor = Colors.grey.shade400;
      borderColor = null;
      borderWidth = 0;
      textColor = Colors.white;
    } else if (isSelected) {
      bgColor = const Color(0xFF2196F3); // Blue for selected
      borderColor = null;
      borderWidth = 0;
      textColor = Colors.white;
    } else if (isRecommended) {
      bgColor = Colors.grey.shade300;
      borderColor = const Color(0xFFFFA726); // Orange border
      borderWidth = 2.5;
      textColor = Colors.black87;
    } else {
      bgColor = Colors.grey.shade300;
      borderColor = null;
      borderWidth = 0;
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatName),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: borderColor != null
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
        ),
        child: Text(
          seatName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Passenger Seat Assignments',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Name',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Seat Name',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Coach',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Passenger rows
                      ...List.generate(_seatSelections.length, (index) {
                        final selection = _seatSelections[index];
                        final isCurrentPassenger =
                            index == _currentPassengerIndex;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _currentPassengerIndex = index),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrentPassenger
                                  ? const Color(0xFFF5E6D3)
                                  : Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                                left: isCurrentPassenger
                                    ? const BorderSide(
                                        color: Color(0xFFD4AF37), width: 3)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isCurrentPassenger
                                              ? const Color(0xFFD4AF37)
                                              : Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: isCurrentPassenger
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selection['passengerName'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isCurrentPassenger
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    selection['seatName'].toString().isEmpty
                                        ? '-'
                                        : selection['seatName'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selection['seatName']
                                              .toString()
                                              .isEmpty
                                          ? Colors.grey.shade400
                                          : const Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    selection['coach'].toString().isEmpty
                                        ? '-'
                                        : selection['coach'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          selection['coach'].toString().isEmpty
                                              ? Colors.grey.shade400
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
