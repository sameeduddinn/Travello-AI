import 'package:flight_app/controllers/city_controller.dart';
import 'package:flight_app/models/hospital.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HealthcareScreen extends StatefulWidget {
  const HealthcareScreen({super.key});

  @override
  State<HealthcareScreen> createState() => _HealthcareScreenState();
}

class _HealthcareScreenState extends State<HealthcareScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, List<double>> _cityCoords = {
    // Major cities
    'Karachi':        [24.8607, 67.0011],
    'Lahore':         [31.5204, 74.3587],
    'Islamabad':      [33.6844, 73.0479],
    'Rawalpindi':     [33.5651, 73.0169],
    'Multan':         [30.1575, 71.5249],
    'Faisalabad':     [31.4504, 73.1350],
    'Peshawar':       [34.0151, 71.5249],
    'Quetta':         [30.1798, 66.9750],
    'Sialkot':        [32.4945, 74.5229],
    'Gujranwala':     [32.1877, 74.1945],
    'Bahawalpur':     [29.3956, 71.6836],
    'Hyderabad':      [25.3960, 68.3578],
    'Sukkur':         [27.7052, 68.8574],
    'Larkana':        [27.5580, 68.2150],
    'Dera Ghazi Khan':[30.0571, 70.6350],
    'Gwadar':         [25.1264, 62.3225],
    'Mirpur':         [33.1475, 73.7511],
    // Northern Pakistan & tourism
    'Skardu':         [35.2971, 75.6338],
    'Gilgit':         [35.9208, 74.3149],
    'Hunza':          [36.3167, 74.6500],
    'Naran':          [34.9030, 73.6540],
    'Chitral':        [35.8518, 71.7864],
    'Swat':           [34.7462, 72.3578],
    'Abbottabad':     [34.1463, 73.2117],
    'Mansehra':       [34.3300, 73.2000],
    'Nathiagali':     [34.0741, 73.3778],
    'Murree':         [33.9072, 73.3943],
    'Muzaffarabad':   [34.3700, 73.4711],
    'Rawalakot':      [33.8575, 73.7614],
    'Ziarat':         [30.3810, 67.7285],
    'Fairy Meadows':  [35.3753, 74.5958],
    'Kalash Valley':  [35.7000, 71.6000],
  };

  String _selectedCity = 'Karachi'; // overridden in initState from CityController
  List<Hospital> _hospitals = [];
  bool _isLoadingHospitals = false;
  final MapController _mapController = MapController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Restore last city selected anywhere in the app
    final saved = CityController.to.selectedCity.value;
    if (_cityCoords.containsKey(saved)) _selectedCity = saved;
    _loadHospitals();

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

  Future<void> _loadHospitals() async {
    if (!mounted) return;
    setState(() => _isLoadingHospitals = true);
    try {
      final raw = await ApiClient.getNearbyHospitals(city: _selectedCity);
      if (raw.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _hospitals = raw
              .map((m) => Hospital(
                    id: m['place_id']?.toString() ?? m['id']?.toString() ?? '',
                    name: m['name']?.toString() ?? 'Hospital',
                    address: m['address']?.toString() ?? '',
                    city: _selectedCity,
                    phone: m['phone']?.toString() ?? '',
                    type: m['type']?.toString() ?? 'Hospital',
                    hasEmergency:
                        m['has_emergency'] == true || m['is_open'] == true,
                    distance: (m['distance_km'] as num?)?.toDouble() ?? 0.0,
                    lat: (m['lat'] as num?)?.toDouble(),
                    lng: (m['lng'] as num?)?.toDouble(),
                    mapsUrl: m['maps_url']?.toString(),
                    rating: (m['rating'] as num?)?.toDouble(),
                    ratingCount: (m['rating_count'] as num?)?.toInt(),
                  ))
              .toList();
        });
        return;
      }
    } catch (_) {
      // Backend unreachable — fall through to local data
    } finally {
      if (mounted) setState(() => _isLoadingHospitals = false);
    }
    // Fallback: local mock data
    if (!mounted) return;
    setState(() {
      _hospitals = PakistanHospitals.getHospitalsByCity(_selectedCity);
    });
  }

  void _changeCity(String city) {
    CityController.to.setCity(city);
    final coords = _cityCoords[city] ?? _cityCoords['Karachi']!;
    setState(() {
      _selectedCity = city;
      _hospitals = []; // clear stale markers immediately
    });
    Future.microtask(() {
      try {
        _mapController.move(LatLng(coords[0], coords[1]), 12.0);
      } catch (_) {}
    });
    _loadHospitals();
  }

  LatLng _mapCenter() {
    final coords = _cityCoords[_selectedCity] ?? _cityCoords['Karachi']!;
    return LatLng(coords[0], coords[1]);
  }

  /// Opens Google Maps navigation to the hospital.
  /// Falls back to geo: URI, then OSM routing if Maps is unavailable.
  Future<void> _navigateToHospital(Hospital hospital) async {
    if (hospital.lat == null || hospital.lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location coordinates not available')),
        );
      }
      return;
    }
    final lat = hospital.lat!;
    final lng = hospital.lng!;

    // Google Maps directions — opens Maps app on Android/iOS if installed,
    // otherwise falls back to browser.
    final googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(googleMaps)) {
      await launchUrl(googleMaps, mode: LaunchMode.externalApplication);
      return;
    }

    // geo: URI — handled by any installed maps app on Android.
    final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(hospital.name)})');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }

    // Last-resort: OSM routing page in browser.
    final osm = Uri.parse(
      'https://www.openstreetmap.org/directions?from=&to=$lat%2C$lng',
    );
    if (await canLaunchUrl(osm)) {
      await launchUrl(osm, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation')),
      );
    }
  }


  Widget _buildOsmMap() {
    final center = _mapCenter();
    final markers = _hospitals
        .where((h) => h.lat != null && h.lng != null)
        .map(
          (hospital) => Marker(
            width: 36,
            height: 36,
            point: LatLng(hospital.lat!, hospital.lng!),
            child: Tooltip(
              message: hospital.name,
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFD4AF37),
                size: 32,
              ),
            ),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travello.flight_app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyContacts = EmergencyContact.getContacts();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: TravelloTheme.primaryMain,
        onRefresh: _loadHospitals,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                onPressed: () => Navigator.of(context).maybePop(),
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
                                        Icons.local_hospital_rounded,
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
                                          const Text(
                                            'Healthcare Guidance',
                                            style: TextStyle(
                                              fontSize: 28,
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
                                            'Hospitals & emergency contacts',
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
                // Emergency Contacts Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Hotlines',
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...emergencyContacts.map((contact) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.red.shade50,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Icon(
                                contact.icon,
                                color: Colors.red.shade900,
                              ),
                            ),
                            title: Text(
                              contact.service,
                              style: TravelloTheme.subtitle,
                            ),
                            trailing: FilledButton.icon(
                              onPressed: () => _makePhoneCall(contact.number),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                              ),
                              icon: const Icon(Icons.phone, size: 18),
                              label: Text(contact.number),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // City Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Hospitals',
                        style: TravelloTheme.title.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
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
                        items: PakistanHospitals.getCities().map((city) {
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _buildOsmMap(),

                const SizedBox(height: 16),

                // Hospitals List
                if (_isLoadingHospitals)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: TravelloTheme.primaryMain)),
                  )
                else if (_hospitals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_hospital_outlined,
                            size: 64,
                            color: colorScheme(context).outline,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hospitals found',
                            style: TravelloTheme.subtitle,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_hospitals
                        ..sort((a, b) => a.distance.compareTo(b.distance)))
                      .map((hospital) {
                    return _HospitalCard(
                      hospital: hospital,
                      onCall: () => _makePhoneCall(hospital.phone),
                      onNavigate: () => _navigateToHospital(hospital),
                    );
                  }),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  const _HospitalCard({
    required this.hospital,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TravelloTheme.primaryMainContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: colorScheme(context).onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.name,
                          style: TravelloTheme.subtitle,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacingUnit(0.75),
                                vertical: spacingUnit(0.25),
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme(context).tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hospital.type,
                                style: TravelloTheme.caption.copyWith(
                                  color:
                                      colorScheme(context).onTertiaryContainer,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (hospital.hasEmergency) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacingUnit(0.75),
                                  vertical: spacingUnit(0.25),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '24/7 Emergency',
                                  style: TravelloTheme.caption.copyWith(
                                    color: Colors.red.shade900,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hospital.rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 15, color: Colors.amber.shade600),
                    const SizedBox(width: 3),
                    Text(
                      hospital.rating!.toStringAsFixed(1),
                      style: TravelloTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    if (hospital.ratingCount != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        '(${hospital.ratingCount})',
                        style: TravelloTheme.caption.copyWith(
                          color: colorScheme(context).outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: colorScheme(context).outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hospital.address,
                      style: TravelloTheme.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.navigation,
                    size: 16,
                    color: colorScheme(context).outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${hospital.distance.toStringAsFixed(1)} km away',
                    style: TravelloTheme.caption.copyWith(
                      color: TravelloTheme.primaryMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hospital.phone.isNotEmpty ? onCall : null,
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(
                        hospital.phone.isNotEmpty ? hospital.phone : 'No number',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text(
                        'Navigate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
