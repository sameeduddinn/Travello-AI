import 'package:flight_app/models/ai_chat.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Send button with hover scale effect
// ─────────────────────────────────────────────────────────────────────────────
class _SendButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;
  const _SendButton(
      {required this.onPressed,
      required this.backgroundColor,
      required this.iconColor});
  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: _hovered ? 0.4 : 0.2),
                blurRadius: _hovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            onPressed: widget.onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Itinerary data model
// ─────────────────────────────────────────────────────────────────────────────
class _DayPlan {
  final int day;
  final String title;
  final IconData icon;
  final List<String> activities;
  const _DayPlan(
      {required this.day,
      required this.title,
      required this.icon,
      required this.activities});
}

class _TripItinerary {
  final String destination;
  final String province;
  final String imageUrl;
  final String style;
  final int duration;
  final String budget;
  final List<_DayPlan> days;
  final DateTime? savedDate;
  const _TripItinerary({
    required this.destination,
    required this.province,
    required this.imageUrl,
    required this.style,
    required this.duration,
    required this.budget,
    required this.days,
    this.savedDate,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Itinerary database by destination
// ─────────────────────────────────────────────────────────────────────────────
Map<String, List<_DayPlan>> _itineraryDB = {
  'Hunza Valley': [
    const _DayPlan(
        day: 1,
        title: 'Arrival in Gilgit',
        icon: Icons.flight_takeoff,
        activities: [
          'Land at Gilgit Airport',
          'Drive to Karimabad (2.5 hrs)',
          'Check into hotel & rest',
          'Evening stroll at Karimabad Bazaar'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Attabad Lake & Hopper Glacier',
        icon: Icons.terrain,
        activities: [
          'Morning: Attabad Lake boat ride',
          'Visit Hopper Glacier',
          'Lunch at lakeside café',
          'Visit Karakoram Highway viewpoints'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Baltit Fort & Eagle\'s Nest',
        icon: Icons.account_balance,
        activities: [
          'Explore Baltit Fort (UNESCO)',
          'Visit Altit Fort',
          'Hike to Eagle\'s Nest viewpoint',
          'Sunset photography over Hunza River'
        ]),
    const _DayPlan(
        day: 4,
        title: 'Rakaposhi Viewpoint',
        icon: Icons.terrain,
        activities: [
          'Drive to Rakaposhi Base Camp',
          'Cherry blossom orchard walk',
          'Visit Nilt & Diran villages',
          'Traditional Hunza cuisine dinner'
        ]),
    const _DayPlan(day: 5, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Khunjerab Pass day trip (optional)',
      'Souvenir shopping for dry fruits & gems',
      'Drive back to Gilgit Airport',
      'Depart with lifetime memories'
    ]),
  ],
  'Skardu': [
    const _DayPlan(
        day: 1,
        title: 'Arrival in Skardu',
        icon: Icons.flight_takeoff,
        activities: [
          'Land at Skardu Airport',
          'Visit Skardu Bazaar',
          'Check-in & settle',
          'Shangrila Resort evening visit'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Shangrila & Kachura Lakes',
        icon: Icons.park,
        activities: [
          'Upper & Lower Kachura Lakes',
          'Row boat at Shangrila Resort',
          'Visit Manthal Buddha Rock',
          'Sunset at Skardu Fort'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Deosai National Park',
        icon: Icons.park,
        activities: [
          'Early morning drive to Deosai (2,800m altitude)',
          'Brown bear safari',
          'Wildflower meadow walk',
          'Sheosar Lake photography'
        ]),
    const _DayPlan(
        day: 4,
        title: 'K2 Base Camp Viewpoint',
        icon: Icons.terrain,
        activities: [
          'Drive toward Concordia area',
          'Baltoro Glacier viewpoint',
          'Jeep safari on Indus River banks',
          'Stargazing night (no light pollution)'
        ]),
    const _DayPlan(day: 5, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Satpara Lake visit',
      'Local gem & mineral shopping',
      'Drive to Skardu Airport',
      'Depart Skardu'
    ]),
  ],
  'Lahore': [
    const _DayPlan(
        day: 1,
        title: 'Mughal Heritage',
        icon: Icons.account_balance,
        activities: [
          'Badshahi Mosque (largest mosque in Pakistan)',
          'Lahore Fort & Sheesh Mahal',
          'Hazuri Bagh gardens',
          'Dinner at Cooco\'s Den restaurant'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Walled City & Food Street',
        icon: Icons.restaurant,
        activities: [
          'Morning: Walled City walking tour',
          'Aurangzeb Mosque & Wazir Khan Mosque',
          'Fort Road Food Street lunch',
          'Anarkali Bazaar shopping'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Colonial Lahore & Museums',
        icon: Icons.account_balance,
        activities: [
          'Lahore Museum (largest museum in Pakistan)',
          'Aitchison College & Mall Road',
          'Packages Mall & Liberty Market',
          'Tikka Gali dinner at Burns Road'
        ]),
  ],
  'Islamabad': [
    const _DayPlan(
        day: 1,
        title: 'Faisal Mosque & Margalla Hills',
        icon: Icons.account_balance,
        activities: [
          'Faisal Mosque (4th largest in world)',
          'Daman-e-Koh viewpoint',
          'Trail 3 Margalla Hills hike',
          'Centaurus Mall evening'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Rawalpindi & Heritage',
        icon: Icons.account_balance,
        activities: [
          'Pakistan Monument & Museum',
          'Lok Virsa Museum',
          'Raja Bazaar Rawalpindi',
          'Ayub National Park'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Murree Day Trip',
        icon: Icons.park,
        activities: [
          'Drive to Murree hill station (1 hr)',
          'Mall Road stroll & local shopping',
          'Pindi Point chairlift ride',
          'Pine forests walk & sunset photography'
        ]),
  ],
  'Swat Valley': [
    const _DayPlan(
        day: 1,
        title: 'Arrival in Mingora',
        icon: Icons.flight_takeoff,
        activities: [
          'Arrive at Saidu Sharif Airport or drive from Peshawar',
          'Swat Museum — Gandhara Buddhist art & artefacts',
          'Explore Mingora Green Chowk Bazaar',
          'Traditional Pashtun dinner at local restaurant'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Malam Jabba Ski Resort',
        icon: Icons.ac_unit,
        activities: [
          'Drive to Malam Jabba (45 km from Mingora)',
          'Chairlift ride for panoramic Hindukush views',
          'Ancient Buddhist ruins at Butkara Stupa',
          'Fizagat Park riverside evening picnic'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Kalam Valley',
        icon: Icons.terrain,
        activities: [
          'Scenic drive to Kalam (85 km along Swat River)',
          'Ushu Forest — towering pine & fir trees',
          'Mahodand Lake boat ride (16 km from Kalam)',
          'Overnight at Kalam guesthouse'
        ]),
    const _DayPlan(
        day: 4,
        title: 'Bahrain & River Rafting',
        icon: Icons.beach_access,
        activities: [
          'White-water rafting on Swat River at Bahrain',
          'Trout fishing at Swat River banks',
          'Mingora Night Bazaar — Swati gemstones & crafts',
          'Saidu Baba historic shrine visit'
        ]),
    const _DayPlan(day: 5, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Saidu Sharif royal mosque visit',
      'Last shopping — Swati embroidery & emerald gems',
      'Drive back to Peshawar or fly home',
      'Depart Swat Valley'
    ]),
  ],
  'Naran & Kaghan': [
    const _DayPlan(
        day: 1,
        title: 'Drive to Naran',
        icon: Icons.flight_takeoff,
        activities: [
          'Drive from Islamabad via Mansehra to Naran (5 hrs)',
          'Kunhar River gorge — dramatic roadside views',
          'Check into Naran & explore the town',
          'Traditional Kaghan Valley dinner'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Saif-ul-Malook Lake',
        icon: Icons.star,
        activities: [
          'Jeep ride to Saif-ul-Malook Lake (3,224 m)',
          'Pakistan\'s most photographed turquoise lake',
          'Photography with Malika Parbat snow peak',
          'Trek around the lake (2 hr loop)'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Lulusar & Babusar Pass',
        icon: Icons.terrain,
        activities: [
          'Drive to Lulusar Lake — mirror-like reflections',
          'Cross Babusar Pass (4,173 m altitude)',
          'Panoramic views of Nanga Parbat',
          'Return to Naran for dinner'
        ]),
    const _DayPlan(day: 4, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Batakundi meadows stroll',
      'Ansoo (Teardrop) Lake viewpoint trail',
      'Drive back to Islamabad',
      'Depart Kaghan Valley'
    ]),
  ],
  'Fairy Meadows': [
    const _DayPlan(
        day: 1,
        title: 'Raikot Bridge Trek Start',
        icon: Icons.flight_takeoff,
        activities: [
          'Drive from Gilgit to Raikot Bridge (80 km)',
          'Jeep ride to Tato Village (rough mountain track)',
          'Begin 3-hour scenic trek to Fairy Meadows',
          'First spectacular view of Nanga Parbat (8,126 m)'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Nanga Parbat Base Camp Trek',
        icon: Icons.terrain,
        activities: [
          'Stunning sunrise view of Nanga Parbat "Killer Mountain"',
          'Trek to Beyal Base Camp (4 hrs round-trip)',
          'Alpine wildflowers & glacial moraine walk',
          'Campfire storytelling with local Kashmiri guides'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Panorama & Departure',
        icon: Icons.home,
        activities: [
          'Golden hour mountain photography at dawn',
          'Explore Fairy Meadows higher viewpoints',
          'Trek down to Raikot Bridge',
          'Drive back to Gilgit town'
        ]),
  ],
  'Gilgit': [
    const _DayPlan(
        day: 1,
        title: 'Gilgit City & Rock Carvings',
        icon: Icons.flight_takeoff,
        activities: [
          'Arrive at Gilgit Airport',
          'Kargah Buddha Rock Carving (7th century CE)',
          'Gilgit Bazaar — dry fruits, gems & local spices',
          'Traditional Dumpukht lamb dinner'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Naltar Valley',
        icon: Icons.terrain,
        activities: [
          'Drive to Naltar Valley (40 km, 1.5 hrs)',
          'Three colourful Naltar Lakes (blue, green & turquoise)',
          'Naltar Ski Resort viewpoints (year-round)',
          'Pine forest picnic & wildlife spotting'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Rakaposhi & KKH',
        icon: Icons.terrain,
        activities: [
          'Drive on Karakoram Highway (8th Wonder of the world)',
          'Rakaposhi Base Camp viewpoint (7,788 m peak)',
          'Nilt Fort & ancient Chinese fort ruins',
          'Return to Gilgit for Sajji dinner'
        ]),
  ],
  'Chitral': [
    const _DayPlan(
        day: 1,
        title: 'Arrival in Chitral',
        icon: Icons.flight_takeoff,
        activities: [
          'Fly Islamabad → Chitral or drive via Lowari Tunnel',
          'Chitral Fort (Royal Palace of Mehtars)',
          'Shahi Mosque — royal mosque of Chitral royalty',
          'Browse Kalash crafts at local bazaar'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Kalash Valleys',
        icon: Icons.palette,
        activities: [
          'Drive to Bumburet Valley — Kalash homeland (35 km)',
          'Meet the unique pre-Islamic Kalash people',
          'Kalash Museum & traditional wooden houses',
          'Witness traditional Kalash folk dances & festivals'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Shandur Polo Ground',
        icon: Icons.sports_hockey,
        activities: [
          'Drive toward Shandur Top (3,734 m)',
          'World\'s highest polo ground',
          'Shandur Lake panorama',
          'Return to Chitral for traditional dinner'
        ]),
    const _DayPlan(day: 4, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Mastuj Fort ruins exploration',
      'Chitrali cap (Pakol) & wool shawl shopping',
      'Fly or drive back to Islamabad',
      'Depart Chitral'
    ]),
  ],
  'Gwadar': [
    const _DayPlan(
        day: 1,
        title: 'Arrival & CPEC Port',
        icon: Icons.flight_takeoff,
        activities: [
          'Arrive at Gwadar International Airport',
          'Gwadar Deep Sea Port overview (CPEC mega-project)',
          'Padi Zirr Beach sunset & pebble shores',
          'Fresh catch seafood dinner at Gwadar Fish Harbour'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Hammerhead & Beaches',
        icon: Icons.beach_access,
        activities: [
          'Hammerhead Point — dramatic cliffs over Arabian Sea',
          'Princess of Hope rock arch formation',
          'Snorkelling at Pasni Beach',
          'Gwadar New Town promenade sunset walk'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Marine Drive & Departure',
        icon: Icons.home,
        activities: [
          'Gwadar Marine Drive — iconic seaside boulevard',
          'Mirani Dam viewpoint',
          'Local Balochi seafood brunch (Sajji fish)',
          'Fly back to Karachi or Islamabad'
        ]),
  ],
  'Karachi': [
    const _DayPlan(
        day: 1,
        title: 'Historic Karachi',
        icon: Icons.location_city,
        activities: [
          'Quaid-e-Azam Mausoleum — Founder\'s resting place',
          'Frere Hall colonial heritage building & library',
          'Clifton Beach & Sea View promenade',
          'Burns Road food street — best nihari & haleem'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Beaches & Bazaars',
        icon: Icons.beach_access,
        activities: [
          'French Beach & Hawkes Bay Sea Turtle Sanctuary',
          'Manora Island boat trip',
          'Port Grand waterfront dining complex',
          'Zainab Market & Tariq Road shopping'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Museums & Culture',
        icon: Icons.account_balance,
        activities: [
          'National Museum of Pakistan',
          'Pakistan Maritime Museum',
          'Empress Market colonial architecture',
          'Boat Basin food street — BBQ & karahi dinner'
        ]),
  ],
  'Peshawar': [
    const _DayPlan(
        day: 1,
        title: 'Old Peshawar City',
        icon: Icons.account_balance,
        activities: [
          'Bala Hisar Fort (Shahi Qila) over the city',
          'Qissa Khawani Bazaar — 2,000-year-old Storytellers\' Market',
          'Mahabat Khan Mosque (Mughal architecture)',
          'Traditional Chapli Kebab dinner at Namak Mandi'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Gandhara Ruins & Khyber Pass',
        icon: Icons.account_balance,
        activities: [
          'Peshawar Museum — finest Gandhara Buddhist art collection',
          'Takht-i-Bahi Buddhist monastery ruins (UNESCO)',
          'Khyber Pass gateway view (permit required)',
          'Bara Bazaar — traditional Pashtun goods & antiques'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Valley & Departure',
        icon: Icons.home,
        activities: [
          'Pushkalavati ancient Gandhara ruins at Charsadda',
          'University Town for modern cafes & culture',
          'Last shopping for Peshwari chappal (sandals)',
          'Depart Peshawar'
        ]),
  ],
  'Multan': [
    const _DayPlan(
        day: 1,
        title: 'City of Saints & Shrines',
        icon: Icons.account_balance,
        activities: [
          'Shrine of Bahauddin Zakariya (13th-century Sufi saint)',
          'Shrine of Shah Rukn-e-Alam (iconic blue-tiled dome)',
          'Multan Fort Old City walls',
          'Traditional Multani sohan halwa & famous mangoes'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Crafts & Culture',
        icon: Icons.palette,
        activities: [
          'Multan Craft Village — famous blue tile pottery workshop',
          'Camel skin lamp & lacquer handicraft shopping',
          'Multan Museum archaeological exhibits',
          'Hussein Agahi historic street market dinner'
        ]),
    const _DayPlan(day: 3, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Tomb of Shah Shams Tabriz (13th century)',
      'Mango garden visit (peak season May–July)',
      'Fly or drive to Islamabad/Lahore',
      'Depart Multan — City of Saints'
    ]),
  ],
  'Quetta': [
    const _DayPlan(
        day: 1,
        title: 'Arrival & Quetta City',
        icon: Icons.flight_takeoff,
        activities: [
          'Arrive at Quetta Airport',
          'Hanna Lake — serene blue reservoir',
          'Balochistan Museum & archaeological finds',
          'Liaquat Bazaar — best dried fruits & nuts in Pakistan'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Ziarat Valley',
        icon: Icons.park,
        activities: [
          'Drive to Ziarat (130 km) — world\'s 2nd largest juniper forest',
          'Quaid-e-Azam Residency (historic colonial villa)',
          'Apple & cherry orchards of Ziarat Valley',
          'Kach Pass scenic mountain drive'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Urak Valley & Departure',
        icon: Icons.home,
        activities: [
          'Urak Valley fruit orchards & spring camping',
          'Spin Karez crystal-clear freshwater pools',
          'Local Balochi Sajji & Kaak bread for brunch',
          'Fly back to Karachi or Islamabad'
        ]),
  ],
  'Neelum Valley': [
    const _DayPlan(
        day: 1,
        title: 'Arrival in Muzaffarabad',
        icon: Icons.flight_takeoff,
        activities: [
          'Drive from Islamabad to Muzaffarabad (140 km)',
          'Muzaffarabad Red Fort ruins',
          'Neelum River–Jhelum River confluence viewpoint',
          'AJK traditional dinner'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Sharda & Upper Neelum',
        icon: Icons.terrain,
        activities: [
          'Drive along scenic Neelum Valley Road gorge',
          'Sharda University ruins (ancient Sanskrit institution)',
          'Keran village — trees overhanging turquoise river',
          'Kel village bridge & river crossing'
        ]),
    const _DayPlan(
        day: 3,
        title: 'Arang Kel Meadow',
        icon: Icons.park,
        activities: [
          'Boat across Neelum River at Kel',
          'Trek to Arang Kel village (1.5 hrs ascent)',
          'Pristine meadow with untouched snow-capped peaks',
          'Overnight camping or return to Kel guesthouse'
        ]),
    const _DayPlan(day: 4, title: 'Departure', icon: Icons.home, activities: [
      'Morning: Ratti Gali Lake day hike (seasonal)',
      'Shounter Pass scenic drive viewpoint',
      'Drive back to Muzaffarabad & Islamabad',
      'Depart Neelum Valley'
    ]),
  ],
  'Taxila': [
    const _DayPlan(
        day: 1,
        title: 'Ancient Gandhara Ruins',
        icon: Icons.account_balance,
        activities: [
          'Taxila Museum — largest Gandhara collection in Pakistan',
          'Sirkap archaeological site (Hellenistic city, 2nd c. BC)',
          'Jaulian Buddhist monastery with 117 intricately carved stupas',
          'Easy 45-min drive from Islamabad — ideal day trip'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Khanpur & Return',
        icon: Icons.water_drop,
        activities: [
          'Khanpur Dam — water sports & boating',
          'Khanpur Caves exploration',
          'Margalla Pass historic Mughal gateway',
          'Return to Islamabad for dinner'
        ]),
  ],
  'Mohenjo-daro': [
    const _DayPlan(
        day: 1,
        title: 'UNESCO World Heritage Site',
        icon: Icons.account_balance,
        activities: [
          'Fly to Mohenjo-daro Airport or drive from Sukkur',
          'Great Bath — world\'s first ever public bath (2500 BC)',
          'Granary, Assembly Hall & ancient streets exploration',
          'Mohenjo-daro Museum — 4,500-year-old Indus Valley artefacts'
        ]),
    const _DayPlan(
        day: 2,
        title: 'Indus Civilisation & Departure',
        icon: Icons.home,
        activities: [
          'Lower Town ruins & private residential quarters',
          'Buddhist Stupa mound (2nd century AD)',
          'Sindhi Ajrak & handicraft shopping in Larkana city',
          'Drive or fly back from Sukkur'
        ]),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _dotController;
  late AnimationController _entryController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // ── Hover state ────────────────────────────────────────────────────────────
  int _hoveredSuggestion = -1;

  // ── Chat state ─────────────────────────────────────────────────────────────
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String? _conversationId;
  String? _pendingAction;
  Map<String, dynamic>? _pendingBookingData;

  static const _kConvIdKey = 'ai_conversation_id';

  // ── Saved Trips state ──────────────────────────────────────────────────────
  final List<_TripItinerary> _savedTrips = [
    _TripItinerary(
      destination: 'Hunza Valley',
      province: 'Gilgit-Baltistan',
      imageUrl:
          'https://images.unsplash.com/photo-1587474260584-136574528ed5?w=800&q=80',
      style: 'Adventure',
      duration: 5,
      budget: 'Mid-range',
      savedDate: DateTime(2026, 3, 10),
      days: _itineraryDB['Hunza Valley']!,
    ),
    _TripItinerary(
      destination: 'Lahore',
      province: 'Punjab',
      imageUrl:
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
      style: 'Cultural',
      duration: 3,
      budget: 'Budget',
      savedDate: DateTime(2026, 2, 20),
      days: _itineraryDB['Lahore']!,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _loadConversationState();
  }

  // ── Conversation persistence ───────────────────────────────────────────────

  Future<void> _loadConversationState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kConvIdKey);

    if (savedId == null) {
      _addWelcomeMessage();
      return;
    }

    setState(() => _isLoadingHistory = true);
    try {
      final msgs = await ApiClient.getAgentMessages(savedId);
      if (!mounted) return;
      if (msgs.isEmpty) {
        _addWelcomeMessage();
      } else {
        setState(() {
          _conversationId = savedId;
          for (final m in msgs) {
            final role = m['role'] as String? ?? 'assistant';
            final content = m['content'] as String? ?? '';
            if (content.isEmpty) continue;
            _messages.add(ChatMessage(
              id: m['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
              message: content,
              isUser: role == 'user',
              timestamp: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
            ));
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) _addWelcomeMessage();
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _addWelcomeMessage() {
    if (_messages.isNotEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: '1',
        message: "Hello! 👋 I'm your AI Travel Assistant for Pakistan. How can I help you plan your journey today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _fetchAndShowProactiveAlert();
  }

  Future<void> _fetchAndShowProactiveAlert() async {
    try {
      final alert = await ApiClient.getProactiveAlert();
      if (!mounted || alert == null) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          message: alert,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConvIdKey, id);
  }

  Future<void> _startNewChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConvIdKey);
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
    _addWelcomeMessage();
  }

  // ── Payment choice handlers ────────────────────────────────────────────────

  void _clearPendingAction() => setState(() {
        _pendingAction = null;
        _pendingBookingData = null;
      });

  void _showCardPaymentSheet() {
    if (_pendingBookingData == null || _conversationId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardPaymentSheet(
        bookingData: _pendingBookingData!,
        conversationId: _conversationId!,
        onSuccess: (pnr, amount) {
          _clearPendingAction();
          setState(() {
            _messages.add(ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              message: '✅ **Booking Confirmed!**\n\n'
                  '**PNR:** $pnr\n'
                  '**Amount Paid:** PKR ${amount.toStringAsFixed(0)}\n\n'
                  'A confirmation email has been sent to you. '
                  'You can view your booking in **My Bookings**.',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
        },
        onCancel: _clearPendingAction,
      ),
    );
  }

  void _navigateToManualPayment() {
    final data = _pendingBookingData;
    _clearPendingAction();
    final type = data?['booking_type'] as String? ?? 'flight';
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: 'No problem! Go to the **${type[0].toUpperCase()}${type.substring(1)}s** tab, '
            'select your option, and complete payment securely. '
            'Your booking details are saved above for reference. 🎯',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  Widget _buildPaymentButtons() {
    const gold = Color(0xFFD4AF37);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose payment method:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCardPaymentSheet,
                  icon: const Icon(Icons.credit_card_rounded,
                      size: 18, color: Colors.white),
                  label: const Text(
                    'Pay with Card',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _navigateToManualPayment,
                  icon: Icon(Icons.open_in_new_rounded,
                      size: 18, color: Colors.grey.shade700),
                  label: Text(
                    'Pay Manually',
                    style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConversationsSheet() async {
    List<Map<String, dynamic>> conversations = [];
    try {
      conversations = await ApiClient.getAgentConversations();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConversationsSheet(
        conversations: conversations,
        currentId: _conversationId,
        onSelect: (id) async {
          Navigator.pop(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kConvIdKey, id);
          setState(() {
            _conversationId = null;
            _messages.clear();
          });
          await _loadConversationState();
        },
        onDelete: (id) async {
          await ApiClient.deleteAgentConversation(id);
          if (id == _conversationId) await _startNewChat();
        },
        onNewChat: () {
          Navigator.pop(context);
          _startNewChat();
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dotController.dispose();
    _entryController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: Column(
        children: [
          // ── Premium header with depth ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1400),
                  Color(0xFF3D2B00),
                  Color(0xFF5C4200),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white70, size: 18),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    // Animated AI logo
                    SlideTransition(
                      position: _headerSlide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFD4AF37),
                                Color(0xFFE8C76A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.smart_toy_rounded,
                                  color: Colors.white, size: 22),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerFade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Travello ',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    'AI',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD4AF37),
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Online  •  Your Pakistan travel planner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white
                                          .withValues(alpha: 0.55),
                                      letterSpacing: 0.3,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // History + New Chat buttons
                    IconButton(
                      tooltip: 'Conversation History',
                      icon: const Icon(Icons.history_rounded,
                          color: Colors.white70, size: 22),
                      onPressed: _showConversationsSheet,
                    ),
                    IconButton(
                      tooltip: 'New Chat',
                      icon: const Icon(Icons.add_comment_outlined,
                          color: Colors.white70, size: 22),
                      onPressed: _startNewChat,
                    ),
                  ],
                ),   // Row
              ),     // Padding
            ),       // SafeArea
          ),         // Container
          // ── TabBar ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD4AF37),
              indicatorWeight: 3,
              labelColor: const Color(0xFFD4AF37),
              unselectedLabelColor: Colors.grey.shade400,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                    icon: Icon(Icons.chat_rounded, size: 20),
                    text: 'Chat'),
                Tab(
                    icon: Icon(CupertinoIcons.bookmark_fill, size: 18),
                    text: 'Saved'),
              ],
            ),
          ),
          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(),
                _buildSavedTripsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — CHAT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildChatTab() {
    final showSuggestions = _messages.length == 1 && !_isTyping;
    return Column(
      children: [
        if (_isLoadingHistory)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: Color(0xFFD4AF37),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length +
                (_isTyping ? 1 : 0) +
                (showSuggestions ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _messages.length) {
                return _buildMessageBubble(_messages[index]);
              }
              if (_isTyping && index == _messages.length) {
                return _buildTypingIndicator();
              }
              if (showSuggestions) {
                return _buildSuggestions();
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        if (_pendingAction == 'payment_choice') _buildPaymentButtons(),
        if (_pendingAction != 'payment_choice') _buildInputField(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isFirst = _messages.indexOf(message) == 0 && !message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(isFirst ? 16 : 13),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFF2D2000)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isUser
                  ? Text(
                      message.message,
                      style: TravelloTheme.paragraph.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  : MarkdownBody(
                      data: message.message,
                      styleSheet: MarkdownStyleSheet(
                        p: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: isFirst ? 14.5 : 14,
                          height: 1.5,
                        ),
                        strong: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: isFirst ? 14.5 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                        em: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TravelloTheme.paragraph.copyWith(
                          color: TravelloTheme.textPrimary,
                          fontSize: 14,
                        ),
                        blockquotePadding: const EdgeInsets.only(left: 8),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFD4AF37),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      shrinkWrap: true,
                    ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2D2000),
              child: Icon(Icons.person, color: Color(0xFFD4AF37), size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD4AF37), Color(0xFFE8C76A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 5),
                _buildDot(1),
                const SizedBox(width: 5),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        final double phase = (_dotController.value - index / 3.0 + 1.0) % 1.0;
        final double opacity = phase < 0.5 ? phase * 2 : (1.0 - phase) * 2;
        return Opacity(
          opacity: 0.3 + opacity * 0.7,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: TravelloTheme.primaryMain, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    final suggestions = AIAssistantData.getSuggestions();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 6),
                Text('Try asking:',
                    style: TravelloTheme.caption.copyWith(
                        color: TravelloTheme.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 10),
            ...suggestions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isHovered = _hoveredSuggestion == i;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 350 + i * 60),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - v), 0),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) =>
                        setState(() => _hoveredSuggestion = i),
                    onExit: (_) =>
                        setState(() => _hoveredSuggestion = -1),
                    child: GestureDetector(
                      onTap: () => _sendMessage(s.title),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? const Color(0xFFFFF8E7)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHovered
                                ? const Color(0xFFD4AF37)
                                : Colors.grey.shade200,
                            width: isHovered ? 1.5 : 1,
                          ),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFFF5F0E6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(s.icon,
                                  size: 16,
                                  color: const Color(0xFFD4AF37)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: isHovered
                                      ? const Color(0xFF2D2000)
                                      : TravelloTheme.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 12,
                                color: isHovered
                                    ? const Color(0xFFD4AF37)
                                    : Colors.grey.shade300),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me about your trip...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: _sendMessage,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SendButton(
                  onPressed: () => _sendMessage(_messageController.text.trim()),
                  backgroundColor: const Color(0xFFD4AF37),
                  iconColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: text,
          isUser: true,
          timestamp: DateTime.now()));
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final result = await ApiClient.agentChat(
        message: text,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      final newConvId = result['conversation_id'] as String?;
      if (newConvId != null && newConvId != _conversationId) {
        _conversationId = newConvId;
        _saveConversationId(newConvId);
      }
      setState(() {
        _pendingAction = result['action'] as String?;
        _pendingBookingData = result['booking_data'] != null
            ? Map<String, dynamic>.from(result['booking_data'] as Map)
            : null;
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: result['response'] as String? ?? 'Sorry, I could not process that.',
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Something went wrong. Please check your connection and try again.',
            isUser: false,
            timestamp: DateTime.now()));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }


  Widget _buildDayCard(_DayPlan day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLightContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colorScheme(context).outline.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: Center(
              child: Icon(
            day.icon,
            size: 18,
            color: TravelloTheme.primaryMain,
          )),
        ),
        title: Text('Day ${day.day}: ${day.title}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        initiallyExpanded: day.day == 1,
        clipBehavior: Clip.none,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: day.activities
            .map((activity) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          decoration: const BoxDecoration(
                              color: TravelloTheme.primaryMain,
                              shape: BoxShape.circle)),
                      Expanded(
                          child: Text(activity,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — SAVED TRIPS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSavedTripsTab() {
    if (_savedTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.bookmark,
                size: 64, color: colorScheme(context).outline),
            const SizedBox(height: 16),
            const Text('No saved trips yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Ask the AI assistant to plan a trip for you',
                style: TextStyle(
                    color:
                        colorScheme(context).onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row with count + Clear All
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(
            children: [
              Text(
                '${_savedTrips.length} saved ${_savedTrips.length == 1 ? 'trip' : 'trips'}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        colorScheme(context).onSurface.withValues(alpha: 0.55)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all saved trips?'),
                      content: const Text(
                          'This will remove all your saved trip plans. This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _savedTrips.clear());
                            Navigator.pop(ctx);
                          },
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear all', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.withValues(alpha: 0.8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // Trip list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _savedTrips.length,
            itemBuilder: (context, index) {
              final trip = _savedTrips[index];
              return _buildSavedTripCard(trip, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedTripCard(_TripItinerary trip, int index) {
    return Dismissible(
      key: Key('${trip.destination}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => setState(() => _savedTrips.removeAt(index)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Image header
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: Image.network(
                      trip.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              color: const Color(0xFF1A237E),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFD4AF37)))),
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1A237E),
                          child: const Center(
                              child: Icon(Icons.landscape,
                                  color: Color(0xFFD4AF37), size: 40))),
                    )),
                    Positioned.fill(
                        child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter),
                      ),
                    )),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.destination,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text(trip.province,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (trip.savedDate != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            'Saved ${trip.savedDate!.day}/${trip.savedDate!.month}/${trip.savedDate!.year}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Info row
              Container(
                color: TravelloTheme.paperLightContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _infoChip(Icons.terrain, trip.style),
                    const SizedBox(width: 8),
                    _infoChip(Icons.calendar_today, '${trip.duration} days'),
                    const SizedBox(width: 8),
                    _infoChip(Icons.account_balance_wallet, trip.budget),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showSavedTripDetail(trip),
                      style: TextButton.styleFrom(
                          foregroundColor: TravelloTheme.primaryMain,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6)),
                      child: const Text('View Plan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: colorScheme(context).onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: colorScheme(context).onSurface.withValues(alpha: 0.7))),
      ],
    );
  }

  void _showSavedTripDetail(_TripItinerary trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('${trip.destination} — ${trip.duration} Day Plan',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...trip.days.map((day) => _buildDayCard(day)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card payment bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CardPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String conversationId;
  final void Function(String pnr, double amount) onSuccess;
  final VoidCallback onCancel;

  const _CardPaymentSheet({
    required this.bookingData,
    required this.conversationId,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<_CardPaymentSheet> createState() => _CardPaymentSheetState();
}

class _CardPaymentSheetState extends State<_CardPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _processing = false;
  String? _errorMsg;

  static const _gold = Color(0xFFD4AF37);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatExpiry(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      return '${digits.substring(0, 2)}/${digits.substring(2).padRight(0)}';
    }
    return digits;
  }

  Future<void> _processPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _processing = true; _errorMsg = null; });

    try {
      final data = widget.bookingData;
      final amount = (data['total_price_pkr'] as num?)?.toDouble() ?? 0.0;

      // Step 1: Create booking via agent endpoint
      final booking = await ApiClient.agentBook(
        bookingType: data['booking_type'] as String? ?? 'flight',
        conversationId: widget.conversationId,
        origin: data['origin'] as String?,
        destination: data['destination'] as String?,
        travelDate: data['travel_date'] as String?,
        departureTime: data['departure_time'] as String?,
        arrivalTime: data['arrival_time'] as String?,
        flightNumber: data['flight_number'] as String?,
        trainName: data['train_name'] as String?,
        checkIn: data['check_in'] as String?,
        checkOut: data['check_out'] as String?,
        travelers: (data['travelers'] as num?)?.toInt() ?? 1,
        totalAmount: amount,
        hotelName: data['hotel_name'] as String?,
        passengerName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        description: data['selected_option'] as String? ?? 'Agent booking',
      );

      final bookingId = booking['booking_id'] as String;
      final pnr = booking['pnr'] as String;

      // Step 2: Initiate card payment (instant confirmation)
      await ApiClient.initiatePayment(
        bookingId: bookingId,
        method: 'card',
        amount: amount,
      );

      if (mounted) Navigator.pop(context);
      widget.onSuccess(pnr, amount);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.bookingData['total_price_pkr'] as num?)?.toInt() ?? 0;
    final fmt = NumberFormat('#,##0', 'en_US');

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card_rounded,
                        color: _gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Card Payment',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Total: PKR ${fmt.format(amount)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: _gold,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Cardholder name
              _CardField(
                controller: _nameCtrl,
                label: 'Cardholder Name',
                hint: 'As printed on card',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter cardholder name' : null,
              ),
              const SizedBox(height: 14),

              // Card number
              _CardField(
                controller: _cardCtrl,
                label: 'Card Number',
                hint: '1234 5678 9012 3456',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                maxLength: 19,
                onChanged: (v) {
                  final formatted = _formatCardNumber(v);
                  if (formatted != v) {
                    _cardCtrl.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  return digits.length < 16 ? 'Enter 16-digit card number' : null;
                },
              ),
              const SizedBox(height: 14),

              // Expiry + CVV row
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      controller: _expiryCtrl,
                      label: 'Expiry',
                      hint: 'MM/YY',
                      icon: Icons.calendar_month_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      onChanged: (v) {
                        final formatted = _formatExpiry(v);
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                      validator: (v) {
                        final parts = (v ?? '').split('/');
                        if (parts.length != 2 || parts[0].length != 2 ||
                            parts[1].length != 2) {
                          return 'Invalid date';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      controller: _cvvCtrl,
                      label: 'CVV',
                      hint: '•••',
                      icon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      validator: (v) =>
                          ((v ?? '').length < 3) ? 'Enter 3-digit CVV' : null,
                    ),
                  ),
                ],
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Pay button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    disabledBackgroundColor: _gold.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          amount > 0
                              ? 'Pay PKR ${fmt.format(amount)}'
                              : 'Confirm Booking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                ),
              ),

              // Security note
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Secured by 256-bit encryption',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
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

// ── Card form field helper ────────────────────────────────────────────────────
class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Past conversations bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final String? currentId;
  final void Function(String id) onSelect;
  final void Function(String id) onDelete;
  final VoidCallback onNewChat;

  const _ConversationsSheet({
    required this.conversations,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
    required this.onNewChat,
  });

  @override
  State<_ConversationsSheet> createState() => _ConversationsSheetState();
}

class _ConversationsSheetState extends State<_ConversationsSheet> {
  late List<Map<String, dynamic>> _convs;

  @override
  void initState() {
    super.initState();
    _convs = List.from(widget.conversations);
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM  HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Icon(Icons.history_rounded, color: gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Conversation History',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add, size: 16, color: gold),
                label: const Text('New Chat',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_convs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No past conversations',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _convs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final c = _convs[i];
                  final id = c['id'] as String? ?? '';
                  final title = c['title'] as String? ?? 'Conversation';
                  final date = _fmtDate(c['updated_at'] as String?);
                  final isCurrent = id == widget.currentId;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? gold.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: isCurrent ? gold : Colors.grey.shade400,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: date.isNotEmpty
                        ? Text(date,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400))
                        : null,
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle_rounded,
                            color: gold, size: 18)
                        : IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red.shade300),
                            onPressed: () {
                              widget.onDelete(id);
                              setState(() => _convs.removeAt(i));
                            },
                          ),
                    onTap: isCurrent ? null : () => widget.onSelect(id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
