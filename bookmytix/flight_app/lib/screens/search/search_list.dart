import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/search_history_service.dart';
import 'package:flight_app/widgets/search_filters/search_input.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFFEF9EC);
const _goldDark = Color(0xFFB8935C);
const _flightBlue = Color(0xFF3B82F6);
const _trainGreen = Color(0xFF059669);

// ─── Data ─────────────────────────────────────────────────────────────────────
class _Chip {
  final String label;
  final String type; // 'flight' | 'train' | 'hotel'
  const _Chip(this.label, this.type);
}

const _popularSearches = [
  _Chip('KHI → LHE', 'flight'),
  _Chip('LHE → ISB', 'flight'),
  _Chip('Karachi Express', 'train'),
  _Chip('Shalimar Express', 'train'),
  _Chip('Hotels in Lahore', 'hotel'),
  _Chip('PIA Flights', 'flight'),
  _Chip('Hotels in Karachi', 'hotel'),
  _Chip('Tezgam', 'train'),
  _Chip('ISB → KHI', 'flight'),
  _Chip('Hotels Murree', 'hotel'),
];

class _Route {
  final String from, to, fromCode, toCode, type, detail;
  const _Route(
      this.from, this.to, this.fromCode, this.toCode, this.type, this.detail);
}

const _flightRoutes = [
  _Route('Karachi', 'Islamabad', 'KHI', 'ISB', 'flight', '~PKR 9,500'),
  _Route('Lahore', 'Karachi', 'LHE', 'KHI', 'flight', '~PKR 7,200'),
  _Route('Islamabad', 'Lahore', 'ISB', 'LHE', 'flight', '~PKR 6,800'),
  _Route('Karachi', 'Peshawar', 'KHI', 'PEW', 'flight', '~PKR 11,000'),
  _Route('Islamabad', 'Skardu', 'ISB', 'KDU', 'flight', '~PKR 14,000'),
];

const _trainRoutes = [
  _Route('Lahore', 'Karachi', 'LHE', 'KHI', 'train', 'Shalimar Express'),
  _Route('Karachi', 'Lahore', 'KHI', 'LHE', 'train', 'Karakoram Express'),
  _Route('Lahore', 'Islamabad', 'LHE', 'ISB', 'train', 'Rawal Express'),
  _Route('Karachi', 'Peshawar', 'KHI', 'PWL', 'train', 'Khyber Mail'),
  _Route('Islamabad', 'Lahore', 'ISB', 'LHE', 'train', 'Business Express'),
];

class _Dest {
  final String name, emoji, tagline;
  final Color color;
  const _Dest(this.name, this.emoji, this.tagline, this.color);
}

const _destinations = [
  _Dest('Hunza', '🏔', 'Northern Gem', Color(0xFF4A90D9)),
  _Dest('Skardu', '🏔', 'Mountain Paradise', Color(0xFF2E7D32)),
  _Dest('Murree', '⛰', 'Hill Station', Color(0xFF6A1B9A)),
  _Dest('Lahore', '🕌', 'City of Gardens', Color(0xFFE65100)),
  _Dest('Karachi', '🌊', 'City of Lights', Color(0xFF0277BD)),
  _Dest('Islamabad', '🌿', 'Capital City', Color(0xFF1B5E20)),
  _Dest('Swat', '🌸', 'Switzerland of East', Color(0xFFAD1457)),
  _Dest('Peshawar', '🏛', 'City of Flowers', Color(0xFF4E342E)),
  _Dest('Quetta', '🌵', 'Fruit Basket', Color(0xFF558B2F)),
  _Dest('Naran', '🏕', 'Kaghan Valley', Color(0xFF00695C)),
];

// ═════════════════════════════════════════════════════════════════════════════
class SearchList extends StatefulWidget {
  const SearchList({super.key});
  @override
  State<SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<SearchList> with TickerProviderStateMixin {
  final TextEditingController _textRef = TextEditingController();
  late TabController _catTab; // All / Flights / Trains / Hotels
  late TabController _routeTab; // Flights / Trains (popular routes)

  bool _showResults = false;
  List<String> _history = [];
  int _catIndex = 0;

  @override
  void initState() {
    super.initState();
    _catTab = TabController(length: 4, vsync: this);
    _routeTab = TabController(length: 2, vsync: this);
    _catTab.addListener(() {
      if (!_catTab.indexIsChanging) setState(() => _catIndex = _catTab.index);
    });
    _textRef.addListener(
        () => setState(() => _showResults = _textRef.text.trim().length >= 2));
    _loadHistory();
  }

  @override
  void dispose() {
    _textRef.dispose();
    _catTab.dispose();
    _routeTab.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final f = await SearchHistoryService.getFlightHistory();
    final t = await SearchHistoryService.getTrainHistory();
    final combined = <String>{...f, ...t}.take(6).toList();
    if (mounted) setState(() => _history = combined);
  }

  Future<void> _navigate(String cityName, String type) async {
    if (type == 'flight') {
      await SearchHistoryService.saveFlightSearch(cityName);
    } else {
      await SearchHistoryService.saveTrainSearch(cityName);
    }
    Get.toNamed('/city-search-results', arguments: {'cityName': cityName});
  }

  void _fillSearch(String text) => setState(() {
        _textRef.text = text;
        _textRef.selection =
            TextSelection.fromPosition(TextPosition(offset: text.length));
        _showResults = true;
      });

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Get.back(),
        ),
        titleSpacing: 0,
        title: SearchInput(
          autofocus: true,
          textRef: _textRef,
          hintText: 'Search flights, trains, hotels...',
        ),
      ),
      body: _showResults ? _buildResults() : _buildIdle(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESULTS (typing)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildResults() {
    final kw = _textRef.text.trim().toLowerCase();

    // Airports
    final airports = airportList
        .where((a) =>
            '${a.location} ${a.name} ${a.code}'.toLowerCase().contains(kw))
        .toList();

    // Train Stations
    final stations = PakistanRailwayStations.getAllStations()
        .where(
            (s) => '${s.name} ${s.city} ${s.code}'.toLowerCase().contains(kw))
        .toList();

    if (airports.isEmpty && stations.isEmpty) {
      return _buildNoResults();
    }

    // Build combined list with section headers
    final items = <Widget>[];

    if (airports.isNotEmpty) {
      items.add(_sectionLabel('Airports & Cities', Icons.flight, _flightBlue));
      for (final a in airports) {
        items.add(_resultTile(
          icon: Icons.flight_takeoff,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: _flightBlue,
          title: a.location,
          subtitle: a.name,
          code: a.code,
          onTap: () => _navigate(a.location, 'flight'),
        ));
        // Show outbound + inbound hint
        items.add(_directionHint(a.location, a.code));
      }
    }

    if (stations.isNotEmpty) {
      items.add(SizedBox(height: airports.isNotEmpty ? spacingUnit(2) : 0));
      items.add(_sectionLabel('Railway Stations', Icons.train, _trainGreen));
      for (final s in stations) {
        items.add(_resultTile(
          icon: Icons.train,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: _trainGreen,
          title: s.name,
          subtitle: s.city,
          code: s.code,
          onTap: () => _navigate(s.name, 'train'),
        ));
      }
    }

    return ListView(
      padding: EdgeInsets.symmetric(
          vertical: spacingUnit(1), horizontal: spacingUnit(2)),
      children: items,
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, spacingUnit(1.5), 0, spacingUnit(0.75)),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: spacingUnit(0.5)),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1)),
      ]),
    );
  }

  Widget _directionHint(String cityName, String code) {
    return Padding(
      padding: EdgeInsets.only(left: 56, bottom: spacingUnit(0.5)),
      child: Row(children: [
        _miniChip('From $code', Icons.flight_takeoff, _flightBlue,
            () => _navigate(cityName, 'flight')),
        SizedBox(width: spacingUnit(1)),
        _miniChip('To $code', Icons.flight_land, const Color(0xFF8B5CF6),
            () => _navigate(cityName, 'flight')),
      ]),
    );
  }

  Widget _miniChip(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _resultTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String code,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacingUnit(0.75)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(width: spacingUnit(1.5)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: ThemeText.subtitle
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: ThemeText.caption
                        .copyWith(color: Colors.grey.shade500)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _goldLight, borderRadius: BorderRadius.circular(6)),
            child: Text(code,
                style: const TextStyle(
                    color: _goldDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacingUnit(4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          SizedBox(height: spacingUnit(2)),
          Text('No results for "${_textRef.text}"',
              style: ThemeText.subtitle.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
          SizedBox(height: spacingUnit(1)),
          Text('Try a city, airport code, or train station',
              style: ThemeText.caption.copyWith(color: Colors.grey.shade400),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IDLE CONTENT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildIdle() {
    return Column(children: [
      _buildCategoryTabs(),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      Expanded(
        child: ListView(
          padding: EdgeInsets.all(spacingUnit(2)),
          children: [
            _buildPopularSearches(),
            SizedBox(height: spacingUnit(2.5)),
            _buildHintCards(),
            SizedBox(height: spacingUnit(2.5)),
            _buildQuickBook(),
            SizedBox(height: spacingUnit(2.5)),
            if (_history.isNotEmpty) ...[
              _buildRecentSearches(),
              SizedBox(height: spacingUnit(2.5)),
            ],
            _buildHeader('Popular Routes', Icons.local_fire_department,
                Colors.red.shade600),
            SizedBox(height: spacingUnit(1.5)),
            _buildPopularRoutes(),
            SizedBox(height: spacingUnit(2.5)),
            _buildHeader('Popular Destinations', Icons.explore, _gold),
            SizedBox(height: spacingUnit(1.5)),
            _buildDestinations(),
            SizedBox(height: spacingUnit(2)),
          ],
        ),
      ),
    ]);
  }

  // ── Category Tabs ─────────────────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    const tabs = [
      _Chip('All', ''),
      _Chip('Flights', 'flight'),
      _Chip('Trains', 'train'),
      _Chip('Hotels', 'hotel'),
    ];
    const icons = [Icons.apps, Icons.flight, Icons.train, Icons.hotel];

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _catTab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _gold,
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: _gold,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: List.generate(
            4,
            (i) => Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[i], size: 15),
                    const SizedBox(width: 5),
                    Text(tabs[i].label),
                  ]),
                )),
      ),
    );
  }

  // ── Popular Search Chips ──────────────────────────────────────────────────
  Widget _buildPopularSearches() {
    final typeFilter = ['', 'flight', 'train', 'hotel'][_catIndex];
    final chips = typeFilter.isEmpty
        ? _popularSearches
        : _popularSearches.where((c) => c.type == typeFilter).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('POPULAR SEARCHES',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.2)),
      SizedBox(height: spacingUnit(1.5)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((c) {
          final color = c.type == 'flight'
              ? _flightBlue
              : c.type == 'train'
                  ? _trainGreen
                  : _goldDark;
          return GestureDetector(
            onTap: () => _fillSearch(c.label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  c.type == 'flight'
                      ? Icons.flight
                      : c.type == 'train'
                          ? Icons.train
                          : Icons.hotel,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(c.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── Hint Cards ────────────────────────────────────────────────────────────
  Widget _buildHintCards() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: _hintCard(
              'FLIGHTS',
              Icons.flight,
              const Color(0xFFEFF6FF),
              _flightBlue,
              [
                'City to city (KHI-LHE)',
                'Airline (PIA, AirBlue, AirSial)',
                'One-way or Return',
                'Business class seats'
              ],
              AppLink.flightSearchHome)),
      SizedBox(width: spacingUnit(1)),
      Expanded(
          child: _hintCard(
              'TRAINS & HOTELS',
              Icons.train,
              const Color(0xFFF0FDF4),
              _trainGreen,
              [
                'Train name (Tezgam)',
                'Route (KHI → LHE)',
                'Hotel in a city',
                'Budget / 5-star hotels'
              ],
              AppLink.trainSearchHome)),
    ]);
  }

  Widget _hintCard(String title, IconData icon, Color bg, Color accent,
      List<String> hints, String route) {
    return GestureDetector(
      onTap: () => Get.toNamed(route),
      child: Container(
        padding: EdgeInsets.all(spacingUnit(1.5)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 13, color: accent),
            SizedBox(width: spacingUnit(0.5)),
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.6)),
          ]),
          SizedBox(height: spacingUnit(1)),
          ...hints.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: TextStyle(
                              fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w700)),
                      Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF374151),
                                  height: 1.4))),
                    ]),
              )),
        ]),
      ),
    );
  }

  // ── Quick Book ────────────────────────────────────────────────────────────
  Widget _buildQuickBook() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader('Quick Book', Icons.bolt, _gold),
      SizedBox(height: spacingUnit(1.5)),
      Row(children: [
        _quickBtn('Flights', Icons.flight, _flightBlue, const Color(0xFFEFF6FF),
            AppLink.flightSearchHome),
        SizedBox(width: spacingUnit(1.5)),
        _quickBtn('Trains', Icons.train, _trainGreen, const Color(0xFFF0FDF4),
            AppLink.trainSearchHome),
        SizedBox(width: spacingUnit(1.5)),
        _quickBtn(
            'Hotels', Icons.hotel, _goldDark, _goldLight, AppLink.hotelSearch),
      ]),
    ]);
  }

  Widget _quickBtn(
      String label, IconData icon, Color color, Color bg, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Get.toNamed(route),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(2)),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            SizedBox(height: spacingUnit(0.75)),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  // ── Recent Searches ───────────────────────────────────────────────────────
  Widget _buildRecentSearches() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _buildHeader('Recent Searches', Icons.history, Colors.grey.shade600),
        GestureDetector(
          onTap: () async {
            await SearchHistoryService.clearFlightHistory();
            await SearchHistoryService.clearTrainHistory();
            setState(() => _history = []);
          },
          child: const Text('Clear all',
              style: TextStyle(
                  fontSize: 12, color: _gold, fontWeight: FontWeight.w600)),
        ),
      ]),
      SizedBox(height: spacingUnit(1.5)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _history
            .map((item) => GestureDetector(
                  onTap: () => _fillSearch(item),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 5),
                      Text(item,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151))),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ]);
  }

  // ── Popular Routes ────────────────────────────────────────────────────────
  Widget _buildPopularRoutes() {
    return Column(children: [
      Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _routeTab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicator: BoxDecoration(
              color: _gold, borderRadius: BorderRadius.circular(8)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.flight, size: 14),
              SizedBox(width: 5),
              Text('Flights')
            ])),
            Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.train, size: 14),
              SizedBox(width: 5),
              Text('Trains')
            ])),
          ],
        ),
      ),
      SizedBox(height: spacingUnit(1.5)),
      SizedBox(
        height: 68.0 * 3 + spacingUnit(1) * 2,
        child: TabBarView(
          controller: _routeTab,
          children: [
            _routeList(_flightRoutes, 'flight'),
            _routeList(_trainRoutes, 'train'),
          ],
        ),
      ),
    ]);
  }

  Widget _routeList(List<_Route> routes, String type) {
    final accent = type == 'flight' ? _flightBlue : _trainGreen;
    final bg =
        type == 'flight' ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: routes.length > 3 ? 3 : routes.length,
      separatorBuilder: (_, __) => SizedBox(height: spacingUnit(1)),
      itemBuilder: (context, i) {
        final r = routes[i];
        return GestureDetector(
          onTap: () => Get.toNamed(type == 'flight'
              ? AppLink.flightSearchHome
              : AppLink.trainSearchHome),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: spacingUnit(1.75), vertical: spacingUnit(1.25)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(
                    type == 'flight' ? Icons.flight_takeoff : Icons.train,
                    color: accent,
                    size: 18),
              ),
              SizedBox(width: spacingUnit(1.5)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(r.from,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 13, color: Colors.grey.shade400),
                      ),
                      Text(r.to,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: bg, borderRadius: BorderRadius.circular(4)),
                        child: Text('${r.fromCode}→${r.toCode}',
                            style: TextStyle(
                                fontSize: 10,
                                color: accent,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(r.detail,
                        style: TextStyle(
                            fontSize: 12,
                            color: type == 'flight'
                                ? _goldDark
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                  ])),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
            ]),
          ),
        );
      },
    );
  }

  // ── Destinations ──────────────────────────────────────────────────────────
  Widget _buildDestinations() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72),
      itemCount: _destinations.length,
      itemBuilder: (context, i) {
        final d = _destinations[i];
        return GestureDetector(
          onTap: () => _fillSearch(d.name),
          child: Column(children: [
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: d.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: d.color.withValues(alpha: 0.2)),
              ),
              child: Center(
                  child: Text(d.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 4),
            Text(d.name,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(d.tagline,
                style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        );
      },
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  Widget _buildHeader(String title, IconData icon, Color iconColor) {
    return Row(children: [
      Icon(icon, size: 17, color: iconColor),
      SizedBox(width: spacingUnit(0.75)),
      Text(title,
          style: ThemeText.subtitle.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: const Color(0xFF111827))),
    ]);
  }
}
