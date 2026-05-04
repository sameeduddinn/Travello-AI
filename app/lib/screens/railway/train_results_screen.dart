import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/utils/format_utils.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/widgets/auth/auth_gate_sheet.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

// Train result model
class TrainResult {
  final String id;
  final String trainName;
  final String trainNumber;
  final String departureTime;
  final String arrivalTime;
  final bool arrivesNextDay;
  final String duration;
  final Map<String, int?> classSeats; // class -> seats (null = N/A)
  final Map<String, double> classPrices; // class name -> price
  final List<String> availableClasses;
  final bool isRefundable;

  TrainResult({
    required this.id,
    required this.trainName,
    required this.trainNumber,
    required this.departureTime,
    required this.arrivalTime,
    this.arrivesNextDay = false,
    required this.duration,
    required this.classSeats,
    required this.classPrices,
    required this.availableClasses,
    this.isRefundable = true,
  });

  int get availableSeats =>
      classSeats.values.where((s) => s != null).fold(0, (sum, s) => sum + s!);
}

class TrainResultsScreen extends StatefulWidget {
  const TrainResultsScreen({super.key});

  @override
  State<TrainResultsScreen> createState() => _TrainResultsScreenState();
}

class _TrainResultsScreenState extends State<TrainResultsScreen> {
  late Map<String, dynamic> searchParams;
  List<TrainResult> _trains = [];
  List<TrainResult> _allTrains = [];

  // Round-trip handling
  late bool _isRoundTrip;
  late int _currentJourneyIndex; // 0 = outbound, 1 = return
  TrainResult? _selectedOutboundTrain;
  String? _selectedOutboundClass;
  late DateTime? _selectedReturnDate;

  // Date selection
  late DateTime _selectedDate;

  // Sort option
  String _sortBy = 'Recommended'; // Recommended, Cheapest, Fastest
  late String _selectedTrainClass;
  RangeValues _priceRange = const RangeValues(0, 100000);
  RangeValues _departureTimeRange = const RangeValues(0, 24);
  bool _refundableOnly = false;

  // Passengers
  int _adults = 1;
  int _children = 0;
  int _infants = 0;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    searchParams = Get.arguments ?? {};

    // Get selected train class from search parameters
    _selectedTrainClass =
        searchParams['trainClass'] as String? ?? 'Economy (Seat)';

    // Check if round-trip
    _isRoundTrip = searchParams['tripType'] == 'Round-trip';
    _currentJourneyIndex = 0; // Start with outbound

    // Initialize date - check both departureDate and travelDate for backwards compatibility
    _selectedDate = searchParams['departureDate'] ??
        searchParams['travelDate'] ??
        DateTime.now();
    // Initialize return date if round-trip
    if (_isRoundTrip) {
      _selectedReturnDate = searchParams['returnDate'];
    } else {
      _selectedReturnDate = null;
    }

    // Initialize passengers
    _adults = (searchParams['adults'] as int?) ?? 1;
    _children = (searchParams['children'] as int?) ?? 0;
    _infants = (searchParams['infants'] as int?) ?? 0;

    _fetchTrains();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA FETCHING — wired to Travello AI FastAPI backend
  // Falls back to dummy data automatically if the backend is unreachable.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _fetchTrains() async {
    setState(() => _isLoading = true);
    try {
      final fromStation = searchParams['fromStation'] as RailwayStation?;
      final toStation = searchParams['toStation'] as RailwayStation?;
      final totalPassengers = (_adults + _children).clamp(1, 6);

      if (fromStation == null || toStation == null) {
        _loadDummyTrains();
      } else {
        final raw = await ApiClient.searchTrains(
          originCity: fromStation.city,
          destinationCity: toStation.city,
          date: _selectedDate,
          passengers: totalPassengers,
        );

        final backendTrains = raw.asMap().entries.map((entry) {
          final m = ApiClient.trainResultFromJson(entry.value, entry.key);
          return TrainResult(
            id: m['id'],
            trainName: m['trainName'],
            trainNumber: m['trainNumber'],
            departureTime: m['departureTime'],
            arrivalTime: m['arrivalTime'],
            arrivesNextDay: m['arrivesNextDay'] ?? false,
            duration: m['duration'],
            classSeats: Map<String, int?>.from(m['classSeats'] ?? {}),
            classPrices: Map<String, double>.from(m['classPrices'] ?? {}),
            availableClasses: List<String>.from(m['availableClasses'] ?? []),
            isRefundable: m['isRefundable'] ?? true,
          );
        }).toList();

        if (backendTrains.isEmpty) {
          _allTrains = [];
          _trains = [];
          if (mounted) setState(() {});
        } else {
          _allTrains = backendTrains;
          if (mounted) setState(() {});
          _applyFiltersAndSort();
        }
      }
    } catch (_) {
      // Backend unreachable — use dummy data so the demo always works
      _loadDummyTrains();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadDummyTrains() {
    final fromCode =
        (searchParams['fromStation'] as RailwayStation?)?.code ?? '';
    final toCode = (searchParams['toStation'] as RailwayStation?)?.code ?? '';

    // Station region groups
    const sindh = {
      'KCT',
      'KRC',
      'KTR',
      'HYD',
      'SKR',
      'RHR',
      'JAC',
      'LRK',
      'NWS',
      'SBI',
      'QTA',
      'QTC'
    };
    const punjabNorth = {
      'LHR',
      'LHC',
      'RWP',
      'MGL',
      'LMJ',
      'GJT',
      'GJW',
      'SKT',
      'MNW',
      'PEC',
      'PWC'
    };

    final fromSouth = sindh.contains(fromCode);
    final fromNorth = punjabNorth.contains(fromCode);
    final toSouth = sindh.contains(toCode);

    // Determine direction
    final isDownDirection = fromNorth && toSouth;
    final isQuettaRoute = toCode == 'QTA' ||
        toCode == 'QTC' ||
        fromCode == 'QTA' ||
        fromCode == 'QTC';
    final isPeshawarRoute = toCode == 'PEC' ||
        toCode == 'PWC' ||
        fromCode == 'PEC' ||
        fromCode == 'PWC';

    if (isQuettaRoute) {
      _allTrains = _getQuettaTrains(fromSouth);
    } else if (isPeshawarRoute) {
      _allTrains = _getPeshawarTrains(fromSouth);
    } else if (isDownDirection) {
      _allTrains = _getDownTrains(); // Lahore → Karachi
    } else {
      _allTrains = _getUpTrains(); // default: Karachi → Lahore (UP)
    }

    _resetPriceRangeForSelectedClass();
    _applyFiltersAndSort();
  }

  // UP trains: Karachi → Lahore direction
  List<TrainResult> _getUpTrains() => [
        TrainResult(
          id: '1',
          trainName: 'Awam Express',
          trainNumber: '13UP',
          departureTime: '07:30',
          arrivalTime: '07:25',
          arrivesNextDay: true,
          duration: '23h 55m',
          classSeats: {
            'AC Lower / Standard (Berth)': 88,
            'AC Business': 54,
            'Economy (Berth)': 127,
            'Economy (Seat)': 47
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6900,
            'AC Business': 9950,
            'Economy (Berth)': 3650,
            'Economy (Seat)': 3550
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '2',
          trainName: 'Karakoram Express',
          trainNumber: '41UP',
          departureTime: '15:00',
          arrivalTime: '10:20',
          arrivesNextDay: true,
          duration: '19h 20m',
          classSeats: {
            'AC Lower / Standard (Berth)': 105,
            'AC Business': 12,
            'Economy (Berth)': 51,
            'Economy (Seat)': 100
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 8300,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '3',
          trainName: 'Allama Iqbal Express',
          trainNumber: '9UP',
          departureTime: '15:30',
          arrivalTime: '12:30',
          arrivesNextDay: true,
          duration: '21h 00m',
          classSeats: {
            'AC Lower / Standard (Berth)': 31,
            'AC Business': null,
            'Economy (Berth)': null,
            'Economy (Seat)': 74
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6900,
            'Economy (Seat)': 3550
          },
          availableClasses: ['AC Lower / Standard (Berth)', 'Economy (Seat)'],
          isRefundable: false,
        ),
        TrainResult(
          id: '4',
          trainName: 'Pak Business Express',
          trainNumber: '33UP',
          departureTime: '16:00',
          arrivalTime: '10:20',
          arrivesNextDay: true,
          duration: '18h 20m',
          classSeats: {
            'AC Lower / Standard (Berth)': 217,
            'AC Business': null,
            'Economy (Berth)': 288,
            'Economy (Seat)': 159
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 8700,
            'Economy (Berth)': 5350,
            'Economy (Seat)': 5250
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '5',
          trainName: 'Tezgam',
          trainNumber: '7UP',
          departureTime: '17:30',
          arrivalTime: '14:00',
          arrivesNextDay: true,
          duration: '20h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 58,
            'AC Business': 31,
            'Economy (Berth)': 42,
            'Economy (Seat)': 87
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 7900,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '6',
          trainName: 'Karachi Express',
          trainNumber: '15UP',
          departureTime: '18:00',
          arrivalTime: '13:00',
          arrivesNextDay: true,
          duration: '19h 00m',
          classSeats: {
            'AC Lower / Standard (Berth)': 91,
            'AC Business': 8,
            'Economy (Berth)': 71,
            'Economy (Seat)': 58
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 7550,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '7',
          trainName: 'Fareed Express',
          trainNumber: '37UP',
          departureTime: '19:50',
          arrivalTime: '22:05',
          arrivesNextDay: true,
          duration: '26h 15m',
          classSeats: {
            'AC Lower / Standard (Berth)': 93,
            'AC Business': null,
            'Economy (Berth)': null,
            'Economy (Seat)': 23
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6900,
            'Economy (Seat)': 3550
          },
          availableClasses: ['AC Lower / Standard (Berth)', 'Economy (Seat)'],
          isRefundable: false,
        ),
      ];

  // DN trains: Lahore → Karachi direction (same trains, return numbers)
  List<TrainResult> _getDownTrains() => [
        TrainResult(
          id: '1',
          trainName: 'Awam Express',
          trainNumber: '14DN',
          departureTime: '08:00',
          arrivalTime: '08:20',
          arrivesNextDay: true,
          duration: '24h 20m',
          classSeats: {
            'AC Lower / Standard (Berth)': 72,
            'AC Business': 48,
            'Economy (Berth)': 110,
            'Economy (Seat)': 55
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6900,
            'AC Business': 9950,
            'Economy (Berth)': 3650,
            'Economy (Seat)': 3550
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '2',
          trainName: 'Karakoram Express',
          trainNumber: '42DN',
          departureTime: '12:30',
          arrivalTime: '07:50',
          arrivesNextDay: true,
          duration: '19h 20m',
          classSeats: {
            'AC Lower / Standard (Berth)': 95,
            'AC Business': 20,
            'Economy (Berth)': 65,
            'Economy (Seat)': 88
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 8300,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '3',
          trainName: 'Allama Iqbal Express',
          trainNumber: '10DN',
          departureTime: '14:00',
          arrivalTime: '11:30',
          arrivesNextDay: true,
          duration: '21h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 44,
            'AC Business': null,
            'Economy (Berth)': null,
            'Economy (Seat)': 62
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6900,
            'Economy (Seat)': 3550
          },
          availableClasses: ['AC Lower / Standard (Berth)', 'Economy (Seat)'],
          isRefundable: false,
        ),
        TrainResult(
          id: '4',
          trainName: 'Pak Business Express',
          trainNumber: '34DN',
          departureTime: '15:00',
          arrivalTime: '09:30',
          arrivesNextDay: true,
          duration: '18h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 180,
            'AC Business': null,
            'Economy (Berth)': 255,
            'Economy (Seat)': 140
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 8700,
            'Economy (Berth)': 5350,
            'Economy (Seat)': 5250
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '5',
          trainName: 'Tezgam',
          trainNumber: '8DN',
          departureTime: '16:00',
          arrivalTime: '12:30',
          arrivesNextDay: true,
          duration: '20h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 50,
            'AC Business': 25,
            'Economy (Berth)': 38,
            'Economy (Seat)': 75
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 7900,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '6',
          trainName: 'Karachi Express',
          trainNumber: '16DN',
          departureTime: '18:30',
          arrivalTime: '13:30',
          arrivesNextDay: true,
          duration: '19h 00m',
          classSeats: {
            'AC Lower / Standard (Berth)': 85,
            'AC Business': 5,
            'Economy (Berth)': 60,
            'Economy (Seat)': 50
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 7550,
            'AC Business': 10500,
            'Economy (Berth)': 4750,
            'Economy (Seat)': 4650
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
      ];

  // Quetta route trains
  List<TrainResult> _getQuettaTrains(bool fromKarachi) => [
        TrainResult(
          id: '1',
          trainName: 'Quetta Express',
          trainNumber: fromKarachi ? '1UP' : '2DN',
          departureTime: '10:00',
          arrivalTime: '06:30',
          arrivesNextDay: true,
          duration: '20h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 60,
            'AC Business': 20,
            'Economy (Berth)': 90,
            'Economy (Seat)': 45
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 7200,
            'AC Business': 11000,
            'Economy (Berth)': 4200,
            'Economy (Seat)': 3900
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '2',
          trainName: 'Jaffar Express',
          trainNumber: fromKarachi ? '25UP' : '26DN',
          departureTime: '21:00',
          arrivalTime: '20:30',
          arrivesNextDay: true,
          duration: '23h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 40,
            'AC Business': null,
            'Economy (Berth)': 75,
            'Economy (Seat)': 38
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 6800,
            'Economy (Berth)': 3800,
            'Economy (Seat)': 3600
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
          isRefundable: false,
        ),
      ];

  // Peshawar route trains
  List<TrainResult> _getPeshawarTrains(bool fromKarachi) => [
        TrainResult(
          id: '1',
          trainName: 'Khyber Mail',
          trainNumber: fromKarachi ? '5UP' : '6DN',
          departureTime: '06:00',
          arrivalTime: '08:30',
          arrivesNextDay: true,
          duration: '26h 30m',
          classSeats: {
            'AC Lower / Standard (Berth)': 70,
            'AC Business': 30,
            'Economy (Berth)': 100,
            'Economy (Seat)': 55
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 9200,
            'AC Business': 13500,
            'Economy (Berth)': 5400,
            'Economy (Seat)': 5100
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'AC Business',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
        TrainResult(
          id: '2',
          trainName: 'Shah Hussain Express',
          trainNumber: fromKarachi ? '19UP' : '20DN',
          departureTime: '14:45',
          arrivalTime: '19:30',
          arrivesNextDay: true,
          duration: '28h 45m',
          classSeats: {
            'AC Lower / Standard (Berth)': 55,
            'AC Business': null,
            'Economy (Berth)': 80,
            'Economy (Seat)': 65
          },
          classPrices: {
            'AC Lower / Standard (Berth)': 8800,
            'Economy (Berth)': 5100,
            'Economy (Seat)': 4900
          },
          availableClasses: [
            'AC Lower / Standard (Berth)',
            'Economy (Berth)',
            'Economy (Seat)'
          ],
        ),
      ];
  void _resetPriceRangeForSelectedClass() {
    final prices = _allTrains
        .where((train) => train.availableClasses.contains(_selectedTrainClass))
        .map((train) => train.classPrices[_selectedTrainClass] ?? 0.0)
        .where((price) => price > 0)
        .toList();

    if (prices.isEmpty) {
      _priceRange = const RangeValues(0, 0);
      return;
    }

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    _priceRange = RangeValues(minPrice, maxPrice);
  }

  void _applyFiltersAndSort() {
    setState(() {
      _trains = _allTrains.where((train) {
        if (!train.availableClasses.contains(_selectedTrainClass)) {
          return false;
        }

        final price = train.classPrices[_selectedTrainClass] ?? 0.0;
        if (price <= 0 ||
            price < _priceRange.start ||
            price > _priceRange.end) {
          return false;
        }

        final departureHour =
            int.tryParse(train.departureTime.split(':').first) ?? 0;
        if (departureHour < _departureTimeRange.start ||
            departureHour > _departureTimeRange.end) {
          return false;
        }

        if (_refundableOnly && !train.isRefundable) {
          return false;
        }

        return true;
      }).toList();

      switch (_sortBy) {
        case 'Cheapest':
          _trains.sort((a, b) {
            final priceA = a.classPrices[_selectedTrainClass] ?? 0.0;
            final priceB = b.classPrices[_selectedTrainClass] ?? 0.0;
            return priceA.compareTo(priceB);
          });
          break;
        case 'Fastest':
          _trains.sort((a, b) =>
              _parseDuration(a.duration).compareTo(_parseDuration(b.duration)));
          break;
        case 'Recommended':
        default:
          // Keep original order for recommended
          break;
      }
    });
  }

  void _showFiltersBottomSheet() {
    RangeValues tempPrice = _priceRange;
    RangeValues tempTime = _departureTimeRange;
    bool tempRefundable = _refundableOnly;

    final prices = _allTrains
        .where((train) => train.availableClasses.contains(_selectedTrainClass))
        .map((train) => train.classPrices[_selectedTrainClass] ?? 0.0)
        .where((price) => price > 0)
        .toList();

    final minPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxPrice =
        prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final sliderMax = maxPrice <= minPrice ? minPrice + 1 : maxPrice;

    if (tempPrice.start < minPrice || tempPrice.end > sliderMax) {
      tempPrice = RangeValues(minPrice, maxPrice);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filters', style: TravelloTheme.title2),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempPrice = RangeValues(minPrice, maxPrice);
                                tempTime = const RangeValues(0, 24);
                                tempRefundable = false;
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Color(0xFFD4AF37)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Price Range',
                              style: TravelloTheme.subtitle),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${formatPKR(tempPrice.start)} – ${formatPKR(tempPrice.end)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: tempPrice,
                        min: minPrice,
                        max: sliderMax,
                        divisions: prices.isEmpty ? 1 : 20,
                        activeColor: const Color(0xFFD4AF37),
                        inactiveColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        labels: RangeLabels(
                          formatPKR(tempPrice.start),
                          formatPKR(tempPrice.end),
                        ),
                        onChanged: prices.isEmpty
                            ? null
                            : (values) {
                                setModalState(() => tempPrice = values);
                              },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Departure Time',
                              style: TravelloTheme.subtitle),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${tempTime.start.round().toString().padLeft(2, '0')}:00 – ${tempTime.end.round() == 24 ? '24:00' : '${tempTime.end.round().toString().padLeft(2, '0')}:00'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: tempTime,
                        min: 0,
                        max: 24,
                        divisions: 24,
                        activeColor: const Color(0xFFD4AF37),
                        inactiveColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        labels: RangeLabels(
                          '${tempTime.start.round().toString().padLeft(2, '0')}:00',
                          tempTime.end.round() == 24
                              ? '24:00'
                              : '${tempTime.end.round().toString().padLeft(2, '0')}:00',
                        ),
                        onChanged: (values) {
                          setModalState(() => tempTime = values);
                        },
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => setModalState(
                            () => tempRefundable = !tempRefundable),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: tempRefundable
                                ? const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.06)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tempRefundable
                                  ? const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_shield_fill,
                                    color: tempRefundable
                                        ? const Color(0xFFD4AF37)
                                        : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Refundable trains only',
                                          style: TravelloTheme.subtitle),
                                      Text(
                                        'Show only cancellable tickets',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: tempRefundable,
                                onChanged: (value) {
                                  setModalState(() => tempRefundable = value);
                                },
                                activeThumbColor: const Color(0xFFD4AF37),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: R.rh(context, 52),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = tempPrice;
                              _departureTimeRange = tempTime;
                              _refundableOnly = tempRefundable;
                            });
                            _applyFiltersAndSort();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  int _parseDuration(String duration) {
    final parts = duration.split(' ');
    int minutes = 0;
    for (var part in parts) {
      if (part.contains('h')) {
        minutes += int.parse(part.replaceAll('h', '')) * 60;
      } else if (part.contains('m')) {
        minutes += int.parse(part.replaceAll('m', ''));
      }
    }
    return minutes;
  }

  @override
  Widget build(BuildContext context) {
    final fromStation = searchParams['fromStation'] as RailwayStation?;
    final toStation = searchParams['toStation'] as RailwayStation?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRoundTrip
                  ? _currentJourneyIndex == 0
                      ? '${fromStation?.code ?? 'DEP'} → ${toStation?.code ?? 'ARR'}'
                      : '${toStation?.code ?? 'ARR'} → ${fromStation?.code ?? 'DEP'}'
                  : '${fromStation?.code ?? 'DEP'} → ${toStation?.code ?? 'ARR'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_trains.length} trains found',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (_isRoundTrip && _currentJourneyIndex == 1) {
              // Go back to outbound selection
              setState(() {
                _currentJourneyIndex = 0;
                _selectedDate = searchParams['departureDate'] ?? DateTime.now();
                _selectedOutboundTrain = null;
                _selectedOutboundClass = null;
              });
              _fetchTrains();
            } else {
              Get.back();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.slider_horizontal_3,
                color: Colors.white),
            onPressed: _showFiltersBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Journey selector for round-trip
          if (_isRoundTrip)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentJourneyIndex == 0
                            ? const Color(0xFFD4AF37)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedOutboundTrain != null
                              ? const Color(0xFFD4AF37)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedOutboundTrain != null)
                            Icon(
                              Icons.check_circle,
                              color: _currentJourneyIndex == 0
                                  ? Colors.white
                                  : const Color(0xFFD4AF37),
                              size: 18,
                            ),
                          if (_selectedOutboundTrain != null)
                            const SizedBox(width: 4),
                          Text(
                            'Outbound',
                            style: TextStyle(
                              color: _currentJourneyIndex == 0
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    CupertinoIcons.arrow_right,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentJourneyIndex == 1
                            ? const Color(0xFFD4AF37)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentJourneyIndex == 1
                              ? const Color(0xFFD4AF37)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Return',
                        style: TextStyle(
                          color: _currentJourneyIndex == 1
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Always-visible search summary bar (like flight screen)
          _buildAlwaysVisibleSearchForm(),

          // Sort options
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
            child: Row(
              children: [
                const Text('Sort by:', style: TravelloTheme.caption),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip('Recommended'),
                        const SizedBox(width: 8),
                        _buildSortChip('Cheapest'),
                        const SizedBox(width: 8),
                        _buildSortChip('Fastest'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM, E').format(_selectedDate),
                  style: TravelloTheme.subtitle2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ],
            ),
          ),

          // Train list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _trains.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.train_style_one,
                                size: 80,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No trains found for this route',
                                style: TravelloTheme.title2,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try different cities or check bus alternatives',
                                style: TravelloTheme.caption
                                    .copyWith(color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.search),
                                label: const Text('Search Again'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TravelloTheme.primaryMain,
                                  side: const BorderSide(
                                      color: TravelloTheme.primaryMain),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trains.length,
                        itemBuilder: (context, index) {
                          final train = _trains[index];
                          return _buildTrainCard(train);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODIFY SEARCH MODAL (Train version)
  // ─────────────────────────────────────────────────────────────────────────

  void _showSearchModificationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSearchModificationSheet(),
    );
  }

  Widget _buildSearchModificationSheet() {
    RailwayStation? selectedFrom =
        searchParams['fromStation'] as RailwayStation?;
    RailwayStation? selectedTo = searchParams['toStation'] as RailwayStation?;
    DateTime selectedDepartureDate = _selectedDate;
    DateTime? selectedReturnDate = _selectedReturnDate;
    int selectedAdults = _adults;
    int selectedChildren = _children;
    int selectedInfants = _infants;
    String selectedClass = _selectedTrainClass;
    String tripType = _isRoundTrip ? 'Round-trip' : 'One-way';

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Modify Search',
                      style: TextStyle(
                        fontSize: R.sp(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip Type Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setFormState(() {
                                  tripType = 'One-way';
                                  selectedReturnDate = null;
                                }),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: tripType == 'One-way'
                                        ? const Color(0xFFD4AF37)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'One-way',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tripType == 'One-way'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setFormState(() {
                                  tripType = 'Round-trip';
                                  selectedReturnDate = selectedDepartureDate
                                      .add(const Duration(days: 7));
                                }),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: tripType == 'Round-trip'
                                        ? const Color(0xFFD4AF37)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Round-trip',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tripType == 'Round-trip'
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FROM station
                      _buildInlineStationDropdown(
                        label: 'FROM',
                        icon: Icons.train,
                        selectedStation: selectedFrom,
                        onChanged: (RailwayStation? s) =>
                            setFormState(() => selectedFrom = s),
                      ),

                      const SizedBox(height: 12),

                      // Swap button
                      Center(
                        child: InkWell(
                          onTap: () {
                            setFormState(() {
                              final temp = selectedFrom;
                              selectedFrom = selectedTo;
                              selectedTo = temp;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.swap_vert,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // TO station
                      _buildInlineStationDropdown(
                        label: 'TO',
                        icon: Icons.location_on,
                        selectedStation: selectedTo,
                        onChanged: (RailwayStation? s) =>
                            setFormState(() => selectedTo = s),
                      ),

                      const SizedBox(height: 16),

                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildInlineDatePicker(
                              label: 'DEPARTURE',
                              date: selectedDepartureDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDepartureDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  builder: (ctx, child) => Theme(
                                    data: Theme.of(ctx).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: Color(0xFFD4AF37)),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setFormState(() {
                                    selectedDepartureDate = picked;
                                    if (selectedReturnDate != null &&
                                        selectedReturnDate!.isBefore(picked)) {
                                      selectedReturnDate =
                                          picked.add(const Duration(days: 1));
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          if (tripType == 'Round-trip') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInlineDatePicker(
                                label: 'RETURN',
                                date: selectedReturnDate ??
                                    selectedDepartureDate
                                        .add(const Duration(days: 7)),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedReturnDate ??
                                        selectedDepartureDate
                                            .add(const Duration(days: 7)),
                                    firstDate: selectedDepartureDate,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.light(
                                            primary: Color(0xFFD4AF37)),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setFormState(
                                        () => selectedReturnDate = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Passengers
                      _buildInlinePassengerSelector(
                        adults: selectedAdults,
                        children: selectedChildren,
                        infants: selectedInfants,
                        onChanged: (Map<String, int> counts) {
                          setFormState(() {
                            selectedAdults = counts['adults']!;
                            selectedChildren = counts['children']!;
                            selectedInfants = counts['infants']!;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Train Class
                      _buildInlineTrainClassSelector(
                        selectedClass: selectedClass,
                        onChanged: (String? newClass) {
                          if (newClass != null) {
                            setFormState(() => selectedClass = newClass);
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        height: R.rh(context, 52),
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedFrom == null || selectedTo == null) {
                              Get.snackbar(
                                'Validation Error',
                                'Please select origin and destination stations',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }
                            if (selectedFrom?.code == selectedTo?.code) {
                              Get.snackbar(
                                'Validation Error',
                                'Origin and destination cannot be the same',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                              );
                              return;
                            }

                            setState(() {
                              searchParams['fromStation'] = selectedFrom;
                              searchParams['toStation'] = selectedTo;
                              searchParams['departureDate'] =
                                  selectedDepartureDate;
                              searchParams['returnDate'] = selectedReturnDate;
                              searchParams['adults'] = selectedAdults;
                              searchParams['children'] = selectedChildren;
                              searchParams['infants'] = selectedInfants;
                              searchParams['tripType'] = tripType;
                              searchParams['trainClass'] = selectedClass;

                              _adults = selectedAdults;
                              _children = selectedChildren;
                              _infants = selectedInfants;
                              _selectedTrainClass = selectedClass;
                              _selectedDate = selectedDepartureDate;

                              if (tripType == 'Round-trip') {
                                _isRoundTrip = true;
                                _currentJourneyIndex = 0;
                                _selectedOutboundTrain = null;
                                _selectedReturnDate = selectedReturnDate;
                              } else {
                                _isRoundTrip = false;
                                _currentJourneyIndex = 0;
                              }
                            });

                            _fetchTrains();
                            Navigator.pop(context);

                            Get.snackbar(
                              'Search Updated',
                              'Search updated: ${selectedFrom?.code} → ${selectedTo?.code}',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: const Color(0xFFD4AF37),
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Update Search',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
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
    );
  }

  // Station dropdown widget
  Widget _buildInlineStationDropdown({
    required String label,
    required IconData icon,
    required RailwayStation? selectedStation,
    required Function(RailwayStation?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final result = await _showStationSelectionModal(
          context: context,
          title: label,
          currentStation: selectedStation,
        );
        if (result != null) {
          onChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingUnit(0.75)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedStation != null
                        ? '${selectedStation.code} – ${selectedStation.city}'
                        : 'Select Station',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selectedStation != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFFD4AF37), size: 20),
              ],
            ),
            if (selectedStation != null)
              Text(
                selectedStation.name,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // Date picker widget (reusable)
  Widget _buildInlineDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.calendar,
                    size: 14, color: Color(0xFFD4AF37)),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingUnit(0.75)),
            Text(
              DateFormat('d MMM yyyy').format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('EEEE').format(date),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Passenger selector widget
  Widget _buildInlinePassengerSelector({
    required int adults,
    required int children,
    required int infants,
    required Function(Map<String, int>) onChanged,
  }) {
    String passengerText = '';
    if (adults > 0) passengerText += '$adults Adult${adults > 1 ? "s" : ""}';
    if (children > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$children Child${children > 1 ? "ren" : ""}';
    }
    if (infants > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$infants Infant${infants > 1 ? "s" : ""}';
    }

    return InkWell(
      onTap: () async {
        final result = await _showPassengerSelectionModal(
            context, adults, children, infants);
        if (result != null) onChanged(result);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.person_2_fill,
                    size: 16, color: Color(0xFFD4AF37)),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  'PASSENGERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  passengerText.isNotEmpty ? passengerText : '1 Adult',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                SizedBox(width: spacingUnit(0.75)),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD4AF37)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Train class selector widget
  Widget _buildInlineTrainClassSelector({
    required String selectedClass,
    required Function(String?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final result =
            await _showTrainClassSelectionModal(context, selectedClass);
        if (result != null) onChanged(result);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.train, size: 16, color: Color(0xFFD4AF37)),
                SizedBox(width: spacingUnit(0.75)),
                Text(
                  'TRAIN CLASS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  selectedClass,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                SizedBox(width: spacingUnit(0.75)),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD4AF37)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Station selection sheet
  Future<RailwayStation?> _showStationSelectionModal({
    required BuildContext context,
    required String title,
    RailwayStation? currentStation,
  }) async {
    return await showModalBottomSheet<RailwayStation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bsContext) {
        String searchQuery = '';
        final TextEditingController searchController = TextEditingController();
        final allStations = PakistanRailwayStations.getAllStations();

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allStations.where((s) {
              final q = searchQuery.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.code.toLowerCase().contains(q) ||
                  s.city.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Select Station ($title)',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    onChanged: (v) => setModalState(() => searchQuery = v),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by city, station or code',
                      prefixIcon: const Icon(CupertinoIcons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                  CupertinoIcons.clear_circled_solid),
                              onPressed: () => setModalState(() {
                                searchController.clear();
                                searchQuery = '';
                              }),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFD4AF37), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final station = filtered[idx];
                        final isCurrent = currentStation?.code == station.code;
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.train_style_one,
                              color: Color(0xFFD4AF37),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            station.name,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(station.city,
                              style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            station.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, station),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Passenger dialog
  Future<Map<String, int>?> _showPassengerSelectionModal(BuildContext context,
      int currentAdults, int currentChildren, int currentInfants) async {
    int adults = currentAdults;
    int children = currentChildren;
    int infants = currentInfants;

    return await showDialog<Map<String, int>>(
      context: context,
      barrierColor: Colors.grey.shade800.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Passengers',
                    style: TextStyle(
                        fontSize: R.sp(context, 22),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildPassengerRow(
                    label: 'Adults',
                    subtitle: '12+ years',
                    count: adults,
                    onDecrement:
                        adults > 1 ? () => setModalState(() => adults--) : null,
                    onIncrement:
                        adults < 9 ? () => setModalState(() => adults++) : null,
                  ),
                  const SizedBox(height: 20),
                  _buildPassengerRow(
                    label: 'Children',
                    subtitle: '2-11 years',
                    count: children,
                    onDecrement: children > 0
                        ? () => setModalState(() => children--)
                        : null,
                    onIncrement: children < 9
                        ? () => setModalState(() => children++)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildPassengerRow(
                    label: 'Infants',
                    subtitle: 'Under 2 years',
                    count: infants,
                    onDecrement: infants > 0
                        ? () => setModalState(() => infants--)
                        : null,
                    onIncrement: infants < 9
                        ? () => setModalState(() => infants++)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: R.rh(context, 50),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'adults': adults > 0 ? adults : 1,
                        'children': children,
                        'infants': infants,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Done',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildPassengerRow({
    required String label,
    required String subtitle,
    required int count,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: onDecrement,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: onDecrement != null
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove,
                    size: 20,
                    color: onDecrement != null
                        ? Colors.black
                        : Colors.grey.shade500),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 36,
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: onIncrement,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: onIncrement != null
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add,
                    size: 20,
                    color: onIncrement != null
                        ? Colors.black
                        : Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Train class selection dialog
  Future<String?> _showTrainClassSelectionModal(
      BuildContext context, String currentClass) async {
    String? selectedClass = currentClass;

    return await showDialog<String>(
      context: context,
      barrierColor: Colors.grey.shade800.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Train Class',
                    style: TextStyle(
                        fontSize: R.sp(context, 22),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildTrainClassOption(
                    label: 'Economy (Seat)',
                    subtitle: 'Sitting seats, budget friendly',
                    icon: Icons.airline_seat_recline_normal,
                    iconColor: const Color(0xFF3B82F6),
                    isSelected: selectedClass == 'Economy (Seat)',
                    onTap: () =>
                        setModalState(() => selectedClass = 'Economy (Seat)'),
                  ),
                  SizedBox(height: spacingUnit(1.25)),
                  _buildTrainClassOption(
                    label: 'Economy (Berth)',
                    subtitle: 'Sleeping berths, economy class',
                    icon: Icons.bed,
                    iconColor: const Color(0xFF10B981),
                    isSelected: selectedClass == 'Economy (Berth)',
                    onTap: () =>
                        setModalState(() => selectedClass = 'Economy (Berth)'),
                  ),
                  SizedBox(height: spacingUnit(1.25)),
                  _buildTrainClassOption(
                    label: 'AC Lower / Standard (Berth)',
                    subtitle: 'Air-conditioned sleeping berths',
                    icon: Icons.ac_unit,
                    iconColor: const Color(0xFFD946EF),
                    isSelected: selectedClass == 'AC Lower / Standard (Berth)',
                    onTap: () => setModalState(
                        () => selectedClass = 'AC Lower / Standard (Berth)'),
                  ),
                  SizedBox(height: spacingUnit(1.25)),
                  _buildTrainClassOption(
                    label: 'AC Business',
                    subtitle: 'Premium AC class, extra comfort',
                    icon: Icons.star,
                    iconColor: const Color(0xFFD4AF37),
                    isSelected: selectedClass == 'AC Business',
                    onTap: () =>
                        setModalState(() => selectedClass = 'AC Business'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: R.rh(context, 50),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, selectedClass),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Done',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildTrainClassOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFFD4AF37).withValues(alpha: 0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // ALWAYS-VISIBLE SEARCH FORM (matches flight screen header)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAlwaysVisibleSearchForm() {
    final fromStation = searchParams['fromStation'] as RailwayStation?;
    final toStation = searchParams['toStation'] as RailwayStation?;
    final tripType = _isRoundTrip ? 'Round-trip' : 'One-way';

    // Get screen width for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Build passenger display text
    String passengerText = '';
    if (_adults > 0) passengerText += '$_adults Adult${_adults > 1 ? "s" : ""}';
    if (_children > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$_children Child${_children > 1 ? "ren" : ""}';
    }
    if (_infants > 0) {
      if (passengerText.isNotEmpty) passengerText += ', ';
      passengerText += '$_infants Infant${_infants > 1 ? "s" : ""}';
    }

    final passengerSummary =
        passengerText.isNotEmpty ? passengerText : '1 Adult';
    final classSummary = isMobile
        ? (_classAbbr[_selectedTrainClass] ?? _selectedTrainClass)
        : _selectedTrainClass;

    return Container(
      color: const Color(0xFFD4AF37),
      padding: EdgeInsets.symmetric(
        horizontal: spacingUnit(isMobile ? 1 : 2),
        vertical: spacingUnit(isMobile ? 0.75 : 1.5),
      ),
      child: Column(
        children: [
          // Top row: Trip type tabs + passenger/class info
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTripTypeTab('Round Trip', tripType == 'Round-trip'),
                      SizedBox(width: spacingUnit(0.5)),
                      _buildTripTypeTab('One Way', tripType == 'One-way'),
                    ],
                  ),
                ),
                SizedBox(height: spacingUnit(0.5)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.person,
                          color: Colors.white, size: 12),
                      SizedBox(width: spacingUnit(0.25)),
                      Text(
                        passengerSummary,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(width: spacingUnit(0.75)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          classSummary,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildTripTypeTab('Round Trip', tripType == 'Round-trip'),
                    SizedBox(width: spacingUnit(1)),
                    _buildTripTypeTab('One Way', tripType == 'One-way'),
                  ],
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.person,
                            color: Colors.white, size: 16),
                        SizedBox(width: spacingUnit(0.5)),
                        Text(
                          passengerSummary,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: spacingUnit(2)),
                        Text(
                          classSummary,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          SizedBox(height: spacingUnit(isMobile ? 0.75 : 1.5)),

          // Bottom row: FROM-TO pill | Date pill | Modify Search button
          Row(
            children: [
              // FROM — TO
              isMobile
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacingUnit(0.75),
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.train_style_one,
                              color: Colors.white70, size: 12),
                          SizedBox(width: spacingUnit(0.25)),
                          Text(
                            fromStation?.code ?? 'FROM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(Icons.swap_horiz,
                                color: Colors.white70, size: 14),
                          ),
                          Text(
                            toStation?.code ?? 'TO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.train_style_one,
                                color: Colors.white70, size: 16),
                            SizedBox(width: spacingUnit(0.75)),
                            Flexible(
                              child: Text(
                                '${fromStation?.code ?? 'FROM'} - ${fromStation?.city ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.swap_horiz,
                                  color: Colors.white70, size: 20),
                            ),
                            Flexible(
                              child: Text(
                                '${toStation?.code ?? 'TO'} - ${toStation?.city ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              SizedBox(width: spacingUnit(isMobile ? 0.5 : 1.5)),

              // Date
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacingUnit(isMobile ? 0.75 : 1.5),
                    vertical: spacingUnit(isMobile ? 0.5 : 1),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.calendar,
                          color: Colors.white70, size: isMobile ? 12 : 16),
                      SizedBox(width: spacingUnit(isMobile ? 0.25 : 0.75)),
                      Flexible(
                        child: Text(
                          _isRoundTrip && _selectedReturnDate != null
                              ? '${DateFormat(isMobile ? 'd MMM' : 'd MMM').format(_selectedDate)} - ${DateFormat(isMobile ? 'd MMM' : 'd MMM yyyy').format(_selectedReturnDate!)}'
                              : DateFormat(
                                      isMobile ? 'd MMM yyyy' : 'd MMM yyyy')
                                  .format(_selectedDate),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: spacingUnit(isMobile ? 0.5 : 1.5)),

              // Modify Search Button
              ElevatedButton.icon(
                onPressed: _showSearchModificationModal,
                icon: Icon(Icons.search, size: isMobile ? 14 : 18),
                label: Text(
                  isMobile ? 'Modify' : 'Modify Search',
                  style: TextStyle(fontSize: isMobile ? 11 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: EdgeInsets.symmetric(
                    horizontal: spacingUnit(isMobile ? 0.75 : 2),
                    vertical: spacingUnit(isMobile ? 0.5 : 1.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripTypeTab(String label, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: spacingUnit(0.75),
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSortChip(String label) {
    final selected = _sortBy == label;
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setChipState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setChipState(() => isHovered = true),
          onExit: (_) => setChipState(() => isHovered = false),
          child: GestureDetector(
            onTap: () {
              setState(() => _sortBy = label);
              _applyFiltersAndSort();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFD4AF37)
                    : isHovered
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD4AF37)
                      : isHovered
                          ? const Color(0xFFD4AF37)
                          : Colors.grey.withValues(alpha: 0.3),
                  width: selected || isHovered ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const Map<String, String> _classAbbr = {
    'Economy (Seat)': 'ECS',
    'Economy (Berth)': 'EC',
    'AC Lower / Standard (Berth)': 'ACSB',
    'AC Business': 'ACLZ',
  };

  static const List<String> _classOrder = [
    'Economy (Seat)',
    'Economy (Berth)',
    'AC Lower / Standard (Berth)',
    'AC Business',
  ];

  Widget _buildClassGrid(TrainResult train) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: _classOrder.map((cls) {
          final abbr = _classAbbr[cls] ?? cls;
          final seats = train.classSeats[cls];
          final price = train.classPrices[cls];
          final isSelected = cls == _selectedTrainClass;
          final isNA = seats == null || price == null;

          bool isHovered = false;
          return Expanded(
            child: StatefulBuilder(
              builder: (context, setChipState) {
                return MouseRegion(
                  cursor: isNA
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onEnter: (_) => setChipState(() => isHovered = true),
                  onExit: (_) => setChipState(() => isHovered = false),
                  child: GestureDetector(
                    onTap: isNA
                        ? null
                        : () {
                            setState(() => _selectedTrainClass = cls);
                            _resetPriceRangeForSelectedClass();
                            _applyFiltersAndSort();
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
                            : isHovered && !isNA
                                ? const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.05)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFFD4AF37), width: 1.5)
                            : isHovered && !isNA
                                ? Border.all(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.3),
                                    width: 1)
                                : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            abbr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFFB89930)
                                  : isNA
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isNA ? 'N/A' : 'Rs.${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isNA
                                  ? Colors.grey[400]
                                  : isSelected
                                      ? const Color(0xFFC6A75E)
                                      : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrainCard(TrainResult train) {
    final priceForClass = train.classPrices[_selectedTrainClass] ?? 0.0;
    final isSelectedOutbound = _isRoundTrip &&
        _currentJourneyIndex == 1 &&
        _selectedOutboundTrain?.id == train.id;

    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform:
                Matrix4.translationValues(0.0, isHovered ? -4.0 : 0.0, 0.0),
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: isHovered ? 8 : (isSelectedOutbound ? 4 : 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isSelectedOutbound
                    ? const BorderSide(color: Color(0xFFD4AF37), width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () {
                  _handleTrainSelection(train, _selectedTrainClass);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Badge for fastest/cheapest
                      if (_getBadge(train).isNotEmpty)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getBadge(train) == 'Cheapest'
                                      ? [
                                          const Color(0xFFD4AF37),
                                          const Color(0xFFE6C68E)
                                        ]
                                      : _getBadge(train) == 'Fastest'
                                          ? [Colors.blue, Colors.blueAccent]
                                          : [
                                              Colors.orange,
                                              Colors.orangeAccent
                                            ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getBadge(train) == 'Cheapest'
                                        ? CupertinoIcons.money_dollar_circle
                                        : _getBadge(train) == 'Fastest'
                                            ? CupertinoIcons.bolt_fill
                                            : CupertinoIcons.star_fill,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getBadge(train),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      if (_getBadge(train).isNotEmpty)
                        const SizedBox(height: 12),

                      // Train info and timing
                      Row(
                        children: [
                          // Train logo/icon
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              CupertinoIcons.train_style_one,
                              color: Color(0xFFD4AF37),
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Time and route info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Departure
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          train.departureTime,
                                          style: TravelloTheme.title2.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _isRoundTrip &&
                                                  _currentJourneyIndex == 1
                                              ? searchParams['toStation']
                                                      ?.code ??
                                                  'DEP'
                                              : searchParams['fromStation']
                                                      ?.code ??
                                                  'DEP',
                                          style: TravelloTheme.caption.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFD4AF37),
                                          ),
                                        ),
                                        SizedBox(height: spacingUnit(0.3)),
                                        Text(
                                          _isRoundTrip &&
                                                  _currentJourneyIndex == 1
                                              ? searchParams['toStation']
                                                      ?.name ??
                                                  ''
                                              : searchParams['fromStation']
                                                      ?.name ??
                                                  '',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        Text(
                                          DateFormat('dd MMM')
                                              .format(_selectedDate),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Duration and route line
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.time,
                                                size: 12,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                train.duration,
                                                style: TravelloTheme.caption
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFD4AF37),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  height: 2,
                                                  color:
                                                      const Color(0xFFD4AF37),
                                                ),
                                              ),
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFD4AF37),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD4AF37)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFD4AF37)
                                                    .withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Text(
                                              '– Direct',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFD4AF37),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrival
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              train.arrivalTime,
                                              style:
                                                  TravelloTheme.title2.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (train.arrivesNextDay)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    left: 3, top: 2),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                        Text(
                                          _isRoundTrip &&
                                                  _currentJourneyIndex == 1
                                              ? searchParams['fromStation']
                                                      ?.code ??
                                                  'ARR'
                                              : searchParams['toStation']
                                                      ?.code ??
                                                  'ARR',
                                          style: TravelloTheme.caption.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFD4AF37),
                                          ),
                                        ),
                                        SizedBox(height: spacingUnit(0.3)),
                                        Text(
                                          _isRoundTrip &&
                                                  _currentJourneyIndex == 1
                                              ? searchParams['fromStation']
                                                      ?.name ??
                                                  ''
                                              : searchParams['toStation']
                                                      ?.name ??
                                                  '',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        Text(
                                          DateFormat('dd MMM').format(
                                            train.arrivesNextDay
                                                ? _selectedDate.add(
                                                    const Duration(days: 1))
                                                : _selectedDate,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Train name and available info
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            train.trainName,
                                            style:
                                                TravelloTheme.caption.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              train.trainNumber,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Class grid — all 4 classes with seats + price
                      _buildClassGrid(train),

                      const SizedBox(height: 12),

                      Divider(
                          height: 1, color: Colors.grey.withValues(alpha: 0.2)),

                      const SizedBox(height: 12),

                      // Price and select button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (priceForClass > 0)
                                ...([
                                  Text(
                                    _selectedTrainClass,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.money_dollar_circle,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Base fare per person',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: spacingUnit(0.3)),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatPKR(priceForClass),
                                        style: TravelloTheme.title2.copyWith(
                                          color: const Color(0xFFD4AF37),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ])
                              else
                                Text(
                                  'Not available in $_selectedTrainClass',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.orange[700]),
                                ),
                              if (isSelectedOutbound)
                                const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: Color(0xFFD4AF37),
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Outbound Selected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: priceForClass > 0
                                ? () {
                                    _handleTrainSelection(
                                        train, _selectedTrainClass);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Select',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTrainSelection(TrainResult train, String trainClass) async {
    // Auth gate at Select — industry standard (browsing was free)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isGuest = await AuthService.isGuestMode();
    if (isGuest && mounted) {
      AuthGateSheet.show(nav.context, action: 'to book this train');
      return;
    }
    // Handle round-trip selection
    if (_isRoundTrip && _currentJourneyIndex == 0) {
      // Outbound selected, move to return
      setState(() {
        _selectedOutboundTrain = train;
        _selectedOutboundClass = trainClass;
        _currentJourneyIndex = 1;
        _selectedDate = _selectedReturnDate ?? _selectedDate;
      });
      _fetchTrains();

      // Show message
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Outbound train selected. Now select return train.'),
          backgroundColor: Color(0xFFD4AF37),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // One-way or return journey selected, proceed to passenger details
      Get.toNamed(
        '/train-passengers',
        arguments: {
          'train': train,
          'selectedClass': trainClass,
          'searchParams': searchParams,
          'isRoundTrip': _isRoundTrip,
          'outboundTrain': _selectedOutboundTrain,
          'outboundClass': _selectedOutboundClass,
          'returnTrain': _isRoundTrip ? train : null,
          'returnClass': _isRoundTrip ? trainClass : null,
        },
      );
    }
  }

  String _getBadge(TrainResult train) {
    if (_trains.isEmpty) return '';

    // Get cheapest train for selected class
    final cheapestTrain = _trains.reduce((a, b) {
      final priceA = a.classPrices[_selectedTrainClass] ?? double.infinity;
      final priceB = b.classPrices[_selectedTrainClass] ?? double.infinity;
      return priceA < priceB ? a : b;
    });

    // Get fastest train
    final fastestTrain = _trains.reduce((a, b) {
      return _parseDuration(a.duration) < _parseDuration(b.duration) ? a : b;
    });

    if (train.id == cheapestTrain.id) return 'Cheapest';
    if (train.id == fastestTrain.id) return 'Fastest';
    if (_trains.indexOf(train) == 0 && _sortBy == 'Recommended') {
      return 'Recommended';
    }

    return '';
  }
}
