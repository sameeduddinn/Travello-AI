import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/home/banner.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// Travel mode descriptor
class _Mode {
  final IconData icon;
  final String label;
  final Color accent;
  const _Mode(this.icon, this.label, this.accent);
}

const _modes = [
  _Mode(Icons.flight_rounded, 'Flights', Color(0xFF3B82F6)),
  _Mode(Icons.train_rounded, 'Trains', Color(0xFF059669)),
  _Mode(Icons.hotel_rounded, 'Hotels', Color(0xFFD4AF37)),
];

class SearchHome extends StatefulWidget {
  const SearchHome({super.key});

  @override
  State<SearchHome> createState() => _SearchHomeState();
}

class _SearchHomeState extends State<SearchHome> {
  int _selected = 0; // 0=Flights, 1=Trains, 2=Hotels

  void _openSearch() => Get.toNamed(AppLink.searchList);

  @override
  Widget build(BuildContext context) {
    final mode = _modes[_selected];

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        /// BANNER
        const Positioned(top: 0, child: HomeBanner()),

        /// SEARCH CARD — Column spacer pushes card to overlap the banner
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Push card down to sit near bottom of the 450px banner
              const SizedBox(height: 360),

              // ── Card ────────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Mode selector ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                        child: Row(
                          children: List.generate(_modes.length, (i) {
                            final m = _modes[i];
                            final active = i == _selected;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(
                                      right: i < _modes.length - 1 ? 8 : 0),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? m.accent.withValues(alpha: 0.12)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? m.accent
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        m.icon,
                                        size: 16,
                                        color: active
                                            ? m.accent
                                            : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        m.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: active
                                              ? m.accent
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Fake search input (tappable) ───────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: GestureDetector(
                          onTap: _openSearch,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: mode.accent, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _hint(_selected),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TravelloTheme.primaryMain,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Search',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _hint(int index) {
    switch (index) {
      case 0:
        return 'Where do you want to fly?';
      case 1:
        return 'Search train routes...';
      case 2:
        return 'Find hotels in any city...';
      default:
        return 'Search...';
    }
  }
}
