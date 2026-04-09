import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/widgets/cards/flight_portrait_card.dart';
import 'package:flight_app/widgets/title/title_action.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightListSlider extends StatefulWidget {
  const FlightListSlider({super.key});

  @override
  State<FlightListSlider> createState() => _FlightListSliderState();
}

class _FlightListSliderState extends State<FlightListSlider> {
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

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 220;
    const double cardHeight = 160;
    final topFlightList = tripList.sublist(0, 12);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TitleAction(
            title: 'Top Destinations',
            textAction: 'Find More',
            onTap: () {
              Get.toNamed('/flight-list');
            }),
      ),
      const SizedBox(height: 16),

      /// FLIGHT ITEMS
      SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 10,
                itemBuilder: ((context, index) {
                  Trip item = topFlightList[index];

                  return SizedBox(
                      width: cardWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            Get.toNamed(AppLink.flightSearchHome, arguments: {
                              'toCode': item.to.code,
                              'toCity': item.to.name,
                            });
                          },
                          child: FlightPortraitCard(
                              from: item.from.name,
                              to: item.to.name,
                              label: item.label,
                              date: DateFormat('dd MMM yyyy')
                                  .format(item.arrival),
                              price: item.price,
                              plane: item.plane),
                        ),
                      ));
                }),
              ),
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
                      color:
                          TravelloTheme.paperLight.withValues(alpha: 0.95),
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
                      color:
                          TravelloTheme.paperLight.withValues(alpha: 0.95),
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
