import 'package:flight_app/models/train.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class RailwayListScreen extends StatefulWidget {
  const RailwayListScreen({super.key});

  @override
  State<RailwayListScreen> createState() => _RailwayListScreenState();
}

class _RailwayListScreenState extends State<RailwayListScreen> {
  late List<Train> _trains;
  late String _fromStation;
  late String _toStation;
  late DateTime _date;
  late String _trainClass;
  late int _passengers;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _fromStation = args['fromStation'] as String;
    _toStation = args['toStation'] as String;
    _date = args['date'] as DateTime;
    _trainClass = args['trainClass'] as String;
    _passengers = args['passengers'] as int;

    // Get filtered trains
    _trains = PakistanTrains.getDummyTrains(
      fromStation: _fromStation,
      toStation: _toStation,
      trainClass: _trainClass == 'All' ? null : _trainClass,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Trains'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Summary
            Container(
              padding: const EdgeInsets.all(16),
              color: TravelloTheme.primaryMainContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.train,
                              size: 16,
                              color: colorScheme(context).onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_fromStation → $_toStation',
                                style: TravelloTheme.subtitle.copyWith(
                                  color:
                                      colorScheme(context).onPrimaryContainer,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_date.day}/${_date.month}/${_date.year} • $_passengers ${_passengers == 1 ? 'Passenger' : 'Passengers'}',
                          style: TravelloTheme.caption.copyWith(
                            color: colorScheme(context).onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _trains.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: colorScheme(context).outline,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No trains found',
                            style: TravelloTheme.title2,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your search criteria',
                            style: TravelloTheme.caption,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trains.length,
                      itemBuilder: (context, index) {
                        return _TrainCard(
                          train: _trains[index],
                          passengers: _passengers,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainCard extends StatelessWidget {
  final Train train;
  final int passengers;

  const _TrainCard({
    required this.train,
    required this.passengers,
  });

  @override
  Widget build(BuildContext context) {
    final totalPrice = train.price * passengers;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Train Name & Number
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        train.name,
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      Text(
                        'Train #${train.trainNumber}',
                        style: TravelloTheme.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme(context).tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    train.trainClass,
                    style: TravelloTheme.caption.copyWith(
                      color: colorScheme(context).onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time & Duration
            Row(
              children: [
                // Departure
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        train.departureTime,
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      Text(
                        train.fromStation,
                        style: TravelloTheme.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Duration
                Column(
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      color: TravelloTheme.primaryMain,
                    ),
                    Text(
                      train.duration,
                      style: TravelloTheme.caption,
                    ),
                  ],
                ),

                // Arrival
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        train.arrivalTime,
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      Text(
                        train.toStation,
                        style: TravelloTheme.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seats & Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_seat,
                      size: 16,
                      color: train.availableSeats < 20
                          ? Colors.orange
                          : const Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${train.availableSeats} seats left',
                      style: TravelloTheme.caption.copyWith(
                        color: train.availableSeats < 20
                            ? Colors.orange
                            : const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                Text(
                  'PKR ${totalPrice.toStringAsFixed(0)}',
                  style: TravelloTheme.title.copyWith(
                    fontSize: 16,
                    color: TravelloTheme.primaryMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Book Button
            FilledButton(
              style: ThemeButton.btnBig,
              onPressed: () {
                Get.toNamed(
                  '/railway-booking-passengers',
                  arguments: {
                    'train': train,
                  },
                );
              },
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }
}

