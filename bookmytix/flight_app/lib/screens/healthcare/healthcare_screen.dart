import 'package:flight_app/models/hospital.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class HealthcareScreen extends StatefulWidget {
  const HealthcareScreen({super.key});

  @override
  State<HealthcareScreen> createState() => _HealthcareScreenState();
}

class _HealthcareScreenState extends State<HealthcareScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCity = 'Karachi';
  List<Hospital> _hospitals = [];
  bool _isLoadingHospitals = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoadingHospitals = true);
    try {
      final raw = await ApiClient.getNearbyHospitals(city: _selectedCity);
      if (raw.isNotEmpty) {
        setState(() {
          _hospitals = raw
              .map((m) => Hospital(
                    id: m['id']?.toString() ?? '',
                    name: m['name']?.toString() ?? 'Hospital',
                    address: m['address']?.toString() ?? '',
                    city: m['city']?.toString() ?? _selectedCity,
                    phone: m['phone']?.toString() ?? '',
                    type: m['type']?.toString() ?? 'General',
                    hasEmergency: m['emergency_available'] == true,
                    distance:
                        (m['distance_km'] as num?)?.toDouble() ?? 0.0,
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
    setState(() {
      _hospitals = PakistanHospitals.getHospitalsByCity(_selectedCity);
      _isLoadingHospitals = false;
    });
  }

  void _changeCity(String city) {
    setState(() => _selectedCity = city);
    _loadHospitals();
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

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onCall;

  const _HospitalCard({
    required this.hospital,
    required this.onCall,
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
                      onPressed: onCall,
                      icon: const Icon(Icons.phone, size: 18),
                      label: Text(hospital.phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigation feature coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigate'),
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
