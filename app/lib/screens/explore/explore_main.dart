import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flutter/material.dart';
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
          // ── Banner + action header ──────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                BannerExplore(),
                Positioned(child: SizedBox(child: HeaderExplore())),
              ],
            ),
          ),

          // ── Sticky category filter (native — fixes scrollbar sync) ──────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterDelegate(
              selected: _selectedCategory,
              onSelect: (cat) => setState(() => _selectedCategory = cat),
            ),
          ),

          // ── Destination cards ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: ExploreDestinationsSection(
              selectedCategory: _selectedCategory,
            ),
          ),

          // ── Featured flight packages ────────────────────────────────────────
          const SliverToBoxAdapter(child: PackageListSlider()),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Pinned category-filter header delegate (no third-party package needed)
class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final String selected;
  final void Function(String) onSelect;

  const _FilterDelegate({required this.selected, required this.onSelect});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: TravelloTheme.paperLightContainerLowest,
      child: ExploreCategoryFilter(selected: selected, onSelect: onSelect),
    );
  }

  @override
  bool shouldRebuild(_FilterDelegate old) => old.selected != selected;
}
