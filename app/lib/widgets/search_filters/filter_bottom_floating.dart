import 'package:flight_app/models/list_item.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/utils/picker.dart';
import 'package:flight_app/widgets/search_filters/filter_flight_form.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FilterBottomFloating extends StatefulWidget {
  const FilterBottomFloating({
    super.key,
    // Sorter Function
    required this.onSortBest,
    required this.onSortCheapest,
    required this.onSortTransits,
    required this.onSortDiscount,
    required this.onSortPlaneName,
    required this.onSortDepart,
    required this.onSortArrival,

    // Filter Function
    required this.onChangePrice, required this.onUpdateAirlines,
    required this.onUpdateTransit, required this.onChangeDuration,
    required this.priceRange, required this.selectedAirlines,
    required this.transits, required this.duration
  });

  // Sorter Function
  final Function() onSortBest;
  final Function() onSortCheapest;
  final Function() onSortTransits;
  final Function() onSortDiscount;
  final Function() onSortPlaneName;
  final Function() onSortDepart;
  final Function() onSortArrival;

  // Filter Function
  // Function
  final Function(RangeValues) onChangePrice;
  final Function(String, Plane) onUpdateAirlines;
  final Function(String, int) onUpdateTransit;
  final Function(double) onChangeDuration;
  // Variables
  final RangeValues priceRange;
  final List<Plane> selectedAirlines;
  final List<int> transits;
  final double duration;

  @override
  State<FilterBottomFloating> createState() => _FilterBottomFloatingState();
}

class _FilterBottomFloatingState extends State<FilterBottomFloating> {
  String _sortByTemp = 'best_value';
  final bool _isDark = Get.isDarkMode;

  @override
  Widget build(BuildContext context) {
    List<ListItem> sortOptions = [
      ListItem(
        value: 'best_value',
        label: 'Best Value',
        text: 'Sort by the best value'
      ),
      ListItem(
        value: 'cheapest',
        label: 'Cheapest',
        text: 'Sort by the cheapest price'
      ),
      ListItem(
        value: 'depart',
        label: 'Depart Time',
        text: 'Sort by the departing time'
      ),
      ListItem(
        value: 'arrival',
        label: 'Arrival Time',
        text: 'Sort by the arriving time'
      ),
      ListItem(
        value: 'transit',
        label: 'Transits',
        text: 'Sort by the shortest transits'
      ),
      ListItem(
        value: 'discount',
        label: 'Discount',
        text: 'Sort by the biggest dicount'
      ),
      ListItem(
        value: 'name',
        label: 'Airline Name',
        text: 'Sort by the airline name'
      ),
    ];

    void showOrderSheet(BuildContext context) {
      openRadioPicker(
        context: context,
        options: sortOptions,
        title: 'Sort By',
        initialValue: _sortByTemp,
        onSelected: (value) {
          if (value !=null) {
            String result = sortOptions.firstWhere((e) => e.value == value).value;
            setState(() {
              _sortByTemp = result;
            });
            switch(result) {
              case 'best_value':
                widget.onSortBest();
                break;
              case 'cheapest':
                widget.onSortCheapest();
                break;
              case 'depart':
                widget.onSortDepart();
                break;
              case 'arrival':
                widget.onSortArrival();
                break;
              case 'transit':
                widget.onSortTransits();
                break;
              case 'discount':
                widget.onSortDiscount();
                break;
              case 'name':
                widget.onSortPlaneName();
                break;
              default:
                break;
            }
          }
        }
      );
    }

    void showFilterSheet() async {
      Get.bottomSheet(
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
          return Wrap(children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: FilterFlightForm(
                priceRange: widget.priceRange,
                selectedAirlines: widget.selectedAirlines,
                transits: widget.transits,
                duration: widget.duration,
                onChangePrice: (RangeValues range) {
                  setState(() {
                    widget.onChangePrice(range);
                  });
                },
                onUpdateAirlines: (String type, Plane item) {
                  setState(() {
                    widget.onUpdateAirlines(type, item);
                  });
                },
                onUpdateTransit: (String type, int item) {
                  setState(() {
                    widget.onUpdateTransit(type, item);
                  });
                },
                onChangeDuration: (double val) {
                  setState(() {
                    widget.onChangeDuration(val);
                  });
                },
              )
            )
          ]);
        }),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        backgroundColor: TravelloTheme.paperLight,
      );
    }

    return Container(
      color: Colors.transparent,
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        height: 100,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Container(
              height: 100,
              width: 240,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMainContainer,
                borderRadius: ThemeRadius.big,
                boxShadow: [ThemeShade.shadeSoft(context)]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      showOrderSheet(context);
                    },
                    child: Row(children: [
                      Icon(Icons.import_export, color: _isDark ? TravelloTheme.tertiaryMain : TravelloTheme.primaryMain),
                      const SizedBox(width: 4),
                      Text('Order', style: TravelloTheme.subtitle2.copyWith(color: colorScheme(context).onSurface))
                    ],)
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: VerticalDivider(color: colorScheme(context).outlineVariant),                      
                  ),
                  TextButton(
                    onPressed: () {
                      showFilterSheet();
                    },
                    child: Row(children: [
                      Icon(Icons.tune, color: _isDark ? TravelloTheme.tertiaryMain : TravelloTheme.primaryMain),
                      const SizedBox(width: 4),
                      Text('Filter', style: TravelloTheme.subtitle2.copyWith(color: colorScheme(context).onSurface))
                    ],)
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}