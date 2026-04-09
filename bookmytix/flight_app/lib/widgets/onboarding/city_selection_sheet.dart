import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// Professional city selection bottom sheet shown after authentication
/// Industry-standard approach used by MakeMyTrip, Uber, Booking.com
/// Personalizes destination content based on user's location
class CitySelectionSheet extends StatefulWidget {
  final VoidCallback onComplete;

  const CitySelectionSheet({super.key, required this.onComplete});

  @override
  State<CitySelectionSheet> createState() => _CitySelectionSheetState();
}

class _CitySelectionSheetState extends State<CitySelectionSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedCity;
  String? _selectedCode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Comprehensive Pakistani cities list - Professional standard (Bookme.pk, Sastaticket.pk)
  // Covers all provinces, major cities, and popular tourist destinations
  final List<Map<String, dynamic>> _allCities = [
    // Punjab - Major Cities
    {
      'name': 'Lahore',
      'code': 'LHE',
      'icon': Icons.location_city,
      'province': 'Punjab',
    },
    {
      'name': 'Faisalabad',
      'code': 'LYP',
      'icon': Icons.business,
      'province': 'Punjab',
    },
    {
      'name': 'Rawalpindi',
      'code': 'RWP',
      'icon': Icons.location_city,
      'province': 'Punjab',
    },
    {
      'name': 'Multan',
      'code': 'MUX',
      'icon': Icons.eco,
      'province': 'Punjab',
    },
    {
      'name': 'Gujranwala',
      'code': 'GUJ',
      'icon': Icons.apartment,
      'province': 'Punjab',
    },
    {
      'name': 'Sialkot',
      'code': 'SKT',
      'icon': Icons.sports_soccer,
      'province': 'Punjab',
    },
    {
      'name': 'Bahawalpur',
      'code': 'BHV',
      'icon': Icons.account_balance,
      'province': 'Punjab',
    },
    {
      'name': 'Sargodha',
      'code': 'SGD',
      'icon': Icons.eco,
      'province': 'Punjab',
    },
    {
      'name': 'Sahiwal',
      'code': 'SWL',
      'icon': Icons.eco,
      'province': 'Punjab',
    },
    {
      'name': 'Jhang',
      'code': 'JHG',
      'icon': Icons.account_balance,
      'province': 'Punjab',
    },

    // Islamabad & Sindh
    {
      'name': 'Islamabad',
      'code': 'ISB',
      'icon': Icons.account_balance,
      'province': 'ICT',
    },
    {
      'name': 'Karachi',
      'code': 'KHI',
      'icon': Icons.waves,
      'province': 'Sindh',
    },
    {
      'name': 'Hyderabad',
      'code': 'HDD',
      'icon': Icons.location_city,
      'province': 'Sindh',
    },
    {
      'name': 'Sukkur',
      'code': 'SKZ',
      'icon': Icons.alt_route,
      'province': 'Sindh',
    },
    {
      'name': 'Larkana',
      'code': 'LRK',
      'icon': Icons.account_balance,
      'province': 'Sindh',
    },
    {
      'name': 'Nawabshah',
      'code': 'NWB',
      'icon': Icons.eco,
      'province': 'Sindh',
    },

    // Khyber Pakhtunkhwa (KPK)
    {
      'name': 'Peshawar',
      'code': 'PEW',
      'icon': Icons.terrain,
      'province': 'KPK',
    },
    {
      'name': 'Abbottabad',
      'code': 'ATD',
      'icon': Icons.terrain,
      'province': 'KPK',
    },
    {
      'name': 'Mardan',
      'code': 'MRD',
      'icon': Icons.account_balance,
      'province': 'KPK',
    },
    {
      'name': 'Swat',
      'code': 'SWT',
      'icon': Icons.terrain,
      'province': 'KPK',
    },
    {
      'name': 'Mansehra',
      'code': 'MSH',
      'icon': Icons.terrain,
      'province': 'KPK',
    },

    // Balochistan
    {
      'name': 'Quetta',
      'code': 'UET',
      'icon': Icons.terrain,
      'province': 'Balochistan',
    },
    {
      'name': 'Gwadar',
      'code': 'GWD',
      'icon': Icons.waves,
      'province': 'Balochistan',
    },
    {
      'name': 'Turbat',
      'code': 'TUK',
      'icon': Icons.landscape,
      'province': 'Balochistan',
    },

    // Gilgit-Baltistan (Tourist Destinations)
    {
      'name': 'Gilgit',
      'code': 'GIL',
      'icon': Icons.terrain,
      'province': 'GB',
    },
    {
      'name': 'Skardu',
      'code': 'KDU',
      'icon': Icons.terrain,
      'province': 'GB',
    },
    {
      'name': 'Hunza',
      'code': 'HNZ',
      'icon': Icons.terrain,
      'province': 'GB',
    },

    // AJK (Azad Jammu & Kashmir)
    {
      'name': 'Muzaffarabad',
      'code': 'MFD',
      'icon': Icons.terrain,
      'province': 'AJK',
    },
    {
      'name': 'Mirpur',
      'code': 'MJL',
      'icon': Icons.account_balance,
      'province': 'AJK',
    },
  ];

  List<Map<String, dynamic>> get _filteredCities {
    if (_searchQuery.isEmpty) {
      return _allCities;
    }
    return _allCities.where((city) {
      return (city['name'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (city['code'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (city['province'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar for visual indication
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme(context).outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      TravelloTheme.primaryMainContainer,
                      TravelloTheme.secondaryMainContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: TravelloTheme.primaryMain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Which city are you in?',
                      style: TravelloTheme.title2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme(context).onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We\'ll show you relevant destinations and accurate travel times from your location',
                      style: TravelloTheme.caption.copyWith(
                        color: colorScheme(context)
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search bar (Pakistani app standard - Bookme.pk style)
              Container(
                decoration: BoxDecoration(
                  color: TravelloTheme.paperLightContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme(context).outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search city or code...',
                    hintStyle: TravelloTheme.caption.copyWith(
                      color:
                          colorScheme(context).onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: TravelloTheme.primaryMain,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme(context)
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Results count
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_filteredCities.length} cities found',
                    style: TravelloTheme.caption.copyWith(
                      color: TravelloTheme.primaryMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // City selection grid (scrollable)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      final isSelected = _selectedCity == city['name'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCity = city['name'] as String;
                            _selectedCode = city['code'] as String;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      TravelloTheme.primaryMain,
                                      colorScheme(context)
                                          .primary
                                          .withOpacity(0.8),
                                    ],
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : TravelloTheme.paperLightContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? TravelloTheme.primaryMain
                                  : colorScheme(context)
                                      .outline
                                      .withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme(context)
                                          .primary
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                city['icon'] as IconData,
                                size: 24,
                                color: isSelected
                                    ? Colors.white
                                    : TravelloTheme.primaryMain,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                city['name'] as String,
                                style: TravelloTheme.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : colorScheme(context).onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                city['code'] as String,
                                style: TravelloTheme.caption.copyWith(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : colorScheme(context)
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selectedCity == null
                      ? null
                      : () async {
                          // Save preference to SharedPreferences
                          await LocationPreferenceService.setOriginCity(
                            _selectedCity!,
                            _selectedCode!,
                          );

                          // Show professional confirmation message
                          Get.snackbar(
                            'Location Set',
                            'Showing destinations from $_selectedCity',
                            backgroundColor: Colors.green.shade600,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.TOP,
                            duration: const Duration(seconds: 2),
                            icon: const Icon(Icons.check_circle,
                                color: Colors.white),
                            borderRadius: 10,
                            margin: const EdgeInsets.all(10),
                          );

                          // Close sheet and continue to home
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          widget.onComplete();
                        },
                  style: ThemeButton.btnBig.merge(ThemeButton.primary),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline),
                      SizedBox(width: 8),
                      Text('CONTINUE', style: TravelloTheme.subtitle),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Skip button with default fallback
              TextButton(
                onPressed: () async {
                  // Set default to Karachi (largest city, most connections)
                  await LocationPreferenceService.setOriginCity(
                      'Karachi', 'KHI');

                  Get.snackbar(
                    'Default Location',
                    'Using Karachi as your location',
                    backgroundColor: Colors.blue.shade600,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 2),
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    borderRadius: 10,
                    margin: const EdgeInsets.all(10),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  widget.onComplete();
                },
                child: Text(
                  'Skip (Use Karachi as default)',
                  style: TravelloTheme.caption.copyWith(
                    color:
                        colorScheme(context).onSurface.withValues(alpha: 0.6),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TravelloTheme.paperLightContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color:
                          colorScheme(context).onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can change this anytime from Settings',
                        style: TravelloTheme.caption.copyWith(
                          fontSize: 11,
                          color: colorScheme(context)
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
