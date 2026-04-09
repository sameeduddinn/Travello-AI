import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/widgets/flight/info_header.dart';
import 'package:flight_app/widgets/flight/flight_trip_list.dart';
import 'package:flight_app/widgets/flight/round_trip_review.dart';
import 'package:flight_app/widgets/flight/round_trip_tab.dart';
import 'package:flight_app/widgets/search_filters/filter_bottom_floating.dart';
import 'package:flight_app/widgets/search_filters/filter_date_slider.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_hide/scroll_to_hide.dart';

class FlightListRoundtrip extends StatefulWidget {
  const FlightListRoundtrip({super.key});

  @override
  State<FlightListRoundtrip> createState() => _FlightListRoundtripState();
}

class _FlightListRoundtripState extends State<FlightListRoundtrip> {
  final ScrollController _scrollController = ScrollController();

  /// FILTER AND ORDER
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

  RangeValues _priceRange = const RangeValues(400, 800);
  final List<Plane> _selectedAirlines = [];
  final List<int> _stopTransits = [0, 1, 2];
  double _duration = 16;

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

  /// TAB MENU DEPAR RETURN

  int _tabMenuIndex = 1;
  bool _departDone = true;
  bool _returnDone = false;

  void _setTabMenu(int index) {
    setState(() {
      _tabMenuIndex = index;
    });
  }

  void _chooseFlight(String type, bool status) {
    if (type == 'depart') {
      _departDone = status;
    } else {
      _returnDone = status;
    }
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
          date: 'Fri, Oct 20 - Tue, Oct 24',
          from: cityList[1].code,
          to: cityList[2].code,
          passengers: 1,
          roundTrip: true,
        ),
      ),
      body: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          /// TAB MENU ROUND-TRIP
          RoundTripTab(setTabMenu: _setTabMenu, tabMenuIndex: _tabMenuIndex),

          /// DATE PICKER
          const FilterDateSlider(),
          Divider(
            color: colorScheme(context).outline,
          ),

          /// FLIGHT LIST
          Expanded(
              child: _tabMenuIndex == 0
                  ? _departReturn(context, _departDone)
                  : _departReturn(context, _returnDone)),
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

  Widget _departReturn(BuildContext context, bool isChosen) {
    if (isChosen) {
      return RoundTripReview(
        onEditDepart: () {
          _setTabMenu(0);
          _chooseFlight('depart', false);
        },
        onEditReturn: () {
          _setTabMenu(1);
          _chooseFlight('return', false);
        },
      );
    }
    return FlightTripList(
        scrollRef: _scrollController, flightData: resultFlight);
  }
}
