import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/utils/search_history_service.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CityListAutocomplete extends StatefulWidget {
  const CityListAutocomplete({super.key, required this.keyword});

  final String keyword;

  @override
  State<CityListAutocomplete> createState() => _CityListAutocompleteState();
}

class _CityListAutocompleteState extends State<CityListAutocomplete> {
  String _travelMode = 'flight';

  @override
  void initState() {
    super.initState();
    _loadTravelMode();
  }

  Future<void> _loadTravelMode() async {
    final mode = await SearchHistoryService.getTravelMode();
    setState(() {
      _travelMode = mode;
    });
  }

  Future<void> _handleSelection(String cityName) async {
    // Save to appropriate history based on mode
    if (_travelMode == 'flight') {
      await SearchHistoryService.saveFlightSearch(cityName);
      // Navigate to comprehensive city search results
      Get.toNamed('/city-search-results', arguments: {'cityName': cityName});
    } else {
      await SearchHistoryService.saveTrainSearch(cityName);
      // Navigate to train search results (similar page can be created)
      Get.toNamed('/city-search-results', arguments: {'cityName': cityName});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_travelMode == 'flight') {
      // Show airports for flight mode
      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: airportList.length,
        itemBuilder: (context, index) {
          final Airport item = airportList[index];
          final String location = '${item.location}, ${item.name}';
          if (!location.toLowerCase().contains(widget.keyword.toLowerCase())) {
            return const SizedBox.shrink();
          }
          return ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: TravelloTheme.primaryMainContainer,
              child: Icon(Icons.flight,
                  color: colorScheme(context).onPrimaryContainer),
            ),
            title: Text(item.location,
                style:
                    TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(item.name, style: TravelloTheme.caption),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TravelloTheme.paperLightContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(item.code, style: TravelloTheme.subtitle),
            ),
            onTap: () => _handleSelection(item.location),
          );
        },
      );
    } else {
      // Show railway stations for train mode
      final railwayStationList = PakistanRailwayStations.getAllStations();
      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: railwayStationList.length,
        itemBuilder: (context, index) {
          final RailwayStation item = railwayStationList[index];
          final String location = '${item.name}, ${item.city}';
          if (!location.toLowerCase().contains(widget.keyword.toLowerCase())) {
            return const SizedBox.shrink();
          }
          return ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: TravelloTheme.secondaryMainContainer,
              child: Icon(Icons.train,
                  color: colorScheme(context).onSecondaryContainer),
            ),
            title: Text(item.name,
                style:
                    TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(item.city, style: TravelloTheme.caption),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TravelloTheme.paperLightContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(item.code, style: TravelloTheme.subtitle),
            ),
            onTap: () => _handleSelection(item.name),
          );
        },
      );
    }
  }
}
