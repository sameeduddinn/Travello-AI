import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/widgets/home/city_destinations/city_destinations_grid.dart';
import 'package:flight_app/widgets/home/city_destinations/city_destinations_list.dart';
import 'package:flutter/material.dart';

class CityDestinations extends StatelessWidget {
  const CityDestinations({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeBreakpoints.smUp(context) ? const CityDestinationsList()
    : const CityDestinationsGrid();
  }
}