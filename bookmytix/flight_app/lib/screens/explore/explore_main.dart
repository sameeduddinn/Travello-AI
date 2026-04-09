import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flight_app/widgets/home/promo_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flight_app/widgets/explore/banner.dart';
import 'package:flight_app/widgets/explore/header.dart';
import 'package:flight_app/widgets/explore/explore_category_filter.dart';
import 'package:flight_app/widgets/explore/explore_destinations_section.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ExploreMain extends StatefulWidget {
  const ExploreMain({super.key});

  @override
  State<ExploreMain> createState() => _ExploreMainState();
}

class _ExploreMainState extends State<ExploreMain> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
            child: Stack(
          alignment: Alignment.topCenter,
          children: [
            /// BANNER ILLUSTRATION
            BannerExplore(),

            /// HEADER
            Positioned(child: SizedBox(child: HeaderExplore())),
          ],
        )),

        /// STICKY SEARCH + CATEGORY BAR
        SliverStickyHeader.builder(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// CATEGORY FILTER CHIPS
                  Container(
                    color: TravelloTheme.paperLightContainerLowest,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExploreCategoryFilter(
                      selected: _selectedCategory,
                      onSelect: (cat) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  ),
                ],
              );
            },

            /// CONTENT BELOW STICKY HEADER
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              const SizedBox(height: 8),

              /// ── DESTINATION GRID (filterable, Pakistan only) ──
              ExploreDestinationsSection(
                selectedCategory: _selectedCategory,
              ),

              /// ── FEATURED PACKAGES ──
              const PackageListSlider(),
              const SizedBox(height: 24),

              /// ── PROMOTIONS ──
              const PromoSlider(),
              const SizedBox(height: 24),
            ]))),
      ],
    ));
  }
}
