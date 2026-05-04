import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatMessage — one turn in a conversation (user or assistant).
// Mapped to the ai_messages table in Supabase.
// ─────────────────────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String? conversationId;   // FK → ai_conversations.id
  final String message;
  final bool isUser;              // true = role:'user', false = role:'assistant'
  final DateTime timestamp;

  // 'text' | 'itinerary' | 'action_result' | 'suggestion' | 'error'
  final String messageType;

  // Structured payload (itinerary days, search results, action details, etc.)
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    this.conversationId,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.messageType = 'text',
    this.metadata,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String?,
        message: map['content'] as String,
        isUser: (map['role'] as String) == 'user',
        timestamp: DateTime.parse(map['created_at'] as String),
        messageType: (map['message_type'] as String?) ?? 'text',
        metadata: map['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'content': message,
        'role': isUser ? 'user' : 'assistant',
        'created_at': timestamp.toIso8601String(),
        'message_type': messageType,
        'metadata': metadata,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// DayPlan — one day inside a trip itinerary.
// Serialised into ai_saved_itineraries.itinerary_data → { "days": [...] }
// ─────────────────────────────────────────────────────────────────────────────
class DayPlan {
  final int day;
  final String title;
  final String iconName;          // icon code-point name stored as string
  final List<String> activities;

  const DayPlan({
    required this.day,
    required this.title,
    required this.iconName,
    required this.activities,
  });

  factory DayPlan.fromMap(Map<String, dynamic> map) => DayPlan(
        day: map['day'] as int,
        title: map['title'] as String,
        iconName: (map['icon'] as String?) ?? 'place',
        activities: List<String>.from(map['activities'] as List),
      );

  Map<String, dynamic> toMap() => {
        'day': day,
        'title': title,
        'icon': iconName,
        'activities': activities,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// AISavedItinerary — a full trip plan persisted to ai_saved_itineraries.
// ─────────────────────────────────────────────────────────────────────────────
class AISavedItinerary {
  final String? id;               // null until saved to DB
  final String? conversationId;
  final String destination;
  final String province;
  final String imageUrl;
  final String travelStyle;       // Adventure | Cultural | Relaxing | Family | Nature | Mixed
  final int durationDays;
  final String budgetRange;       // Budget | Mid-range | Luxury
  final List<DayPlan> days;
  final DateTime? tripDate;
  final String? notes;
  final bool isBooked;
  final DateTime? savedDate;

  const AISavedItinerary({
    this.id,
    this.conversationId,
    required this.destination,
    required this.province,
    required this.imageUrl,
    required this.travelStyle,
    required this.durationDays,
    required this.budgetRange,
    required this.days,
    this.tripDate,
    this.notes,
    this.isBooked = false,
    this.savedDate,
  });

  factory AISavedItinerary.fromMap(Map<String, dynamic> map) {
    final data = map['itinerary_data'] as Map<String, dynamic>;
    final rawDays = data['days'] as List;
    return AISavedItinerary(
      id: map['id'] as String?,
      conversationId: map['conversation_id'] as String?,
      destination: map['destination'] as String,
      province: (map['province'] as String?) ?? '',
      imageUrl: (map['image_url'] as String?) ?? '',
      travelStyle: (map['travel_style'] as String?) ?? 'Mixed',
      durationDays: (map['duration_days'] as int?) ?? rawDays.length,
      budgetRange: (map['budget_range'] as String?) ?? 'Mid-range',
      days: rawDays
          .map((d) => DayPlan.fromMap(d as Map<String, dynamic>))
          .toList(),
      tripDate: map['trip_date'] != null
          ? DateTime.tryParse(map['trip_date'] as String)
          : null,
      notes: map['notes'] as String?,
      isBooked: (map['is_booked'] as bool?) ?? false,
      savedDate: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'conversation_id': conversationId,
        'destination': destination,
        'province': province,
        'image_url': imageUrl,
        'travel_style': travelStyle,
        'duration_days': durationDays,
        'budget_range': budgetRange,
        'itinerary_data': {'days': days.map((d) => d.toMap()).toList()},
        'trip_date': tripDate?.toIso8601String().split('T').first,
        'notes': notes,
        'is_booked': isBooked,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// AgentTask — one autonomous task the agent executes on behalf of the user.
// Mapped to the agent_tasks table in Supabase.
// ─────────────────────────────────────────────────────────────────────────────
class AgentTask {
  final String? id;
  final String? conversationId;

  // plan_trip | search_flights | search_hotels | search_trains |
  // price_alert | book_flight | book_hotel | book_train |
  // weather_check | summarise_options | custom
  final String taskType;
  final String taskDescription;
  final Map<String, dynamic>? taskParams;

  // pending | in_progress | completed | failed | cancelled
  final String status;
  final int priority;             // 1 (low) – 5 (critical)

  final Map<String, dynamic>? result;
  final String? errorMessage;
  final int retryCount;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AgentTask({
    this.id,
    this.conversationId,
    required this.taskType,
    required this.taskDescription,
    this.taskParams,
    this.status = 'pending',
    this.priority = 1,
    this.result,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory AgentTask.fromMap(Map<String, dynamic> map) => AgentTask(
        id: map['id'] as String?,
        conversationId: map['conversation_id'] as String?,
        taskType: map['task_type'] as String,
        taskDescription: map['task_description'] as String,
        taskParams: map['task_params'] as Map<String, dynamic>?,
        status: (map['status'] as String?) ?? 'pending',
        priority: (map['priority'] as int?) ?? 1,
        result: map['result'] as Map<String, dynamic>?,
        errorMessage: map['error_message'] as String?,
        retryCount: (map['retry_count'] as int?) ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        startedAt: map['started_at'] != null
            ? DateTime.tryParse(map['started_at'] as String)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.tryParse(map['completed_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'conversation_id': conversationId,
        'task_type': taskType,
        'task_description': taskDescription,
        'task_params': taskParams,
        'status': status,
        'priority': priority,
      };

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  IconData get statusIcon => switch (status) {
        'pending' => Icons.schedule,
        'in_progress' => Icons.autorenew,
        'completed' => Icons.check_circle,
        'failed' => Icons.error_outline,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.help_outline,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// AISuggestion — quick-reply chip shown below the first AI message.
// ─────────────────────────────────────────────────────────────────────────────
class AISuggestion {
  final String title;
  final IconData icon;

  const AISuggestion({required this.title, required this.icon});
}

// ─────────────────────────────────────────────────────────────────────────────
// AIAssistantData — static helpers used by the AI assistant screen.
// (responses are pattern-matched locally; real Claude API call goes here later)
// ─────────────────────────────────────────────────────────────────────────────
class AIAssistantData {
  static List<AISuggestion> getSuggestions() {
    return const [
      AISuggestion(title: 'Plan a trip to Hunza Valley', icon: Icons.landscape),
      AISuggestion(
          title: 'Cheapest flights to Islamabad', icon: Icons.flight_takeoff),
      AISuggestion(title: 'Best time to visit Skardu', icon: Icons.ac_unit),
      AISuggestion(title: 'Hotels near Faisal Mosque', icon: Icons.hotel),
      AISuggestion(title: 'Train from Karachi to Lahore', icon: Icons.train),
      AISuggestion(
          title: 'Budget trip to Northern Pakistan',
          icon: Icons.account_balance_wallet),
    ];
  }

  static String getAIResponse(String userMessage) {
    final msg = userMessage.toLowerCase();

    // ── Hunza / Northern Pakistan ───────────────────────────────────
    if (msg.contains('hunza')) {
      return "Hunza Valley is Pakistan's crown jewel! Best time: April-October.\n\n"
          "Flight: Islamabad -> Gilgit (PIA/AirBlue, ~1.5 hrs, PKR 8,000-14,000) then drive 2.5 hrs to Karimabad.\n\n"
          "Must-see: Attabad Lake, Baltit Fort, Eagle's Nest, Rakaposhi viewpoint.\n\n"
          "Budget: PKR 25,000-45,000 for 5 days (mid-range guesthouse + meals).\n\n"
          "Want a full 5-day itinerary? Go to the **Plan Trip** tab!";
    }

    // ── Skardu ──────────────────────────────────────────────────────
    if (msg.contains('skardu') ||
        msg.contains('k2') ||
        msg.contains('deosai')) {
      return "Skardu - Gateway to K2 and the Karakoram!\n\n"
          "Flight: Islamabad -> Skardu (~1.5 hrs, PKR 9,000-16,000) - book early as flights fill fast.\n\n"
          "Top spots: Shangrila Resort, Deosai National Park, Kachura Lakes, K2 viewpoint.\n\n"
          "Best season: May-September. Winter roads may close.\n\n"
          "Budget: PKR 30,000-55,000 for 5 days. Use the **Plan Trip** tab for your personalised itinerary!";
    }

    // ── Lahore ──────────────────────────────────────────────────────
    if (msg.contains('lahore')) {
      return "Lahore - The Heart of Pakistan!\n\n"
          "Flights from Karachi/Islamabad take ~1 hr (PKR 6,000-12,000).\n\n"
          "Must visit: Badshahi Mosque, Lahore Fort (Sheesh Mahal), Walled City, Fort Road Food Street.\n\n"
          "Food: Try Cooco's Den, Cafe Aylanto, and Anarkali's street food.\n\n"
          "Budget: PKR 15,000-30,000 for 3 days including transport and food.";
    }

    // ── Islamabad / Murree ──────────────────────────────────────────
    if (msg.contains('islamabad') ||
        msg.contains('murree') ||
        msg.contains('margalla')) {
      return "Islamabad - Pakistan's beautiful capital!\n\n"
          "Top attractions: Faisal Mosque, Margalla Hills Trail 3, Pakistan Monument, Daman-e-Koh.\n\n"
          "Day trips: Murree (~1 hr), Taxila ruins (~45 min), Khanpur Dam.\n\n"
          "Well-connected: Flights from major cities (PKR 5,000-13,000 from Karachi/Lahore).\n\n"
          "Budget: PKR 12,000-25,000 for 2-3 days. Ideal as a base for northern travels!";
    }

    // ── Karachi ─────────────────────────────────────────────────────
    if (msg.contains('karachi')) {
      return "Karachi - City of Lights and the Arabian Sea!\n\n"
          "Must see: Quaid's Mausoleum, Clifton Beach, Port Grand, Empress Market.\n\n"
          "Food: Burns Road, Boat Basin, Student Biryani, Kolachi seafood restaurant.\n\n"
          "Beaches: French Beach, Hawkes Bay, Manora Island.\n\n"
          "Karachi is Pakistan's main aviation hub - flights available from all cities.";
    }

    // ── Flights ─────────────────────────────────────────────────────
    if (msg.contains('flight') ||
        msg.contains('fly') ||
        msg.contains('airline')) {
      return "Pakistan's major airlines: PIA, AirBlue, SereneAir and FlyJinnah.\n\n"
          "Tips for cheap flights:\n"
          "- Book 3-4 weeks in advance\n"
          "- Morning flights (6-8 AM) are usually cheapest\n"
          "- Avoid school holiday periods\n"
          "- Check all airlines via the **Flights** tab\n\n"
          "Popular routes and approx fares:\n"
          "- Karachi -> Lahore: PKR 6,000-12,000\n"
          "- Islamabad -> Gilgit: PKR 8,000-14,000\n"
          "- Islamabad -> Skardu: PKR 9,000-16,000";
    }

    // ── Trains ──────────────────────────────────────────────────────
    if (msg.contains('train') ||
        msg.contains('rail') ||
        msg.contains('railway')) {
      return "Pakistan Railways network covers major cities.\n\n"
          "Popular routes:\n"
          "- Karachi -> Lahore: Tezgam Express (14 hrs), PKR 2,500-6,500\n"
          "- Karachi -> Islamabad: Green Line (18 hrs), PKR 3,000-7,000\n"
          "- Lahore -> Peshawar: Khyber Mail (5 hrs), PKR 800-2,500\n\n"
          "Tip: AC Business class is recommended for long journeys. Book via the **Trains** tab!";
    }

    // ── Hotels ──────────────────────────────────────────────────────
    if (msg.contains('hotel') ||
        msg.contains('stay') ||
        msg.contains('accommodation') ||
        msg.contains('hostel')) {
      return "Accommodation options across Pakistan:\n\n"
          "**Budget (PKR 2,000-5,000/night):** Guest houses, hostels\n"
          "**Mid-range (PKR 5,000-15,000/night):** 3-star hotels\n"
          "**Luxury (PKR 15,000+/night):** Pearl Continental, Serena Hotels, Avari\n\n"
          "Popular: Serena Hotel (Islamabad/Gilgit), PC Hotel (Karachi/Lahore), PTDC motels (Northern areas).\n\n"
          "Use the **Hotels** tab to search and book!";
    }

    // ── Weather / Best time ─────────────────────────────────────────
    if (msg.contains('weather') ||
        msg.contains('best time') ||
        msg.contains('season') ||
        msg.contains('when to visit')) {
      return "Pakistan travel seasons:\n\n"
          "**Northern areas (Hunza, Skardu, Swat):**\n"
          "- Best: April-October\n"
          "- Winter (Nov-Mar): Roads may close, heavy snow\n\n"
          "**Punjab and Sindh (Lahore, Karachi):**\n"
          "- Best: Oct-Mar (pleasant 15-25 C)\n"
          "- Summer (May-Aug): Very hot 35-45 C\n\n"
          "**Balochistan (Quetta, Gwadar):**\n"
          "- Best: Mar-May and Sep-Nov";
    }

    // ── Budget / Cost ────────────────────────────────────────────────
    if (msg.contains('budget') ||
        msg.contains('cost') ||
        msg.contains('expensive') ||
        msg.contains('cheap') ||
        msg.contains('price')) {
      return "Pakistan travel budget guide:\n\n"
          "**Budget traveller:** PKR 3,000-5,000/day\n"
          "- Shared transport, local food, budget guesthouse\n\n"
          "**Mid-range:** PKR 8,000-15,000/day\n"
          "- Comfortable hotel, restaurant meals, attractions\n\n"
          "**Luxury:** PKR 25,000+/day\n"
          "- 5-star hotels, private guides, premium experiences\n\n"
          "Biggest expense is usually flights. Book early for best prices!";
    }

    // ── Trip planning ────────────────────────────────────────────────
    if (msg.contains('plan') ||
        msg.contains('itinerary') ||
        msg.contains('trip') ||
        msg.contains('tour')) {
      return "I can help you plan your Pakistan adventure.\n\n"
          "Switch to the **Plan Trip** tab to:\n"
          "- Choose your destination (17 destinations available)\n"
          "- Select travel style (Adventure, Cultural, Relaxing, Family, Nature)\n"
          "- Set trip duration (3, 5, 7 or 10 days)\n"
          "- Pick your budget range\n\n"
          "I'll generate a complete day-by-day itinerary with activities, highlights and tips!";
    }

    // ── Food ────────────────────────────────────────────────────────
    if (msg.contains('food') ||
        msg.contains('eat') ||
        msg.contains('restaurant') ||
        msg.contains('cuisine') ||
        msg.contains('biryani') ||
        msg.contains('kebab')) {
      return "Pakistani cuisine is world-class!\n\n"
          "**Must-try dishes:**\n"
          "- Biryani (Karachi-style)\n"
          "- Chapli Kebab (Peshawar)\n"
          "- Lahori Nihari and Paye\n"
          "- Sajji - whole roasted lamb/chicken (Balochistan)\n"
          "- Hunza Tsamak and Chapshuro (Northern)\n"
          "- Karahi Gosht and Butter Chicken\n\n"
          "**Food streets:** Fort Road Lahore, Burns Road Karachi, Namak Mandi Peshawar";
    }

    // ── Safety ──────────────────────────────────────────────────────
    if (msg.contains('safe') ||
        msg.contains('safety') ||
        msg.contains('danger') ||
        msg.contains('security')) {
      return "Pakistan safety tips for travellers:\n\n"
          "- Tourist areas are generally safe\n"
          "- Northern Pakistan (Hunza, Skardu) is very safe and tourist-friendly\n"
          "- Major cities have tourist police\n\n"
          "Tips:\n"
          "- Register with your country's embassy if staying long\n"
          "- Hire a local guide for remote treks\n"
          "- Keep copies of ID and travel documents\n"
          "- Check travel advisories before visiting border areas\n\n"
          "Pakistan is renowned for its warm hospitality.";
    }

    // ── Default ─────────────────────────────────────────────────────
    return "I'm your AI Travel Assistant for Pakistan!\n\n"
        "I can help you with:\n"
        "- Flight booking guidance and pricing\n"
        "- Train routes and schedules\n"
        "- Hotel recommendations\n"
        "- Personalised trip planning (17 destinations)\n"
        "- Best time to visit\n"
        "- Budget planning\n"
        "- Food and cuisine guide\n\n"
        "What would you like to explore? Try the **Plan Trip** tab for a full AI-generated itinerary!";
  }
}
