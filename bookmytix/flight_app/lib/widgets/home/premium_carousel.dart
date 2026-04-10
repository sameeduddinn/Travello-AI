import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Static Pakistan slides — never change regardless of selected tab
// ─────────────────────────────────────────────────────────────────────────────
const List<_Slide> _pakistanSlides = [
  _Slide(
    // Attabad Lake, Hunza Valley
    url: 'https://images.unsplash.com/photo-1586348943529-beaae6c28db9?w=900',
    location: 'Hunza Valley, Gilgit',
    tagline: 'Heaven on Earth',
  ),
  _Slide(
    // Badshahi Mosque, Lahore
    url: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=900',
    location: 'Lahore, Punjab',
    tagline: 'City of Gardens & Culture',
  ),
  _Slide(
    // Faisal Mosque, Islamabad
    url: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=900',
    location: 'Islamabad',
    tagline: "Pakistan's Green Capital",
  ),
  _Slide(
    // Karachi Sea View / Clifton
    url:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
    location: 'Karachi, Sindh',
    tagline: 'City of Lights & The Sea',
  ),
  _Slide(
    // Swat Valley green landscape
    url: 'https://images.unsplash.com/photo-1597149441099-47f7e2e4e468?w=900',
    location: 'Swat Valley, KPK',
    tagline: 'The Switzerland of Pakistan',
  ),
];

class _Slide {
  final String url;
  final String location;
  final String tagline;
  const _Slide(
      {required this.url, required this.location, required this.tagline});
}

// ─────────────────────────────────────────────────────────────────────────────
//  PremiumCarousel — place ONCE in the layout, stays fixed across all tabs
// ─────────────────────────────────────────────────────────────────────────────
class PremiumCarousel extends StatefulWidget {
  final double height;
  const PremiumCarousel({super.key, this.height = 210});

  @override
  State<PremiumCarousel> createState() => _PremiumCarouselState();
}

class _PremiumCarouselState extends State<PremiumCarousel> {
  late final PageController _ctrl;
  double _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.88)
      ..addListener(() {
        setState(() => _page = _ctrl.page ?? 0);
      });
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1).round() % _pakistanSlides.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _pakistanSlides.length,
            onPageChanged: (_) => HapticFeedback.lightImpact(),
            itemBuilder: (context, index) {
              final diff = (index - _page).abs();
              final scale = (1 - diff * 0.08).clamp(0.0, 1.0);
              final opacity = (1 - diff * 0.35).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _Card(slide: _pakistanSlides[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _Dots(
          count: _pakistanSlides.length,
          current: _page.round() % _pakistanSlides.length,
          context: context,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final _Slide slide;
  const _Card({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.network(
              slide.url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
              ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Text — bottom left
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slide.location,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    slide.tagline,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.88),
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 6)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Expanding dot indicator
// ─────────────────────────────────────────────────────────────────────────────
class _Dots extends StatelessWidget {
  final int count;
  final int current;
  final BuildContext context;
  const _Dots(
      {required this.count, required this.current, required this.context});

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFD4AF37)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
