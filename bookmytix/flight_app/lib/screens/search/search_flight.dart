import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/tag_button.dart';
import 'package:flight_app/widgets/home/flight_list_double.dart';
import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flight_app/widgets/search_filters/search_flight_form.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class SearchFlight extends StatefulWidget {
  const SearchFlight({super.key});

  @override
  State<SearchFlight> createState() => _SearchFlightState();
}

class _SearchFlightState extends State<SearchFlight> {
  bool _roundTrip = false;
  final bool isDark = Get.isDarkMode;

  void _setRoundTrip(bool value) {
    setState(() {
      _roundTrip = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          /// SLIVER APPBAR AND BANNER
          SliverAppBar(
            expandedHeight: 200.0,
            collapsedHeight: 80,
            floating: false,
            pinned: true,
            leadingWidth: 60,
            toolbarHeight: 60,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
              onPressed: () {
                Get.back();
              },
            ),
            title: const Text('Search Flights', style: ThemeText.subtitle),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset(
                ImgApi.searchBanner,
                fit: BoxFit.cover,
                color:
                    isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white,
                colorBlendMode: BlendMode.darken,
              ),
            ),

            /// PROMOTION INFO
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme(context).primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    /// INFO
                    GestureDetector(
                      onTap: () {
                        Get.toNamed(AppLink.promo);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: spacingUnit(2),
                            vertical: spacingUnit(1)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  colorScheme(context).primaryContainer,
                              radius: 12,
                              child: Icon(
                                CupertinoIcons.tags_solid,
                                color: colorScheme(context).onPrimaryContainer,
                                size: 12,
                              ),
                            ),
                            SizedBox(width: spacingUnit(1)),
                            Expanded(
                              child: Text(
                                  'Find exciting deals and unlock incredible travel experiences. Check the latest promos now and let the journey begin!',
                                  textAlign: TextAlign.start,
                                  style: ThemeText.caption
                                      .copyWith(color: Colors.white)),
                            ),
                            SizedBox(width: spacingUnit(1)),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.white, size: 12),
                            SizedBox(width: spacingUnit(1)),
                          ],
                        ),
                      ),
                    ),

                    /// DECORATION
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme(context).surfaceContainerLowest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  colorScheme(context).surfaceContainerLowest,
                              offset: const Offset(0, 2),
                              blurRadius: 0,
                              spreadRadius: 0)
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          /// CONTENT
          SliverToBoxAdapter(
              child: Column(
            children: [
              /// SEARCH FORM
              Container(
                constraints: BoxConstraints(maxWidth: ThemeSize.sm),
                padding: EdgeInsets.symmetric(
                    horizontal: spacingUnit(2), vertical: spacingUnit(1)),
                child: Row(children: [
                  TagButton(
                      text: 'One Way',
                      selected: !_roundTrip,
                      onPressed: () {
                        _setRoundTrip(false);
                      }),
                  SizedBox(width: spacingUnit(1)),
                  TagButton(
                      text: 'Round Trip',
                      selected: _roundTrip,
                      onPressed: () {
                        _setRoundTrip(true);
                      }),
                ]),
              ),
              ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: ThemeSize.sm),
                  child: SearchFlightForm(roundTrip: _roundTrip)),
              const VSpace(),
              const PackageListSlider(),
              const VSpace(),
              const FlightListDouble(),
              const VSpaceBig(),
              const SizedBox(height: 80),
            ],
          ))
        ],
      ),
    );
  }
}
