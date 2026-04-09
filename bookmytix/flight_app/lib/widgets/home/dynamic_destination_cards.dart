import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:flight_app/models/destination.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// Dynamic destination cards that change based on travel mode (Flight/Train/Hotel)
class DynamicDestinationCards extends StatefulWidget {
  final List<Destination> destinations;
  final String travelMode; // 'flight', 'train', 'hotel'

  const DynamicDestinationCards({
    super.key,
    required this.destinations,
    required this.travelMode,
  });

  @override
  State<DynamicDestinationCards> createState() =>
      _DynamicDestinationCardsState();
}

class _DynamicDestinationCardsState extends State<DynamicDestinationCards> {
  final ScrollController _scrollController = ScrollController();
  String _userOriginCityCode = 'KHI'; // Default fallback
  String _userOriginCityName = 'Karachi';

  @override
  void initState() {
    super.initState();
    _loadUserOriginCity();
  }

  /// Fetch user's selected origin city for dynamic travel times
  Future<void> _loadUserOriginCity() async {
    final cityData = await LocationPreferenceService.getOriginCity();
    if (mounted) {
      setState(() {
        _userOriginCityCode = cityData['cityCode']!;
        _userOriginCityName = cityData['cityName']!;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    final cardWidth = MediaQuery.of(context).size.width < 400 ? 180.0 : 220.0;
    _scrollController.animateTo(
      _scrollController.offset - cardWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    final cardWidth = MediaQuery.of(context).size.width < 400 ? 180.0 : 220.0;
    _scrollController.animateTo(
      _scrollController.offset + cardWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final showArrows = screenWidth > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? spacingUnit(8) : 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSectionTitle(),
                    style: TravelloTheme.title2.copyWith(
                      color: colorScheme(context).onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSectionSubtitle(),
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          colorScheme(context).onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (isDesktop)
                TextButton.icon(
                  onPressed: () {
                    // Navigate to view all destinations
                    _navigateToViewAll();
                  },
                  icon: const Icon(CupertinoIcons.arrow_right_circle_fill,
                      size: 18),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal scrollable destination cards with arrow controls
        SizedBox(
          width: double.infinity,
          height: screenWidth < 400 ? 220 : 260,
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? spacingUnit(8) : 16,
                    ),
                    itemCount: widget.destinations.length,
                    itemBuilder: (context, index) {
                      final destination = widget.destinations[index];
                      return _buildDestinationCard(
                          context, destination, isDesktop);
                    },
                  ),
                ),
              ),
              if (showArrows) ...[
                Positioned(
                  left: 16,
                  top: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          TravelloTheme.paperLight.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
                Positioned(
                  right: 16,
                  top: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          TravelloTheme.paperLight.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationCard(
    BuildContext context,
    Destination destination,
    bool isDesktop,
  ) {
    return GestureDetector(
      onTap: () => _onDestinationTap(destination),
      child: Container(
        width: isDesktop
            ? 260
            : (MediaQuery.of(context).size.width < 400 ? 180 : 220),
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: destination.cardColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  destination.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to gradient if image fails
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            destination.cardColor,
                            destination.cardColor.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            destination.cardColor,
                            destination.cardColor.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Gradient overlay for readability
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section - Icon and badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getModeIcon(),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (destination.popularityRank <= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.star_fill,
                                color: Color(0xFFFFB800),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Top ${destination.popularityRank}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Bottom section - Destination info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.clock,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                destination.getFormattedTravelTime(
                                    _userOriginCityCode, _userOriginCityName),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionTitle() {
    switch (widget.travelMode) {
      case 'flight':
        return 'Top Flight Destinations';
      case 'train':
        return 'Popular Train Routes';
      case 'hotel':
        return 'Top Tourist Destinations';
      default:
        return 'Popular Destinations';
    }
  }

  String _getSectionSubtitle() {
    switch (widget.travelMode) {
      case 'flight':
        return 'Most searched and booked flight routes in Pakistan';
      case 'train':
        return 'ML-1 main line and popular railway journeys';
      case 'hotel':
        return 'Highest rated valleys and tourist spots';
      default:
        return 'Explore amazing places';
    }
  }

  IconData _getModeIcon() {
    switch (widget.travelMode) {
      case 'flight':
        return CupertinoIcons.airplane;
      case 'train':
        return CupertinoIcons.train_style_one;
      case 'hotel':
        return CupertinoIcons.building_2_fill;
      default:
        return CupertinoIcons.map_pin;
    }
  }

  void _onDestinationTap(Destination destination) {
    // Navigate based on travel mode
    switch (widget.travelMode) {
      case 'flight':
        Get.toNamed('/flight-search-home', arguments: {
          'toCode': destination.code,
          'toCity': destination.name,
        });
        break;
      case 'train':
        Get.toNamed('/train-search-home', arguments: {
          'toCode': destination.code,
          'toCity': destination.name,
        });
        break;
      case 'hotel':
        Get.toNamed('/hotel-search', arguments: {
          'cityName': destination.name,
        });
        break;
    }
  }

  void _navigateToViewAll() {
    switch (widget.travelMode) {
      case 'flight':
        Get.toNamed('/flight-list');
        break;
      case 'train':
        Get.toNamed('/train-results');
        break;
      case 'hotel':
        Get.toNamed('/hotel-search');
        break;
    }
  }
}
