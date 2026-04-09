import 'package:flight_app/models/airport.dart';
import 'package:flight_app/widgets/cards/airport_card.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AirportListSlider extends StatefulWidget {
  const AirportListSlider({super.key});

  @override
  State<AirportListSlider> createState() => _AirportListSliderState();
}

class _AirportListSliderState extends State<AirportListSlider> {
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
    const double cardHeight = 120;
    bool isDesktop = MediaQuery.of(context).size.width > 600;

    final List<Airport> airports = [
      airportList[0],
      airportList[1],
      airportList[2],
      airportList[3],
      airportList[4],
      airportList[5],
      airportList[6],
      airportList[7],
      airportList[8],
      airportList[9],
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TitleBasic(
          title: 'Top 10 Airports',
          desc: 'Voted by customers from across the world',
        ),
      ),
      const VSpaceShort(),
      SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: airports.length,
              itemBuilder: ((context, index) {
                Airport item = airports[index];
                return Padding(
                    padding: EdgeInsets.only(
                        left: index == 0 ? 16 : 0,
                        right: 8),
                    child: SizedBox(
                      width: 280,
                      height: cardHeight,
                      child: AirportCard(
                          thumb: item.photo,
                          name: item.name,
                          code: item.code,
                          location: item.location),
                    ));
              }),
            ),
            // Left Arrow
            if (isDesktop && _showLeftArrow)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _scrollLeft,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme(context)
                            .surface
                            .withValues(alpha: 0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: TravelloTheme.primaryMain,
                      ),
                    ),
                  ),
                ),
              ),
            // Right Arrow
            if (isDesktop && _showRightArrow)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _scrollRight,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme(context)
                            .surface
                            .withValues(alpha: 0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: TravelloTheme.primaryMain,
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
