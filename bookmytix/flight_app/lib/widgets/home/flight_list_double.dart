import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flight_app/widgets/cards/flight_portrait_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightListDouble extends StatefulWidget {
  const FlightListDouble({super.key});

  @override
  State<FlightListDouble> createState() => _FlightListDoubleState();
}

class _FlightListDoubleState extends State<FlightListDouble> {
  int _selected = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    setState(() {
      _showLeftArrow = _scrollController.offset > 0;
      _showRightArrow =
          _scrollController.offset < _scrollController.position.maxScrollExtent;
    });
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 250,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 250,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Map cities to their regions
  final Map<String, List<String>> regionCities = {
    'Punjab': [
      'Lahore',
      'Rawalpindi',
      'Faisalabad',
      'Multan',
      'Sialkot',
      'Gujranwala',
      'Bahawalpur',
      'Sargodha',
      'Sahiwal',
      'Dera Ghazi Khan',
      'Mianwali'
    ],
    'Sindh': [
      'Karachi',
      'Hyderabad',
      'Sukkur',
      'Larkana',
      'Nawabshah',
      'Jacobabad'
    ],
    'KPK': [
      'Peshawar',
      'Abbottabad',
      'Mardan',
      'Swat',
      'Chitral',
      'Bannu',
      'D.I. Khan',
      'Murree'
    ],
    'Balochistan': [
      'Quetta',
      'Gwadar',
      'Turbat',
      'Zhob',
      'Khuzdar',
      'Pasni',
      'Panjgur',
      'Dalbandin',
      'Chaman'
    ],
    'Gilgit-Baltistan': ['Gilgit', 'Skardu', 'Hunza']
  };

  List<Trip> _getFilteredFlights() {
    final List<String> tags = [
      'Punjab',
      'Sindh',
      'KPK',
      'Balochistan',
      'Gilgit-Baltistan'
    ];

    final selectedRegion = tags[_selected];
    final regionCitiesNames = regionCities[selectedRegion] ?? [];

    // Filter trips where the destination (to) city is in the selected region
    final filtered = tripList.where((trip) {
      return regionCitiesNames.contains(trip.to.name) ||
          regionCitiesNames.contains(trip.from.name);
    }).toList();

    // If we have filtered results, return them, otherwise show all
    return filtered.isNotEmpty ? filtered : tripList.sublist(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    final List<String> tags = [
      'Punjab',
      'Sindh',
      'KPK',
      'Balochistan',
      'Gilgit-Baltistan'
    ];

    final displayFlights = _getFilteredFlights();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? spacingUnit(8) : 16),
        child: TitleAction(
            title: 'Top Destinations',
            textAction: 'Find More',
            onTap: () {
              Get.toNamed(AppLink.flightList);
            }),
      ),
      const SizedBox(height: 16),

      /// TAGS
      Padding(
        padding:
            EdgeInsets.only(left: isDesktop ? spacingUnit(8) : 16),
        child: SizedBox(
          height: 25,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TagButton(
                    text: tags[index],
                    size: BtnSize.small,
                    selected: index == _selected,
                    onPressed: () {
                      setState(() {
                        _selected = index;
                      });
                    },
                  ));
            },
          ),
        ),
      ),
      const SizedBox(height: 16),

      /// FLIGHT ITEMS - Single Row Horizontal Scroller with Arrows
      SizedBox(
        height: 145,
        child: displayFlights.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No flights available for ${tags[_selected]}',
                    style:
                        const TextStyle(fontSize: 16, color: Color(0xFFB3B3B3)),
                  ),
                ),
              )
            : Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        displayFlights.length > 10 ? 10 : displayFlights.length,
                    itemBuilder: (context, index) {
                      Trip item = displayFlights[index];

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 220,
                          child: GestureDetector(
                            onTap: () {
                              Get.toNamed(
                                AppLink.flightSearchHome,
                                arguments: {
                                  'toCode': item.to.code,
                                  'toCity': item.to.name,
                                },
                              );
                            },
                            child: FlightPortraitCard(
                              from: item.from.name,
                              to: item.to.name,
                              label: item.label,
                              date: DateFormat('dd MMM yyyy')
                                  .format(item.arrival),
                              price: item.price,
                              plane: item.plane,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // LEFT ARROW BUTTON
                  if (_showLeftArrow)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme(context)
                                .surface
                                .withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _scrollLeft,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: TravelloTheme.primaryMain,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // RIGHT ARROW BUTTON
                  if (_showRightArrow)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme(context)
                                .surface
                                .withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _scrollRight,
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: TravelloTheme.primaryMain,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      )
    ]);
  }
}
