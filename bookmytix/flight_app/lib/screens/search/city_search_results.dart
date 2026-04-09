import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/trip.dart';
import 'package:flight_app/widgets/cards/flight_portrait_card.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class CitySearchResults extends StatefulWidget {
  const CitySearchResults({super.key});

  @override
  State<CitySearchResults> createState() => _CitySearchResultsState();
}

class _CitySearchResultsState extends State<CitySearchResults>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String cityName = '';
  City? selectedCity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Get city from arguments
    final args = Get.arguments as Map<String, dynamic>?;
    cityName = args?['cityName'] ?? '';

    // Find city in cityList
    try {
      selectedCity = cityList.firstWhere(
          (city) => city.name.toLowerCase() == cityName.toLowerCase());
    } catch (e) {
      selectedCity = null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Trip> _getDepartureFlights() {
    if (selectedCity == null) return [];
    return tripList
        .where((trip) => trip.from.name.toLowerCase() == cityName.toLowerCase())
        .take(10)
        .toList();
  }

  List<Trip> _getArrivalFlights() {
    if (selectedCity == null) return [];
    return tripList
        .where((trip) => trip.to.name.toLowerCase() == cityName.toLowerCase())
        .take(10)
        .toList();
  }

  List<Trip> _getPopularRoutes() {
    if (selectedCity == null) return [];
    return tripList
        .where((trip) =>
            trip.from.name.toLowerCase() == cityName.toLowerCase() ||
            trip.to.name.toLowerCase() == cityName.toLowerCase())
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedCity == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Search Results'),
        ),
        body: const Center(
          child: Text('City not found'),
        ),
      );
    }

    final departureFlights = _getDepartureFlights();
    final arrivalFlights = _getArrivalFlights();
    final popularRoutes = _getPopularRoutes();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with City Info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                cityName,
                style: TravelloTheme.title2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    selectedCity!.photos[0],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: TravelloTheme.primaryMain,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),

          // Quick Stats
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TravelloTheme.paperLightContainerLow,
                borderRadius: ThemeRadius.medium,
                boxShadow: [ThemeShade.shadeSoft(context)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    Icons.flight_takeoff,
                    '${departureFlights.length}',
                    'Departures',
                  ),
                  _buildStatItem(
                    context,
                    Icons.flight_land,
                    '${arrivalFlights.length}',
                    'Arrivals',
                  ),
                  _buildStatItem(
                    context,
                    Icons.route,
                    '${popularRoutes.length}',
                    'Routes',
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: TravelloTheme.primaryMain,
                unselectedLabelColor: colorScheme(context).onSurfaceVariant,
                indicatorColor: TravelloTheme.primaryMain,
                tabs: const [
                  Tab(text: 'Departures'),
                  Tab(text: 'Arrivals'),
                  Tab(text: 'Popular Routes'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFlightList(departureFlights, 'No departures found'),
                _buildFlightList(arrivalFlights, 'No arrivals found'),
                _buildFlightList(popularRoutes, 'No routes found'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: TravelloTheme.primaryMain, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TravelloTheme.title.copyWith(
            fontWeight: FontWeight.bold,
            color: TravelloTheme.primaryMain,
          ),
        ),
        Text(
          label,
          style: TravelloTheme.caption.copyWith(
            color: colorScheme(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFlightList(List<Trip> flights, String emptyMessage) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_outlined,
              size: 64,
              color: colorScheme(context).outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TravelloTheme.subtitle.copyWith(
                color: colorScheme(context).onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final trip = flights[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FlightPortraitCard(
            from: trip.from.code,
            to: trip.to.code,
            date: '${trip.depart.day}/${trip.depart.month}/${trip.depart.year}',
            price: trip.price,
            plane: trip.plane,
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: TravelloTheme.paperLight,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
