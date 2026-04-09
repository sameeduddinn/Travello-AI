import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/models/train.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SearchRailwayScreen extends StatefulWidget {
  const SearchRailwayScreen({super.key});

  @override
  State<SearchRailwayScreen> createState() => _SearchRailwayScreenState();
}

class _SearchRailwayScreenState extends State<SearchRailwayScreen> {
  final _formKey = GlobalKey<FormState>();

  RailwayStation? _selectedFromStation;
  RailwayStation? _selectedToStation;
  DateTime _selectedDate = DateTime.now();
  String _selectedClass = 'AC Business';
  int _passengers = 1;

  final List<RailwayStation> _allStations =
      PakistanRailwayStations.getAllStations();
  final List<String> _trainClasses = PakistanTrains.getTrainClasses();

  void _swapStations() {
    setState(() {
      final temp = _selectedFromStation;
      _selectedFromStation = _selectedToStation;
      _selectedToStation = temp;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _searchTrains() {
    if (_formKey.currentState!.validate()) {
      if (_selectedFromStation == null || _selectedToStation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both stations')),
        );
        return;
      }

      if (_selectedFromStation!.code == _selectedToStation!.code) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Departure and arrival stations cannot be the same')),
        );
        return;
      }

      // Navigate to train list screen with search parameters
      Get.toNamed(
        AppLink.railwayList,
        arguments: {
          'fromStation': _selectedFromStation!.name,
          'toStation': _selectedToStation!.name,
          'date': _selectedDate,
          'trainClass': _selectedClass,
          'passengers': _passengers,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Trains'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Railway Icon Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.train, size: 60, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Pakistan Railways',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Book your train journey',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // From Station
                const Text('From Station', style: TravelloTheme.subtitle),
                const SizedBox(height: 8),
                DropdownButtonFormField<RailwayStation>(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  hint: const Text('Select departure station'),
                  initialValue: _selectedFromStation,
                  items: _allStations.map((station) {
                    return DropdownMenuItem(
                      value: station,
                      child: Text('${station.name} (${station.code})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFromStation = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Please select departure station';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Swap Button
                Center(
                  child: IconButton(
                    onPressed: _swapStations,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TravelloTheme.primaryMainContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        color: colorScheme(context).onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // To Station
                const Text('To Station', style: TravelloTheme.subtitle),
                const SizedBox(height: 8),
                DropdownButtonFormField<RailwayStation>(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  hint: const Text('Select arrival station'),
                  initialValue: _selectedToStation,
                  items: _allStations.map((station) {
                    return DropdownMenuItem(
                      value: station,
                      child: Text('${station.name} (${station.code})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedToStation = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Please select arrival station';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Travel Date
                const Text('Travel Date', style: TravelloTheme.subtitle),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TravelloTheme.paragraph,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Train Class
                const Text('Train Class', style: TravelloTheme.subtitle),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => Container(
                        decoration: const BoxDecoration(
                          color: TravelloTheme.paperLight,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Grabber
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Text('Train Class', style: TravelloTheme.title2),
                            const SizedBox(height: 24),
                            ..._trainClasses
                                .where((c) => c != 'All')
                                .map((trainClass) {
                              final isSelected = _selectedClass == trainClass;
                              IconData classIcon;
                              Color classColor;
                              String description;

                              switch (trainClass) {
                                case 'AC Business':
                                  classIcon = Icons.business_center;
                                  classColor = Colors.purple;
                                  description = 'Premium comfort with AC';
                                  break;
                                case 'AC Standard':
                                  classIcon = Icons.event_seat;
                                  classColor = Colors.blue;
                                  description = 'Standard AC seating';
                                  break;
                                case 'AC Sleeper':
                                  classIcon = Icons.hotel;
                                  classColor = Colors.indigo;
                                  description = 'AC berths for overnight';
                                  break;
                                case 'Economy':
                                  classIcon = Icons.chair;
                                  classColor = const Color(0xFFD4AF37);
                                  description = 'Budget-friendly option';
                                  break;
                                default:
                                  classIcon = Icons.train;
                                  classColor = Colors.grey;
                                  description = '';
                              }

                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD4AF37)
                                        : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                      ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedClass = trainClass);
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: classColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            classIcon,
                                            color: classColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                trainClass,
                                                style:
                                                    TravelloTheme.subtitle.copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              if (description.isNotEmpty)
                                                Text(
                                                  description,
                                                  style: TravelloTheme.caption
                                                      .copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Radio<String>(
                                          value: trainClass,
                                          groupValue: _selectedClass,
                                          activeColor: const Color(0xFFD4AF37),
                                          onChanged: (value) {
                                            setState(() =>
                                                _selectedClass = trainClass);
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.airline_seat_recline_normal),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                            ).border !=
                            null
                        ? BoxDecoration(
                            color: TravelloTheme.paperLightContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          )
                        : BoxDecoration(
                            color: TravelloTheme.paperLightContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                    child: Row(
                      children: [
                        const Icon(Icons.airline_seat_recline_normal),
                        const SizedBox(width: 16),
                        Text(
                          _selectedClass,
                          style: TravelloTheme.paragraph,
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Passengers
                const Text('Passengers', style: TravelloTheme.subtitle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: TravelloTheme.paperLightContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.person),
                            Text(
                              '$_passengers ${_passengers == 1 ? 'Passenger' : 'Passengers'}',
                              style: TravelloTheme.paragraph,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _passengers > 1
                                      ? () => setState(() => _passengers--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                IconButton(
                                  onPressed: _passengers < 9
                                      ? () => setState(() => _passengers++)
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Search Button
                FilledButton(
                  style: ThemeButton.btnBig,
                  onPressed: _searchTrains,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 8),
                      Text('Search Trains', style: TravelloTheme.subtitle),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

