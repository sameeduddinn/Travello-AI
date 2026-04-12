import 'package:flight_app/constants/image_api.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.saveIntroStatus});

  final Function() saveIntroStatus;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  int _current = 0;
  final CarouselSliderController _sliderRef = CarouselSliderController();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _restartAnimation() {
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> introList = [
      {
        'title': 'All-in-One Travel App',
        'desc':
            'Book flights and railways across Pakistan with ease and convenience.',
        'image': ImgApi.intro[0],
        'gradient': TravelloTheme.gradientHeroGold,
      },
      {
        'title': 'AI Travel Assistant',
        'desc':
            'Chat with AI to plan your perfect journey and get personalized recommendations.',
        'image': ImgApi.intro[1],
        'gradient': TravelloTheme.gradientSkyTravel,
      },
      {
        'title': 'Safe & Smart Travel',
        'desc':
            'Get real-time weather alerts and healthcare guidance for a secure journey.',
        'image': ImgApi.intro[2],
        'gradient': TravelloTheme.gradientSunsetTravel,
      },
      {
        'title': 'Made for Pakistan',
        'desc':
            'Designed for domestic travel with local cities, stations, and cultural understanding.',
        'image': ImgApi.intro[0],
        'gradient': TravelloTheme.gradientBeigeLight,
      },
    ];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: introList[_current]['gradient'] as LinearGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                      height: 400,
                      child: CarouselSlider(
                          items: introList
                              .map((item) => _contentIntro(
                                    context,
                                    item['title'] as String,
                                    item['desc'] as String,
                                    item['image'] as String,
                                  ))
                              .toList(),
                          carouselController: _sliderRef,
                          options: CarouselOptions(
                              autoPlay: false,
                              initialPage: 0,
                              enlargeFactor: 1,
                              reverse: false,
                              enableInfiniteScroll: false,
                              autoPlayCurve: Curves.fastOutSlowIn,
                              enlargeCenterPage: false,
                              aspectRatio: 1,
                              viewportFraction: 1,
                              disableCenter: true,
                              height: 400,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _current = index;
                                  _restartAnimation();
                                });
                              }))),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: introList.asMap().entries.map((entry) {
                  var curSlide = entry.key;

                  return GestureDetector(
                    onTap: () {
                      _sliderRef.animateToPage(curSlide);
                    },
                    child: Container(
                      width: _current == curSlide ? 24.0 : 12.0,
                      height: 12.0,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                          borderRadius: ThemeRadius.big,
                          color: Colors.white.withValues(
                              alpha: _current == curSlide ? 0.9 : 0.2)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () async {
                            widget.saveIntroStatus();
                            await Future.delayed(
                                const Duration(milliseconds: 100));
                            Get.offAllNamed(AppLink.welcome);
                          },
                          child: Text('SKIP',
                              style: TravelloTheme.subtitle
                                  .copyWith(color: Colors.white))),
                      _current < introList.length - 1
                          ? FilledButton(
                              style: ThemeButton.btnBig
                                  .merge(ThemeButton.tonalPrimary(context)),
                              onPressed: () => _sliderRef.nextPage(),
                              child: Row(children: [
                                const Text('NEXT',
                                    style: TravelloTheme.subtitle),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16,
                                    color:
                                        colorScheme(context).onPrimaryContainer)
                              ]))
                          : FilledButton(
                              style: ThemeButton.btnBig
                                  .merge(ThemeButton.tonalPrimary(context)),
                              onPressed: () async {
                                widget.saveIntroStatus();
                                await Future.delayed(
                                    const Duration(milliseconds: 100));
                                Get.offAllNamed(AppLink.welcome);
                              },
                              child: Row(children: [
                                const Text('CONTINUE',
                                    style: TravelloTheme.subtitle),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16,
                                    color:
                                        colorScheme(context).onPrimaryContainer)
                              ]))
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentIntro(
      BuildContext context, String title, String desc, String image) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SvgPicture.asset(
                image,
                width: 200,
                height: 200,
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
