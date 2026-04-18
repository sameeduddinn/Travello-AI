import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/utils/search_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CitySelectorDropdown extends StatefulWidget {
  const CitySelectorDropdown({
    super.key,
    required this.keyword,
    required this.onCitySelected,
  });

  final String keyword;
  final Function(String cityName, String cityCode) onCitySelected;

  @override
  State<CitySelectorDropdown> createState() => _CitySelectorDropdownState();
}

class _CitySelectorDropdownState extends State<CitySelectorDropdown> {
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

  void _handleSelection(String cityName, String cityCode) {
    // Just callback to parent, don't navigate
    widget.onCitySelected(cityName, cityCode);
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
            onTap: () => _handleSelection(item.location, item.code),
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
            onTap: () => _handleSelection(item.name, item.code),
          );
        },
      );
    }
  }
}
