import 'package:flight_app/models/weather.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCity = 'Karachi';
  late WeatherData _currentWeather;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentWeather = PakistanWeatherData.getWeatherForCity(_selectedCity);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _changeCity(String city) {
    setState(() {
      _selectedCity = city;
      _currentWeather = PakistanWeatherData.getWeatherForCity(city);
    });
  }

  @override
  Widget build(BuildContext context) {
    final warnings = PakistanWeatherData.getCitiesWithWarnings();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Animated Golden Header ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFFD4AF37), size: 18),
                onPressed: () => Get.back(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFD4AF37),
                      Color(0xFFDAB853),
                      Color(0xFFE8C76A),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: constraints.maxHeight > 120 ? 24 : 16,
                          bottom: 8,
                        ),
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.wb_sunny_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Weather Updates',
                                            style: TextStyle(
                                              fontSize: R.sp(context, 28),
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.8,
                                              height: 1.1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Live weather across Pakistan',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              letterSpacing: 0.2,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Body content ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City Selector
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFFD4AF37)),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_rounded,
                          color: Color(0xFFD4AF37)),
                      labelText: 'Select City',
                      labelStyle: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFD4AF37), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFD4AF37), width: 2),
                      ),
                    ),
                    items: PakistanWeatherData.getCities().map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city,
                            style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) _changeCity(value);
                    },
                  ),
                ),

                // Current Weather Card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxWidth < 360;
                          return Column(
                            children: [
                              Icon(
                                _currentWeather.icon,
                                size: isSmall ? 56.0 : 72.0,
                                color: TravelloTheme.primaryMain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${_currentWeather.temperature.toStringAsFixed(0)}°C',
                                style: TextStyle(
                                  fontSize: isSmall ? 36.0 : 48.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentWeather.condition,
                                style:
                                    TravelloTheme.title.copyWith(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _WeatherDetail(
                                    icon: Icons.water_drop,
                                    label: 'Humidity',
                                    value: '${_currentWeather.humidity}%',
                                  ),
                                  _WeatherDetail(
                                    icon: Icons.air,
                                    label: 'Wind',
                                    value: '${_currentWeather.windSpeed} km/h',
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Travel Warning (if applicable)
                if (_currentWeather.travelWarning)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade800,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Travel Warning',
                                    style: TravelloTheme.subtitle.copyWith(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentWeather.warningMessage,
                                    style: TravelloTheme.caption.copyWith(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Weather Warnings Section
                if (warnings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Active Weather Alerts',
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                  ...warnings.map((weather) => _WarningCard(weather: weather)),
                ],

                // All Cities Weather
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Cities',
                      style: TravelloTheme.title.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                ...PakistanWeatherData.getAllCitiesWeather().map((weather) {
                  return _CityWeatherTile(
                    weather: weather,
                    isSelected: weather.city == _selectedCity,
                    onTap: () => _changeCity(weather.city),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: TravelloTheme.primaryMain),
        const SizedBox(height: 4),
        Text(label, style: TravelloTheme.caption),
        Text(value, style: TravelloTheme.subtitle),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final WeatherData weather;

  const _WarningCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Card(
        color: Colors.red.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Icon(
              weather.icon,
              size: 24,
              color: Colors.red.shade700,
            ),
          ),
          title: Text(
            weather.city,
            style: TravelloTheme.subtitle.copyWith(
              color: Colors.red.shade900,
            ),
          ),
          subtitle: Text(
            weather.warningMessage,
            style: TravelloTheme.caption.copyWith(
              color: Colors.red.shade800,
            ),
          ),
          trailing: Icon(
            Icons.warning,
            color: Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}

class _CityWeatherTile extends StatelessWidget {
  final WeatherData weather;
  final bool isSelected;
  final VoidCallback onTap;

  const _CityWeatherTile({
    required this.weather,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Card(
        color: isSelected ? TravelloTheme.primaryMainContainer : null,
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            weather.icon,
            size: 32,
            color: isSelected
                ? colorScheme(context).onPrimaryContainer
                : TravelloTheme.primaryMain,
          ),
          title: Text(
            weather.city,
            style: TravelloTheme.subtitle.copyWith(
              color:
                  isSelected ? colorScheme(context).onPrimaryContainer : null,
            ),
          ),
          subtitle: Text(
            weather.condition,
            style: TravelloTheme.caption.copyWith(
              color:
                  isSelected ? colorScheme(context).onPrimaryContainer : null,
            ),
          ),
          trailing: Text(
            '${weather.temperature.toStringAsFixed(0)}°C',
            style: TravelloTheme.title.copyWith(
              fontSize: 16,
              color: isSelected
                  ? colorScheme(context).onPrimaryContainer
                  : TravelloTheme.primaryMain,
            ),
          ),
        ),
      ),
    );
  }
}
