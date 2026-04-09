import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pakistan destination data model
// ─────────────────────────────────────────────────────────────────────────────
class _PakDestination {
  final String name;
  final String province;
  final String tagline;
  final String imageUrl;
  final String category; // matches ExploreCategoryFilter labels
  final Color accentColor;
  final String flightCode; // IATA or nearest airport code
  final List<String> highlights;
  final String description;
  final String bestTime;

  const _PakDestination({
    required this.name,
    required this.province,
    required this.tagline,
    required this.imageUrl,
    required this.category,
    required this.accentColor,
    required this.flightCode,
    required this.highlights,
    required this.description,
    required this.bestTime,
  });
}

const List<_PakDestination> _pakDestinations = [
  // ── ADVENTURE ──────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Hunza Valley',
    province: 'Gilgit-Baltistan',
    tagline: 'Heaven on Earth',
    imageUrl:
        'https://images.unsplash.com/photo-1587474260584-136574528ed5?w=800&q=80',
    category: 'Adventure',
    accentColor: Color(0xFF1565C0),
    flightCode: 'GIL',
    highlights: ['K2 Trek', 'Attabad Lake', 'Baltit Fort'],
    description:
        'Hunza is a breathtaking mountain valley nestled at 2,438 m, renowned for its ancient forts, turquoise Attabad Lake, and views of some of the world\'s highest peaks.',
    bestTime: 'Apr – Oct',
  ),
  _PakDestination(
    name: 'Skardu',
    province: 'Gilgit-Baltistan',
    tagline: 'Gateway to K2',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    category: 'Adventure',
    accentColor: Color(0xFF4527A0),
    flightCode: 'SKD',
    highlights: ['K2 Base Camp', 'Deosai Plains', 'Shangrila'],
    description:
        'Skardu sits at 2,228 m in the Karakoram range and is the base for expeditions to K2, the 2nd highest peak on Earth. It hosts some of the most dramatic landscapes in Asia.',
    bestTime: 'May – Sep',
  ),
  _PakDestination(
    name: 'Swat Valley',
    province: 'KPK',
    tagline: 'Switzerland of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80',
    category: 'Adventure',
    accentColor: Color(0xFF1B5E20),
    flightCode: 'PEW',
    highlights: ['Malam Jabba Ski', 'Mahodand Lake', 'Madyan'],
    description:
        'Swat Valley, once called the \'Switzerland of the East\', is famed for its lush pine-forested hills, gushing rivers, and ski resort at Malam Jabba. A paradise for nature lovers.',
    bestTime: 'Mar – Nov',
  ),
  _PakDestination(
    name: 'Naran & Kaghan',
    province: 'KPK',
    tagline: 'Land of Glacial Lakes',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    category: 'Adventure',
    accentColor: Color(0xFF006064),
    flightCode: 'ISB',
    highlights: ['Saiful Muluk Lake', 'Babusar Top', 'Lulusar Lake'],
    description:
        'Naran & Kaghan Valley offers one of Pakistan\'s most scenic road journeys with the famous Saiful Muluk Lake at 3,224 m — a glacier-fed jewel surrounded by towering peaks.',
    bestTime: 'Jun – Sep',
  ),

  // ── MOUNTAINS ──────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Fairy Meadows',
    province: 'Gilgit-Baltistan',
    tagline: 'Base of Nanga Parbat',
    imageUrl:
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=800&q=80',
    category: 'Mountains',
    accentColor: Color(0xFF37474F),
    flightCode: 'GIL',
    highlights: ['Nanga Parbat View', 'Raikot Glacier', 'Beyal Camp'],
    description:
        'Fairy Meadows is a lush green plateau at 3,300 m offering unobstructed views of Nanga Parbat (8,126 m) — the 9th highest mountain and one of the deadliest climbs in the world.',
    bestTime: 'May – Oct',
  ),
  _PakDestination(
    name: 'Gilgit',
    province: 'Gilgit-Baltistan',
    tagline: 'Where Rivers Meet',
    imageUrl:
        'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800&q=80',
    category: 'Mountains',
    accentColor: Color(0xFF4E342E),
    description:
        'Gilgit is the capital of Gilgit-Baltistan at the confluence of the Gilgit and Hunza rivers. It serves as the gateway to some of the world\'s highest mountain ranges.',
    bestTime: 'Apr – Oct',
    flightCode: 'GIL',
    highlights: ['Rakaposhi Base', 'Naltar Valley', 'Jutial Gorge'],
  ),
  _PakDestination(
    name: 'Chitral',
    province: 'KPK',
    tagline: 'Roof of KPK',
    imageUrl:
        'https://images.unsplash.com/photo-1527786356703-4b100091cd2c?w=800&q=80',
    category: 'Mountains',
    accentColor: Color(0xFF263238),
    flightCode: 'CJL',
    highlights: ['Tirich Mir', 'Kalash Festival', 'Shandur Polo'],
    description:
        'Chitral is home to Tirich Mir (7,708 m) — the highest peak of the Hindu Kush — and the ancient Kalash people, who maintain a unique pre-Islamic culture and colorful festivals.',
    bestTime: 'Apr – Oct',
  ),

  // ── BEACHES ────────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Clifton Beach',
    province: 'Sindh',
    tagline: 'Karachi\'s Most Popular Beach',
    imageUrl:
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF0277BD),
    flightCode: 'KHI',
    highlights: ['Sunset Views', 'Camel Rides', 'Sea View'],
    description:
        'Clifton Beach is Karachi\'s most iconic seafront along the Arabian Sea, stretching 5 km with vibrant street food, camel rides, and spectacular orange sunsets over the ocean.',
    bestTime: 'Nov – Feb',
  ),
  _PakDestination(
    name: 'French Beach',
    province: 'Sindh',
    tagline: 'Pristine Waters Near Karachi',
    imageUrl:
        'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF0288D1),
    flightCode: 'KHI',
    highlights: ['Clean Sand', 'Snorkeling', 'Family Picnics'],
    description:
        'French Beach is a secluded private paradise 25 km west of Karachi with crystal-clear turquoise water, fine golden sand, and excellent snorkeling among vibrant coral reefs.',
    bestTime: 'Oct – Mar',
  ),
  _PakDestination(
    name: 'Hawke\'s Bay',
    province: 'Sindh',
    tagline: 'Turtle Nesting Paradise',
    imageUrl:
        'https://images.unsplash.com/photo-1505142468610-359e7d316be0?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF01579B),
    flightCode: 'KHI',
    highlights: ['Turtle Watching', 'Wide Beach', 'Water Sports'],
    description:
        'Hawke\'s Bay is a protected beach famous as a nesting ground for endangered green sea turtles. Visitors can witness hatchlings during nesting season in a UNESCO-recognized habitat.',
    bestTime: 'Sep – Feb',
  ),
  _PakDestination(
    name: 'Sandspit Beach',
    province: 'Sindh',
    tagline: 'Protected Turtle Sanctuary',
    imageUrl:
        'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF006064),
    flightCode: 'KHI',
    highlights: ['Green Turtles', 'Nature Reserve', 'Peaceful'],
    description:
        'Sandspit is an 8 km protected sand-spit wildlife reserve where thousands of green and olive ridley turtles nest annually. A rare ecological treasure on Karachi\'s coastline.',
    bestTime: 'Aug – Jan',
  ),
  _PakDestination(
    name: 'Manora Island',
    province: 'Sindh',
    tagline: 'Historic Beach Island',
    imageUrl:
        'https://images.unsplash.com/photo-1532408840957-031d8034aeef?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF00838F),
    flightCode: 'KHI',
    highlights: ['Manora Fort', 'Lighthouse', 'Boat Ride'],
    description:
        'Manora Island is a historic peninsula accessible only by boat, housing a 19th-century lighthouse, colonial-era fort, and Hindu temples — a living slice of Karachi\'s multicultural past.',
    bestTime: 'Nov – Mar',
  ),
  _PakDestination(
    name: 'Paradise Point',
    province: 'Sindh',
    tagline: 'Karachi\'s Hidden Gem',
    imageUrl:
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF0097A7),
    flightCode: 'KHI',
    highlights: ['Rock Formations', 'Coral Reefs', 'Photography'],
    description:
        'Paradise Point is a dramatic natural rock arch jutting into the Arabian Sea, famous among photographers and nature lovers for its striking geology and serene seascape views.',
    bestTime: 'Oct – Mar',
  ),
  _PakDestination(
    name: 'Gwadar Beach',
    province: 'Balochistan',
    tagline: 'Pearl of the Arabian Sea',
    imageUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF00796B),
    flightCode: 'GWD',
    highlights: ['Hammerhead Rock', 'CPEC Port', 'Sunset Point'],
    description:
        'Gwadar is Pakistan\'s rising deep-sea port city on the Arabian Sea, strategically located at the mouth of the Persian Gulf. It blends untouched beaches with the ambition of a future megacity.',
    bestTime: 'Nov – Feb',
  ),
  _PakDestination(
    name: 'Ormara Beach',
    province: 'Balochistan',
    tagline: 'Golden Sands & Clear Waters',
    imageUrl:
        'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF00695C),
    flightCode: 'GWD',
    highlights: ['Turtle Point', 'Camping', 'Pristine Nature'],
    description:
        'Ormara is an unspoiled coastal gem in Balochistan with powder-white sand beaches, clear blue water, and designated turtle nesting areas — one of Pakistan\'s most pristine natural escapes.',
    bestTime: 'Nov – Feb',
  ),
  _PakDestination(
    name: 'Kund Malir',
    province: 'Balochistan',
    tagline: 'Desert Meets the Sea',
    imageUrl:
        'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF004D40),
    flightCode: 'KHI',
    highlights: ['Crystal Water', 'Desert Cliffs', 'Remote Beauty'],
    description:
        'Kund Malir is paradise where Makran\'s rust-coloured desert cliffs meet the crystal-blue Arabian Sea. It is one of the most remote and spectacular beach landscapes in all of Pakistan.',
    bestTime: 'Nov – Feb',
  ),
  _PakDestination(
    name: 'Pasni Beach',
    province: 'Balochistan',
    tagline: 'Coastal Fishing Town',
    imageUrl:
        'https://images.unsplash.com/photo-1505142468610-359e7d316be0?w=800&q=80',
    category: 'Beaches',
    accentColor: Color(0xFF1B5E20),
    flightCode: 'GWD',
    highlights: ['Fresh Seafood', 'Fishing Village', 'Boat Tours'],
    description:
        'Pasni is a traditional Balochi fishing town on the Makran coast known for its abundant marine life, fresh seafood, colourful fishing boats, and authentic coastal culture.',
    bestTime: 'Oct – Mar',
  ),

  // ── HISTORICAL ─────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Lahore',
    province: 'Punjab',
    tagline: 'Cultural Heart of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1584204687456-cbed5e3c1e82?w=800&q=80',
    category: 'Historical',
    accentColor: Color(0xFF880E4F),
    flightCode: 'LHE',
    highlights: ['Badshahi Mosque', 'Lahore Fort', 'Walled City'],
    description:
        'Lahore is Pakistan\'s cultural capital and second-largest city, home to Mughal architectural masterpieces including the Badshahi Mosque — one of the world\'s largest mosques — and a UNESCO-listed fort.',
    bestTime: 'Oct – Mar',
  ),
  _PakDestination(
    name: 'Peshawar',
    province: 'KPK',
    tagline: 'Ancient Gandhara Heritage',
    imageUrl:
        'https://images.unsplash.com/photo-1539136788836-5699e78bfc75?w=800&q=80',
    category: 'Historical',
    accentColor: Color(0xFF4A148C),
    flightCode: 'PEW',
    highlights: [
      'Qissa Khwani Bazaar',
      'Masjid Mahabat Khan',
      'Bala Hisar Fort'
    ],
    description:
        'Peshawar is one of the oldest cities in Asia, with over 2,500 years of recorded history. It was a major hub on the ancient Silk Road and centre of Gandharan Buddhist civilisation.',
    bestTime: 'Oct – Apr',
  ),
  _PakDestination(
    name: 'Mohenjo-daro',
    province: 'Sindh',
    tagline: 'Indus Valley Civilization',
    imageUrl:
        'https://images.unsplash.com/photo-1548705085-101177834f47?w=800&q=80',
    category: 'Historical',
    accentColor: Color(0xFF5D4037),
    flightCode: 'MJD',
    highlights: ['Great Bath', 'Dancing Girl', '4000-Year History'],
    description:
        'Mohenjo-daro is a UNESCO World Heritage Site and one of the earliest and largest urban settlements on Earth, dating back to 2500 BC — a 4,500-year-old city built with advanced town planning.',
    bestTime: 'Nov – Feb',
  ),
  _PakDestination(
    name: 'Taxila',
    province: 'Punjab',
    tagline: 'Ancient Buddhist City',
    imageUrl:
        'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=80',
    category: 'Historical',
    accentColor: Color(0xFF3E2723),
    flightCode: 'ISB',
    highlights: ['Dharmarajika Stupa', 'Taxila Museum', 'Jaulian'],
    description:
        'Taxila is a UNESCO World Heritage Site with ruins spanning 3,000 years, including the Dharmarajika Stupa — one of the most important Buddhist pilgrim sites in South Asia.',
    bestTime: 'Oct – Apr',
  ),

  // ── NATURE ─────────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Neelum Valley',
    province: 'AJK',
    tagline: 'Jewel of Azad Kashmir',
    imageUrl:
        'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800&q=80',
    category: 'Nature',
    accentColor: Color(0xFF1B5E20),
    flightCode: 'ISB',
    highlights: ['Neelum River', 'Arang Kel', 'Ratti Gali Lake'],
    description:
        'Neelum Valley stretches 200 km along the turquoise Neelum River in Azad Kashmir, flanked by dense pine forests and snowy peaks. Arang Kel is accessible only by cable car and is utterly pristine.',
    bestTime: 'May – Oct',
  ),
  _PakDestination(
    name: 'Deosai Plains',
    province: 'Gilgit-Baltistan',
    tagline: 'World\'s 2nd Highest Plateau',
    imageUrl:
        'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=800&q=80',
    category: 'Nature',
    accentColor: Color(0xFF33691E),
    flightCode: 'SKZ',
    highlights: ['Brown Bears', 'Wildflower Meadows', 'Sheosar Lake'],
    description:
        'Deosai Plains at 4,114 m is the world\'s second highest plateau and a national park, home to the endangered Himalayan brown bear, millions of wildflowers, and the stunning Sheosar Lake.',
    bestTime: 'Jul – Sep',
  ),
  _PakDestination(
    name: 'Quetta',
    province: 'Balochistan',
    tagline: 'City of Fruit Gardens',
    imageUrl:
        'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=800&q=80',
    category: 'Nature',
    accentColor: Color(0xFF558B2F),
    flightCode: 'UET',
    highlights: ['Hanna Lake', 'Hazarganji Chiltan', 'Quaid Residency'],
    description:
        'Quetta, the \'Fruit Garden of Pakistan\', sits at 1,680 m elevation surrounded by barren mountains. It is known for its apple orchards, juniper forests, and the endangered Chiltan wild goat.',
    bestTime: 'Mar – May, Sep – Nov',
  ),

  // ── CITIES ─────────────────────────────────────────────────────────────────
  _PakDestination(
    name: 'Islamabad',
    province: 'Federal Capital',
    tagline: 'Modern Green Capital',
    imageUrl:
        'https://images.unsplash.com/photo-1578895101408-1a36b834405b?w=800&q=80',
    category: 'Cities',
    accentColor: Color(0xFF1A237E),
    flightCode: 'ISB',
    highlights: ['Faisal Mosque', 'Daman-e-Koh', 'Margalla Hills'],
    description:
        'Islamabad is one of the greenest and most planned capital cities in the world, ranked among the top 10 most beautiful capitals globally, bordered by the lush Margalla Hills National Park.',
    bestTime: 'Oct – Apr',
  ),
  _PakDestination(
    name: 'Multan',
    province: 'Punjab',
    tagline: 'City of Saints',
    imageUrl:
        'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
    category: 'Cities',
    accentColor: Color(0xFFE65100),
    flightCode: 'MUX',
    highlights: ['Bahauddin Zakariya Shrine', 'Multan Fort', 'Blue Pottery'],
    description:
        'Multan, over 5,000 years old, is one of the oldest cities in the world and the \'City of Saints\' — home to hundreds of Sufi shrines, iconic blue glazed pottery, and world-famous mangoes.',
    bestTime: 'Oct – Mar',
  ),
  _PakDestination(
    name: 'Faisalabad',
    province: 'Punjab',
    tagline: 'Industrial Hub & Textile City',
    imageUrl:
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
    category: 'Cities',
    accentColor: Color(0xFF827717),
    flightCode: 'LYP',
    highlights: ['Clock Tower', 'Lyallpur Museum', 'Food Street'],
    description:
        'Faisalabad is Pakistan\'s third-largest city and the textile capital of Asia. Its famous British-era Clock Tower stands at the centre of 8 bazaars laid out in the pattern of the Union Jack flag.',
    bestTime: 'Nov – Mar',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Explore Destinations Section Widget
// ─────────────────────────────────────────────────────────────────────────────
class ExploreDestinationsSection extends StatelessWidget {
  final String selectedCategory;

  const ExploreDestinationsSection({
    super.key,
    required this.selectedCategory,
  });

  List<_PakDestination> get _filtered {
    if (selectedCategory == 'All') return _pakDestinations;
    return _pakDestinations
        .where((d) => d.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _filtered;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final crossCount = isDesktop ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCategory == 'All'
                        ? 'Explore Pakistan'
                        : '$selectedCategory in Pakistan',
                    style: TravelloTheme.title2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacingUnit(0.3)),
                  Text(
                    '${destinations.length} destinations',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          colorScheme(context).onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const Icon(
                CupertinoIcons.map,
                color: TravelloTheme.primaryMain,
                size: 20,
              ),
            ],
          ),
        ),

        // Grid of destination cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              return _DestinationCard(destination: destinations[index]);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual destination card  –  flips on tap to reveal facts
// ─────────────────────────────────────────────────────────────────────────────
class _DestinationCard extends StatefulWidget {
  final _PakDestination destination;

  const _DestinationCard({required this.destination});

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _showingFront = !_showingFront);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final angle = _animation.value * pi;
        final isFrontVisible = angle < pi / 2;

        return GestureDetector(
          onTap: _flip,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFrontVisible
                ? _buildFront(context)
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildBack(context),
                  ),
          ),
        );
      },
    );
  }

  // ── Front face ────────────────────────────────────────────────────────────
  Widget _buildFront(BuildContext context) {
    final d = widget.destination;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: d.accentColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.network(
                d.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: d.accentColor),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: d.accentColor.withValues(alpha: 0.4),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Tap-hint icon (top-right)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),

            // Category badge (top-left)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: d.accentColor.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.category,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Bottom content
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.province.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.tagline,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: d.highlights
                        .take(2)
                        .map((h) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Back face ─────────────────────────────────────────────────────────────
  Widget _buildBack(BuildContext context) {
    final d = widget.destination;

    // derive a lighter tint for background layers
    final bgDark = d.accentColor;
    final bgLight = Color.lerp(d.accentColor, Colors.black, 0.45)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgLight, bgDark],
        ),
        boxShadow: [
          BoxShadow(
            color: d.accentColor.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle translucent pattern circles (decorative)
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: category + flip-back hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          d.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _flip,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Destination name
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Province
                  Text(
                    d.province,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),

                  const SizedBox(height: 7),

                  // Divider
                  Divider(
                    color: Colors.white.withValues(alpha: 0.2),
                    height: 1,
                    thickness: 0.5,
                  ),

                  const SizedBox(height: 7),

                  // Description
                  Expanded(
                    child: Text(
                      d.description,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.45,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Highlights (all 3)
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: d.highlights
                        .map((h) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 6),

                  // Best time row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 9,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Best time: ',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        d.bestTime,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
