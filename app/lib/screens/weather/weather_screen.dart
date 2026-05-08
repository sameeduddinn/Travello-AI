import 'package:flight_app/controllers/city_controller.dart';
import 'package:flight_app/models/weather.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

// ---------------------------------------------------------------------------
// Helper: map backend icon string → Flutter IconData
// ---------------------------------------------------------------------------
IconData _iconFromName(String name) {
  switch (name) {
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'wb_cloudy':
      return Icons.wb_cloudy;
    case 'cloud':
      return Icons.cloud;
    case 'water_drop':
      return Icons.water_drop;
    case 'thunderstorm':
      return Icons.thunderstorm;
    case 'ac_unit':
      return Icons.ac_unit;
    case 'foggy':
      return Icons.foggy;
    case 'grain':
      return Icons.grain;
    case 'air':
      return Icons.air;
    case 'local_fire_department':
      return Icons.local_fire_department;
    default:
      return Icons.wb_sunny;
  }
}

// ---------------------------------------------------------------------------
// Convert backend weather map → WeatherData model
// ---------------------------------------------------------------------------
WeatherData _fromApi(Map<String, dynamic> map) {
  return WeatherData(
    city: map['city']?.toString() ?? '',
    temperature: (map['temperature'] as num?)?.toDouble() ?? 27.0,
    feelsLike: (map['feels_like'] as num?)?.toDouble(),
    condition: map['condition']?.toString() ?? 'Pleasant',
    icon: _iconFromName(map['icon']?.toString() ?? 'wb_sunny'),
    humidity: (map['humidity'] as num?)?.toInt() ?? 55,
    windSpeed: (map['wind_speed'] as num?)?.toDouble() ?? 10.0,
    travelWarning: map['travel_warning'] == true,
    warningMessage: map['warning_message']?.toString() ?? '',
    source: map['source']?.toString() ?? 'live',
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCity = 'Karachi';
  WeatherData _currentWeather = PakistanWeatherData.getWeatherForCity('Karachi');
  List<WeatherData> _allCities = PakistanWeatherData.getAllCitiesWeather();

  // Restore city from global selection before first build
  void _syncCityFromController() {
    final saved = CityController.to.selectedCity.value;
    if (PakistanWeatherData.getCities().contains(saved)) {
      _selectedCity = saved;
      _currentWeather = PakistanWeatherData.getWeatherForCity(saved);
    }
  }
  bool _loadingCurrent = false;
  bool _loadingAll = false;
  bool _allCitiesLoaded = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _syncCityFromController();

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

    // Load only the selected city on open — all-cities is lazy
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentCity());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentCity() async {
    setState(() => _loadingCurrent = true);
    final data = await ApiClient.getWeather(_selectedCity);
    if (!mounted) return;
    if (data != null) {
      final weather = _fromApi(data);
      setState(() {
        _currentWeather = weather;
        final idx = _allCities.indexWhere((c) => c.city == _selectedCity);
        if (idx != -1) _allCities[idx] = weather;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load live weather. Showing estimated data.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    setState(() => _loadingCurrent = false);
  }

  Future<void> _loadAllCities() async {
    setState(() => _loadingAll = true);
    final data = await ApiClient.getAllCitiesWeather();
    if (!mounted) return;
    if (data != null && data.isNotEmpty) {
      final cities = data.map(_fromApi).toList();
      setState(() {
        _allCities = cities;
        _allCitiesLoaded = true;
        final match = cities.where((c) => c.city == _selectedCity);
        if (match.isNotEmpty) _currentWeather = match.first;
        _loadingAll = false;
      });
    } else {
      setState(() => _loadingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load live city data. Showing estimated data.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _changeCity(String city) async {
    CityController.to.setCity(city);
    setState(() {
      _selectedCity = city;
      _currentWeather = PakistanWeatherData.getWeatherForCity(city);
    });
    await _loadCurrentCity();
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _allCities.where((w) => w.travelWarning).toList();

    final bool isRefreshing = _loadingAll || _loadingCurrent;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          RefreshIndicator(
        color: const Color(0xFFD4AF37),
        onRefresh: _loadCurrentCity,
        child: CustomScrollView(
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
                                        borderRadius:
                                            BorderRadius.circular(14),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCity),
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
                      child: _loadingCurrent
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            )
                          : LayoutBuilder(
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
                                      style: TravelloTheme.title
                                          .copyWith(fontSize: 16),
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
                                          value:
                                              '${_currentWeather.humidity}%',
                                        ),
                                        _WeatherDetail(
                                          icon: Icons.air,
                                          label: 'Wind',
                                          value:
                                              '${_currentWeather.windSpeed.toStringAsFixed(0)} km/h',
                                        ),
                                        if (_currentWeather.feelsLike != null)
                                          _WeatherDetail(
                                            icon: Icons.thermostat,
                                            label: 'Feels Like',
                                            value: '${_currentWeather.feelsLike!.toStringAsFixed(0)}°C',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _LiveBadge(source: _currentWeather.source),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ),

                // Travel Warning
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

                // Active Weather Alerts
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

                // All Cities
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'All Cities',
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      const Spacer(),
                      if (_loadingAll)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4AF37),
                          ),
                        )
                      else if (!_allCitiesLoaded)
                        TextButton.icon(
                          onPressed: _loadAllCities,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 15),
                          label: const Text('Load live',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 13, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text('Live',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                ),
                ..._allCities.map((weather) {
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
    ),
    if (isRefreshing)
      Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFFD4AF37),
                  strokeWidth: 3,
                ),
                SizedBox(height: 14),
                Text(
                  'Loading weather...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
}
}

class _LiveBadge extends StatelessWidget {
  final String source;
  const _LiveBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isLive = source == 'google-weather' || source == 'open-meteo';
    final label = source == 'google-weather'
        ? 'Live'
        : source == 'open-meteo'
            ? 'Live'
            : 'Estimated';
    final color = isLive ? Colors.green.shade600 : Colors.grey.shade500;
    final bgColor = isLive ? Colors.green.shade50 : Colors.grey.shade100;
    final icon = isLive ? Icons.wifi_rounded : Icons.wifi_off_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: Colors.red.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Icon(weather.icon, size: 24, color: Colors.red.shade700),
          ),
          title: Text(
            weather.city,
            style: TravelloTheme.subtitle.copyWith(color: Colors.red.shade900),
          ),
          subtitle: Text(
            weather.warningMessage,
            style:
                TravelloTheme.caption.copyWith(color: Colors.red.shade800),
          ),
          trailing: Icon(Icons.warning, color: Colors.red.shade700),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              color: isSelected
                  ? colorScheme(context).onPrimaryContainer
                  : null,
            ),
          ),
          subtitle: Text(
            weather.condition,
            style: TravelloTheme.caption.copyWith(
              color: isSelected
                  ? colorScheme(context).onPrimaryContainer
                  : null,
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
