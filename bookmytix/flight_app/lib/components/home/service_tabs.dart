import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

/// ✨ ENTERPRISE-GRADE SERVICE TABS
/// Premium tab selector for Flight | Train | Hotel services
/// Features:
/// - Smooth slide animation on tab change
/// - Glassmorphism design
/// - Accessibility support
/// - Responsive layout
class ServiceTabs extends StatefulWidget {
  final String selectedService;
  final ValueChanged<String> onServiceChanged;

  const ServiceTabs({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
  });

  @override
  State<ServiceTabs> createState() => _ServiceTabsState();
}

class _ServiceTabsState extends State<ServiceTabs>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _hoveredIndex = -1;

  final List<Map<String, dynamic>> _services = [
    {
      'id': 'flight',
      'label': 'Flights',
      'icon': CupertinoIcons.airplane,
    },
    {
      'id': 'train',
      'label': 'Trains',
      'icon': CupertinoIcons.train_style_one,
    },
    {
      'id': 'hotel',
      'label': 'Hotels',
      'icon': CupertinoIcons.building_2_fill,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    return _services.indexWhere((s) => s['id'] == widget.selectedService);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Exact 1/3 of the widget's own width — no phantom padding deductions
        final tabWidth = constraints.maxWidth / 3;
        return _buildTabContent(context, tabWidth);
      },
    );
  }

  Widget _buildTabContent(BuildContext context, double tabWidth) {
    final isSmall = MediaQuery.of(context).size.width < 380;
    final tabHeight = isSmall ? 48.0 : 56.0;
    return SizedBox(
      height: tabHeight,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Animated indicator background
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              left: _selectedIndex * tabWidth,
              width: tabWidth,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      TravelloTheme.primaryMain,
                      TravelloTheme.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),

            // Service buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _services.asMap().entries.map((entry) {
                final index = entry.key;
                final service = entry.value;
                final isSelected = service['id'] == widget.selectedService;
                final isHovered = _hoveredIndex == index;
                return Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = -1),
                    child: GestureDetector(
                      onTap: () {
                        _animationController.forward(from: 0);
                        widget.onServiceChanged(service['id']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: tabHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: (!isSelected && isHovered)
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.transparent,
                          boxShadow: isHovered && !isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isHovered && !isSelected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                service['icon'],
                                color: isSelected
                                    ? Colors.white
                                    : isHovered
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.white.withValues(alpha: 0.65),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service['label'],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isHovered
                                        ? Colors.white.withValues(alpha: 0.95)
                                        : Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : isHovered
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ), // Container
    ); // SizedBox
  }
}
