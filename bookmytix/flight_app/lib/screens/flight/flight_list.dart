import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/widgets/flight/info_header.dart';
import 'package:flight_app/widgets/flight/flight_trip_list.dart';
import 'package:flight_app/widgets/search_filters/filter_bottom_floating.dart';
import 'package:flight_app/widgets/search_filters/filter_date_slider.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_hide/scroll_to_hide.dart';

class FlightList extends StatefulWidget {
  const FlightList({super.key});

  @override
  State<FlightList> createState() => _FlightListState();
}

class _FlightListState extends State<FlightList> {
  final ScrollController _scrollController = ScrollController();

  RangeValues _priceRange = const RangeValues(400, 800);
  final List<Plane> _selectedAirlines = [];
  final List<int> _stopTransits = [0, 1, 2];
  double _duration = 16;

  List<Trip> allData = [];
  List<Trip> resultFlight = [];
  List<Trip> filterFlights(List<Trip> flights,
      {double? maxPrice,
      double? minPrice,
      List<Plane>? airlines,
      List<int>? transits,
      double? duration}) {
    return flights.where((item) {
      bool matchesAirline = airlines == null ||
          airlines.isEmpty ||
          _selectedAirlines.contains(item.plane);
      bool matchesPrice = maxPrice == null ||
          minPrice == null ||
          item.price >= minPrice && item.price <= maxPrice;
      bool matchesTransit =
          transits == null || _stopTransits.contains(item.transit);
      bool matchesDuration = duration == null ||
          (item.arrival.difference(item.depart)).inHours <= duration;

      return matchesAirline &&
          matchesPrice &&
          matchesTransit &&
          matchesDuration;
    }).toList();
  }

  void sortFlights(String criteria, {bool descending = false}) {
    setState(() {
      filterFlights(allData).sort((a, b) {
        dynamic valueA;
        dynamic valueB;

        switch (criteria) {
          case 'best':
            valueA = a.label;
            valueB = b.label;
            break;
          case 'cheapest':
            valueA = a.price;
            valueB = b.price;
            break;
          case 'transit':
            valueA = a.transit;
            valueB = b.transit;
            break;
          case 'discount':
            valueA = a.discount;
            valueB = b.discount;
            break;
          case 'name':
            valueA = a.plane.name;
            valueB = b.plane.name;
            break;
          case 'depart':
            valueA = a.depart;
            valueB = b.depart;
            break;
          case 'arrival':
            valueA = a.arrival;
            valueB = b.arrival;
            break;
          default:
            return 0; // No sorting if an invalid criteria is passed
        }

        return descending ? valueB.compareTo(valueA) : valueA.compareTo(valueB);
      });
    });
  }

  void changePrice(RangeValues values) {
    setState(() {
      _priceRange = values;
      resultFlight = filterFlights(allData,
          airlines: _selectedAirlines,
          minPrice: values.start,
          maxPrice: values.end,
          duration: _duration,
          transits: _stopTransits);
    });
  }

  void selectAirlines(String type, Plane plane) {
    setState(() {
      if (type == 'add') {
        _selectedAirlines.add(plane);
      } else {
        _selectedAirlines.remove(plane);
      }

      resultFlight = filterFlights(allData,
          airlines: _selectedAirlines,
          minPrice: _priceRange.start,
          maxPrice: _priceRange.end,
          duration: _duration,
          transits: _stopTransits);
    });
  }

  void selectTransits(String type, int val) {
    setState(() {
      if (type == 'add') {
        _stopTransits.add(val);
      } else {
        _stopTransits.remove(val);
      }

      resultFlight = filterFlights(allData,
          airlines: _selectedAirlines,
          minPrice: _priceRange.start,
          maxPrice: _priceRange.end,
          duration: _duration,
          transits: _stopTransits);
    });
  }

  void changeDuration(double val) {
    setState(() {
      _duration = val;

      resultFlight = filterFlights(allData,
          airlines: _selectedAirlines,
          minPrice: _priceRange.start,
          maxPrice: _priceRange.end,
          duration: val,
          transits: _stopTransits);
    });
  }

  @override
  void initState() {
    super.initState();
    allData.addAll(tripList);
    resultFlight.addAll(tripList);
    sortFlights('best', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: InfoHeader(
          date: 'Fri, Oct 20',
          from: cityList[1].code,
          to: cityList[2].code,
          passengers: 1,
        ),
      ),
      body: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          /// DATE PICKER
          const FilterDateSlider(),
          Divider(
            color: Theme.of(context).colorScheme.outline,
          ),

          /// FLIGHT LIST
          Expanded(
              child: FlightTripList(
            scrollRef: _scrollController,
            flightData: resultFlight,
          ))
        ]),
      ),
      bottomNavigationBar: ScrollToHide(
          scrollController: _scrollController,
          height: 100,
          hideDirection: Axis.vertical,
          child: FilterBottomFloating(
            onSortBest: () {
              sortFlights('best', descending: true);
            },
            onSortCheapest: () {
              sortFlights('cheapest');
            },
            onSortDiscount: () {
              sortFlights('discount', descending: true);
            },
            onSortPlaneName: () {
              sortFlights('name');
            },
            onSortTransits: () {
              sortFlights('transit');
            },
            onSortDepart: () {
              sortFlights('depart');
            },
            onSortArrival: () {
              sortFlights('arival');
            },
            priceRange: _priceRange,
            duration: _duration,
            selectedAirlines: _selectedAirlines,
            transits: _stopTransits,
            onChangePrice: (RangeValues val) {
              changePrice(val);
            },
            onChangeDuration: (double val) {
              changeDuration(val);
            },
            onUpdateTransit: (String type, int val) {
              selectTransits(type, val);
            },
            onUpdateAirlines: (String type, Plane item) {
              selectAirlines(type, item);
            },
          )),
    );
  }
}
