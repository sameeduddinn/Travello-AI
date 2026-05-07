import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IconData _typeIcon(String type) {
  switch (type) {
    case 'flight':
      return Icons.flight_rounded;
    case 'train':
      return Icons.train_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    default:
      return Icons.search_rounded;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'flight':
      return const Color(0xFF3B82F6);
    case 'train':
      return const Color(0xFF059669);
    case 'hotel':
      return const Color(0xFF7C3AED);
    default:
      return const Color(0xFF6B7280);
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'flight':
      return 'Flight';
    case 'train':
      return 'Train';
    case 'hotel':
      return 'Hotel';
    default:
      return 'Search';
  }
}

String _formatParams(Map<String, dynamic> p, String type) {
  if (p.containsKey('from') && p.containsKey('to')) {
    final route = '${p['from']} → ${p['to']}';
    final extras = <String>[];
    if (p['date'] != null) extras.add(p['date'].toString());
    if (p['passengers'] != null) extras.add('${p['passengers']} pax');
    return extras.isEmpty ? route : '$route  ·  ${extras.join('  ·  ')}';
  }
  if (p.containsKey('city')) return p['city'].toString();
  if (p.containsKey('destination')) return p['destination'].toString();
  final values =
      p.values.where((v) => v != null).map((v) => v.toString()).toList();
  return values.isEmpty ? _typeLabel(type) : values.take(3).join('  ·  ');
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  } catch (_) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SavedSearchesScreen extends StatefulWidget {
  const SavedSearchesScreen({super.key});

  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _searches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiClient.getSavedSearches();
    if (!mounted) return;
    setState(() {
      _searches = data;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    setState(() => _searches.removeWhere((s) => s['id']?.toString() == id));
    await ApiClient.deleteSavedSearch(id);
  }

  void _rerunSearch(Map<String, dynamic> data) {
    final type = data['search_type']?.toString() ?? '';
    final params = (data['search_params'] as Map?)?.cast<String, dynamic>() ?? {};

    switch (type) {
      case 'flight':
        final fromAirport = airportList.firstWhereOrNull(
          (a) => a.code == params['from'],
        );
        final toAirport = airportList.firstWhereOrNull(
          (a) => a.code == params['to'],
        );
        Get.toNamed(AppLink.flightList, arguments: {
          'fromAirport': fromAirport,
          'toAirport': toAirport,
          'departureDate':
              DateTime.tryParse(params['date']?.toString() ?? '') ??
                  DateTime.now(),
          'tripType': params['trip_type'] ?? 'One-way',
          'cabinClass': params['cabin_class'] ?? 'Economy',
          'adults': params['adults'] ?? 1,
          'children': params['children'] ?? 0,
          'infants': params['infants'] ?? 0,
        });
        break;

      case 'hotel':
        Get.toNamed(AppLink.hotelResults, arguments: {
          'city': params['city'] ?? '',
          'checkInDate':
              DateTime.tryParse(params['check_in']?.toString() ?? '') ??
                  DateTime.now(),
          'checkOutDate':
              DateTime.tryParse(params['check_out']?.toString() ?? '') ??
                  DateTime.now().add(const Duration(days: 1)),
          'rooms': params['rooms'] ?? 1,
          'guests': params['guests'] ?? 2,
        });
        break;

      case 'train':
        final allStations = PakistanRailwayStations.getAllStations();
        final fromStation = allStations.firstWhereOrNull(
          (s) => s.code == params['from'],
        );
        final toStation = allStations.firstWhereOrNull(
          (s) => s.code == params['to'],
        );
        Get.toNamed(AppLink.railwayList, arguments: {
          'fromStation': fromStation,
          'toStation': toStation,
          'departureDate':
              DateTime.tryParse(params['date']?.toString() ?? '') ??
                  DateTime.now(),
          'tripType': params['trip_type'] ?? 'One-way',
          'trainClass': params['train_class'] ?? 'Economy (Seat)',
          'adults': params['adults'] ?? 1,
          'children': params['children'] ?? 0,
          'infants': params['infants'] ?? 0,
        });
        break;
    }
  }

  List<Map<String, dynamic>> _forType(String? type) => type == null
      ? _searches
      : _searches.where((s) => s['search_type'] == type).toList();

  int _count(String? type) => _forType(type).length;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _Header(onRefresh: _load),
          _TabBar(controller: _tabController, counts: {
            null: _count(null),
            'flight': _count('flight'),
            'train': _count('train'),
            'hotel': _count('hotel'),
          }),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(null),
                _buildList('flight'),
                _buildList('train'),
                _buildList('hotel'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String? type) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }
    final items = _forType(type);
    if (items.isEmpty) {
      return _EmptyState(type: type);
    }
    return RefreshIndicator(
      color: const Color(0xFFD4AF37),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final s = items[i];
          return _SearchCard(
            data: s,
            onTap: () => _rerunSearch(s),
            onDelete: () => _delete(s['id']?.toString() ?? ''),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD4AF37), Color(0xFFDAB853), Color(0xFFE8C76A)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Saved Searches',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Your flight, train & hotel searches',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  final TabController controller;
  final Map<String?, int> counts;

  const _TabBar({required this.controller, required this.counts});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        labelColor: const Color(0xFFD4AF37),
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: const Color(0xFFD4AF37),
        indicatorWeight: 2.5,
        isScrollable: false,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: [
          Tab(text: 'All (${counts[null] ?? 0})'),
          Tab(text: 'Flights (${counts['flight'] ?? 0})'),
          Tab(text: 'Trains (${counts['train'] ?? 0})'),
          Tab(text: 'Hotels (${counts['hotel'] ?? 0})'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search card
// ---------------------------------------------------------------------------

class _SearchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SearchCard({required this.data, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = data['search_type']?.toString() ?? 'flight';
    final params =
        (data['search_params'] as Map?)?.cast<String, dynamic>() ?? {};
    final createdAt = data['created_at']?.toString();
    final color = _typeColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(type), color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatParams(params, type),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _typeLabel(type),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
                      if (createdAt != null && createdAt.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Delete
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade300, size: 20),
              onPressed: onDelete,
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String? type;
  const _EmptyState({this.type});

  @override
  Widget build(BuildContext context) {
    final label = type == null ? 'searches yet' : '${_typeLabel(type!)} searches yet';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No saved $label',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Search for flights, trains or hotels\nand they\'ll appear here automatically.',
              style: TravelloTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
