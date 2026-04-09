import 'package:flight_app/utils/custom_tooltip.dart';
import 'package:flight_app/widgets/bottom_navigation/bottom_nav_menu.dart';
import 'package:flight_app/widgets/home/city_destinations/city_destinations_main.dart';
import 'package:flight_app/widgets/home/header.dart';
import 'package:flight_app/widgets/home/package_list_slider.dart';
import 'package:flight_app/widgets/home/search.dart';
import 'package:flight_app/widgets/home/quick_search_bar.dart';
import 'package:flight_app/widgets/home/flight_list_double.dart';
import 'package:flight_app/widgets/home/quick_access_features.dart';
import 'package:flight_app/widgets/home/travello_features.dart';
import 'package:flight_app/screens/home_railway.dart';
import 'package:flutter/material.dart';
import 'package:overlay_tooltip/overlay_tooltip.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ScrollController _scrollref = ScrollController();
  final TooltipController _tooltipRef = TooltipController();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  final String _key = 'finishedGuide';
  String _travelMode = 'airline'; // Default mode

  bool _isFixed = false;
  // ignore: unused_field
  bool _isDoneGuide = false;

  void _checkFinishedGuide() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDoneGuide = prefs.getBool(_key) ?? false;
      _travelMode = prefs.getString('travel_mode') ?? 'airline';
    });
  }

  @override
  void initState() {
    _tooltipRef.onDone(() async {
      SharedPreferences pref = await _prefs;
      pref.setBool(_key, true);
      setState(() {
        _isDoneGuide = true;
      });
    });

    _checkFinishedGuide();
    super.initState();
  }

  @override
  void dispose() {
    _tooltipRef.dispose();
    _scrollref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Route to different home based on travel mode
    if (_travelMode == 'railway') {
      return const HomeRailway();
    }

    // Default: Airline Mode (existing home)
    _scrollref.addListener(() {
      setState(() {
        if (_scrollref.offset > 60) {
          _isFixed = true;
        } else {
          _isFixed = false;
        }
      });
    });

    return OverlayTooltipScaffold(
      overlayColor: Colors.grey.shade400.withValues(alpha: 0.3),
      tooltipAnimationCurve: Curves.linear,
      tooltipAnimationDuration: const Duration(milliseconds: 1000),
      controller: _tooltipRef,
      startWhen: (initializedWidgetLength) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return false; // Tutorial disabled - users can freely explore
      },
      builder: (context) => Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: HomeHeader(isFixed: _isFixed),
        ),
        body: SingleChildScrollView(
          controller: _scrollref,
          child: Column(
            children: [
              const SearchHome(),
              const VSpaceShort(),
              const QuickSearchBar(),
              const VSpace(),
              const QuickAccessFeatures(),
              const VSpace(),
              const TravelloFeatures(),
              const VSpace(),
              OverlayTooltipItem(
                  displayIndex: 1,
                  tooltip: (controller) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: MTooltip(
                            title: 'Explore The Most Popular Places',
                            controller: controller),
                      ),
                  child: const CityDestinations()),
              const VSpaceBig(),
              const PackageListSlider(),
              const VSpaceBig(),
              const FlightListDouble(),
              const SizedBox(
                height: 120,
              )
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavMenu(),
      ),
    );
  }
}
