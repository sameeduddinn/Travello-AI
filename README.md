# Travello AI — Intelligent Travel Booking Platform

> A full-stack, AI-powered travel booking application for Pakistan, built as a Final Year Project.
> Covers flight, hotel, train, and car-transfer booking, with a native tool-calling AI travel
> assistant that can search, compare, and book on the user's behalf — including a guided,
> multi-leg **Trip Package** (transport + hotel + car transfer as one linked booking, one payment).

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Features](#2-features)
3. [System Architecture](#3-system-architecture)
4. [Tech Stack](#4-tech-stack)
5. [Project Structure](#5-project-structure)
6. [Database Schema](#6-database-schema)
7. [API Reference](#7-api-reference)
8. [Getting Started](#8-getting-started)
   - [Prerequisites](#prerequisites)
   - [Backend Setup](#backend-setup)
   - [Flutter App Setup](#flutter-app-setup)
9. [Environment Variables](#9-environment-variables)
10. [Third-Party Integrations](#10-third-party-integrations)
11. [User Journeys](#11-user-journeys)
12. [Team](#12-team)

---

## 1. Project Overview

**Travello AI** is an Android travel booking app tailored for Pakistan. Users can search, compare,
and book flights, trains, hotels, and car transfers through a manual step-by-step flow, or by
chatting with an integrated AI assistant that drives the exact same backend booking pipeline. The
assistant can also run a guided **Trip Planner**: it searches transport + hotel (+ a car transfer
for a northern destination), lets the user pick each part, prices the whole trip, and books all of
it as one linked package under a single card payment.

The backend is a Python/FastAPI REST API on Supabase (PostgreSQL + Auth + Storage). The frontend
is a Flutter application. **Android is the only built and tested target** — the `ios/`, `web/`,
`windows/`, `linux/`, and `macos/` folders are default `flutter create` scaffolding that has never
been built or run.

This is an academic project, not a commercial product — some scope decisions (card-only payment,
no promo codes, fully mocked train data) are deliberate, supervisor-approved simplifications, not
gaps.

---

## 2. Features

### Booking & Search
- **Flight Search** — Domestic Pakistan routes: seeded mock data supplemented by live
  [AviationStack](https://aviationstack.com) results when available. International routes:
  AviationStack primary, mock supplement. (Free-tier AviationStack is 100 requests/month and
  today-only, so future-dated searches rely on the mock data.)
- **Hotel Search** — Multi-source fallback chain: RapidAPI (TripAdvisor) → Google Places →
  OpenStreetMap (Nominatim + Overpass) → mock data.
- **Train Search** — Pakistan Railways. **Fully mocked** with realistic names, schedules, and
  ±5% price jitter — there is no public Pakistan Railways API, so this is a permanent,
  supervisor-approved design choice, not a TODO.
- **Car / Transfer Booking** — Standalone driver booking (Sedan/SUV/Van) for any pickup/dropoff,
  plus a real hub→destination fare table for the four supported northern trips (Naran, Hunza,
  Swat, Skardu).
- **Saved Searches** — Auto-saved to the database; re-run with one tap from the Profile screen.

### AI Travel Assistant
- **Native tool-calling agent** (not a framework like LangChain) that searches, compares, and
  books through the same deterministic pipeline the manual UI uses — every money/dispatch
  decision (pricing, booking gates, package totals) is enforced in code, never left to the model.
- **Interactive Trip Planner** — a guided flow (options → user picks → priced plan → one-checkout
  booking) for a complete Naran/Hunza/Swat/Skardu package: transport + hotel + hub car transfer,
  booked together as one payment.
- **Budget feasibility checks** — the assistant compares real search-tool prices against a stated
  budget and states plainly whether a trip fits, without ever fabricating numbers.
- **LLM provider fallback chain** — Groq (Llama 3.3 70B) → OpenRouter (free-tier models) → Google
  Gemini, so the assistant keeps working even when a free-tier provider is rate-limited.
- Card numbers/CVV and identity documents (CNIC, passport, DOB) are never accepted as a chat
  message or sent to the LLM.

### Booking Management
- **Full Booking Flow** — Passenger/guest details, then card payment, for a single component or
  for an entire Trip Package in one checkout.
- **Booking History** — All bookings (confirmed, pending, cancelled), with Trip Package
  components grouped together.
- **Booking Detail & E-Ticket** — QR code, barcode, and PDF download/share.
- **Cancel Booking** — Cancel pending/confirmed bookings; remove cancelled ones from history.

### Post-Booking
- **Email Confirmations** — Sent via Gmail SMTP after every successful payment; a Trip Package
  gets one consolidated confirmation email covering all of its components.
- **In-App Notifications** — Notification feed for booking events.
- **Review System** — Star ratings and comments on completed bookings, stored in Supabase.
- **PDF Ticket Generation** — Downloadable e-ticket PDF.

### User Profile
- **Authentication** — Email/password via Supabase Auth (JWT).
- **Profile & Preferences** — Name, phone, profile picture, and travel preferences (cabin class,
  travel style, companion type, and more) that the AI assistant also learns from and reuses.
- **Wishlist & Saved Searches**
- **FAQ, Terms, Privacy Policy, Cancellation Policy**

### Other
- **Weather** — Google Weather API, falling back to Open-Meteo, then a static default.
- **Healthcare** — Nearby hospitals/pharmacies and emergency numbers.
- **Support** — Contact-support email flow with an admin email-reply link.

---

## 3. System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                             │
│                    Flutter App (Android only)                     │
│      Screens → Widgets → Controllers (GetX) → Services            │
└──────────────────────────┬─────────────────────────────────────────┘
                            │ HTTPS / REST API
┌───────────────────────────▼─────────────────────────────────────────┐
│                           API LAYER                                  │
│                     Python FastAPI Backend                           │
│  Routers → Agents (AI loop) → Services → Models → Core (Auth/DB)    │
└───┬──────────────┬───────────────┬───────────────┬──────────────────┘
    │              │               │               │
┌───▼───────┐ ┌────▼────────┐ ┌────▼───────────┐ ┌──▼─────────────────┐
│ Supabase  │ │ Search APIs │ │ LLM Providers   │ │ Gmail SMTP          │
│ PostgreSQL│ │ AviationStack│ │ Groq → OpenRouter│ │ (booking + support │
│ + Auth    │ │ RapidAPI    │ │ → Gemini         │ │  emails)            │
│ + Storage │ │ Google Places│ └─────────────────┘ └─────────────────────┘
└───────────┘ │ OpenStreetMap│
              │ Open-Meteo   │
              └──────────────┘
```

### Data Flow — Single-Component Booking
```
User fills passenger/guest form → Flutter calls POST /flights/book (or /hotels/book, /trains/book)
→ Backend creates booking (status: pending) in Supabase
→ Flutter calls POST /payments/initiate
→ Backend marks booking as confirmed, records a payment_attempt row
→ Backend sends a confirmation email (Gmail SMTP)
→ Flutter shows the confirmation / e-ticket screen
→ In-app notification created
```

### Data Flow — AI Trip Package Booking
```
User chats with the assistant (or uses the native Trip Package screens)
→ POST /agent/chat drives process_message_agentic (backend/agents/master_agent.py)
→ Assistant searches transport + hotel (+ car transfer), presents options
→ User picks; assistant builds one priced plan and asks to confirm
→ On confirmation: transport, hotel, and transfer are created as linked booking rows
  sharing one package_id, and charged in exactly one payment
→ One consolidated confirmation email is sent for the whole package
```

---

## 4. Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile Frontend | Flutter (Dart), **Android only** | 3.x / Dart ≥3.4.4 |
| State Management | GetX | ^4.7.3 |
| Backend Framework | FastAPI | 0.115.6 |
| Backend Runtime | Python | 3.11+ |
| ASGI Server | Uvicorn | 0.32.1 |
| Database | Supabase (PostgreSQL) | — |
| Auth | Supabase JWT | — |
| Supabase Client | supabase-py | 2.15.3 |
| Async DB Driver | asyncpg | 0.30.0 |
| HTTP Client (backend) | httpx | 0.28.1 |
| HTTP Client (Flutter) | http | ^1.2.2 |
| Local Storage | SharedPreferences | ^2.3.2 |
| PDF Generation | pdf + printing | ^3.12.0 / ^5.13.4 |
| QR / Barcode | qr_flutter, barcode_widget | ^4.1.0 / ^2.0.4 |
| Maps | flutter_map + latlong2 | ^7.0.2 / ^0.9.1 |
| Email | Gmail SMTP | — |
| Flight Data | AviationStack | — |
| Hotel Data | RapidAPI (TripAdvisor) + Google Places + OpenStreetMap | — |
| Train Data | Fully mocked (no live API) | — |
| Weather Data | Google Weather API + Open-Meteo | — |
| LLM — primary | Groq (`llama-3.3-70b-versatile`) | groq ≥0.13.0 |
| LLM — fallback | OpenRouter (`gpt-oss-20b`, `nemotron-3-super-120b`, free tier) | via httpx |
| LLM — final fallback | Google Gemini (`gemini-2.5-flash`) | google-genai 2.14.0 |
| Deployment | Render | — |
| JSON | orjson | 3.10.12 |
| Fonts | Ubuntu (Regular, Medium, Bold) | — |

---

## 5. Project Structure

```
Travello-AI-Project/
│
├── app/                             # Flutter application (Android only)
│   └── lib/
│       ├── main.dart                # App entry point
│       ├── app/                     # Routing & navigation
│       ├── models/                  # Dart data models (flight, hotel, train, booking, trip, ...)
│       ├── screens/                 # Feature screens
│       │   ├── auth/                # Login, Register, OTP, Reset Password
│       │   ├── home/                # Unified home screen
│       │   ├── flight/              # Search, Results, Detail
│       │   ├── hotel/               # Search, Results, Detail, Checkout
│       │   ├── railway/             # Train search, Results, Detail
│       │   ├── railway_booking/     # Train-specific booking flow
│       │   ├── booking/             # Flight booking flow (passengers, checkout)
│       │   ├── trip_package/        # Native Trip Package requirements/review screens
│       │   ├── transport/           # Car/transfer booking
│       │   ├── payment/             # Card payment, Status
│       │   ├── orders/              # My Bookings, Booking Detail, E-Ticket
│       │   ├── profile/             # Profile, Saved Searches, FAQ, etc.
│       │   ├── explore/             # Destination discovery
│       │   ├── ai/                  # AI Assistant chat
│       │   ├── messages/            # Notifications / support messages
│       │   ├── healthcare/          # Hospital/clinic search
│       │   ├── weather/             # Weather screens
│       │   ├── wishlist/            # Saved favourites
│       │   └── intro/               # Onboarding & splash
│       │
│       ├── widgets/                 # Reusable UI components
│       │   ├── cards/               # Flight, Hotel, Train, Ticket cards
│       │   ├── booking/             # Passenger forms, card payment sheet
│       │   ├── railway_booking/     # Train passenger form
│       │   ├── search_filters/      # Search forms, filters, sorting
│       │   ├── chat/                # AI Assistant chat bubbles/cards
│       │   ├── home/                # Banners, sliders, sections
│       │   └── ...
│       │
│       ├── controllers/             # GetX state controllers
│       ├── services/                # API & integration clients
│       │   ├── api_client.dart      # Central HTTP client for the backend
│       │   ├── ai_service.dart      # AI assistant integration
│       │   ├── location_service.dart
│       │   └── notification_service.dart
│       │
│       ├── utils/                   # Helpers & utilities
│       ├── constants/               # App constants & image paths
│       ├── config/                  # Supabase configuration
│       └── ui/                      # Theme + shared layouts
│
│   └── assets/                      # Images, fonts (Ubuntu family)
│
├── backend/                         # Python FastAPI server
│   ├── main.py                      # App entry point, router registration
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── render.yaml                  # Render deployment config
│   │
│   ├── core/
│   │   ├── config.py                # Settings from .env (pydantic-settings)
│   │   ├── auth.py                  # JWT verification (Supabase tokens)
│   │   ├── database.py              # asyncpg pool init/close
│   │   ├── email.py                 # Gmail SMTP email sender
│   │   └── supabase_client.py       # Supabase admin + anon clients
│   │
│   ├── models/                      # Pydantic request/response schemas
│   │
│   ├── routers/                     # REST API route handlers
│   │   ├── auth.py / flights.py / hotels.py / trains.py / cars.py
│   │   ├── bookings.py / passengers.py / payments.py / reviews.py
│   │   ├── notifications.py / wishlist.py / saved_searches.py
│   │   ├── weather.py / healthcare.py / support.py / email.py
│   │   ├── agent.py                 # AI chat endpoint + conversation history
│   │   └── trip_packages.py         # Native Trip Package search/confirm
│   │
│   ├── agents/                      # The AI agent system (native tool-calling loop)
│   │   ├── master_agent.py          # Orchestration loop, deterministic booking gates
│   │   ├── agent_tools.py           # Tool schemas + deterministic validators
│   │   ├── trip_selection.py        # Trip Planner logic (options, picks, plan) — pure
│   │   ├── memory_agent.py          # Conversation/preference persistence (Supabase)
│   │   ├── conversation_state.py    # Soft, regex-derived conversation hints
│   │   └── ...                      # One agent module per domain (hotel, transport, ...)
│   │
│   ├── services/                    # External integrations & business logic
│   │   ├── flight_service.py        # AviationStack + seeded mock
│   │   ├── hotel_service.py         # RapidAPI → Google Places → OSM → mock
│   │   ├── train_service.py         # Fully mocked Pakistan Railways data
│   │   ├── car_service.py           # Driver assignment, northern-route fares
│   │   ├── northern_routes.py       # Hub → destination fare table
│   │   ├── payment_service.py       # Payment initiation & confirmation (card only)
│   │   ├── email_service.py         # Gmail SMTP transactional emails
│   │   ├── package_email.py         # Consolidated Trip Package emails
│   │   ├── llm_service.py           # Groq → OpenRouter → Gemini provider chain
│   │   └── weather_service.py       # Google Weather → Open-Meteo
│   │
│   └── sql/                         # Database schema (run in order, 01–14)
│
└── README.md
```

---

## 6. Database Schema

All tables live in Supabase (PostgreSQL) with Row Level Security (RLS) enabled.

| Table | Purpose |
|---|---|
| `profiles` | Extended user data linked to Supabase Auth (`auth.users`) |
| `user_preferences` | Origin city, currency, theme, language, and AI-learned travel preferences |
| `bookings` | All flight/hotel/train booking records. Carries `package_id` (nullable) linking the components of one Trip Package together |
| `payment_attempts` | Payment transaction log per booking |
| `payment_otps` | OTP records for payment verification |
| `passengers` | Passenger details attached to each booking |
| `reviews` | Post-booking star ratings and comments (one per booking) |
| `wishlist` | User-saved favourite routes/hotels |
| `saved_searches` | Auto-saved search parameters per user |
| `notifications` | In-app notification log per user |
| `ai_conversations` / `ai_messages` | AI assistant conversation history, including the Trip Planner's own persisted state |
| `agent_tasks` / `agent_actions` / `agent_failure_log` | AI assistant task/action logging and failure diagnostics |
| `ai_feedback` | User feedback on AI assistant responses |
| `support_messages` | Contact-support submissions and admin replies |
| `drivers` / `car_bookings` | Car-transfer drivers and bookings (standalone or Trip Package transfers) |

### Booking Status Flow
```
pending  →  confirmed  →  (completed)
    ↓
 cancelled
```

---

## 7. API Reference

Base URL: the app defaults to the deployed Render backend; override with
`--dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000` for local development against the Android
emulator.

### Authentication
| Method | Endpoint | Description |
|---|---|---|
| GET | `/auth/me` | Get the current authenticated user |
| PUT | `/auth/profile` | Update profile fields |
| PUT | `/auth/preferences` | Update travel preferences |
| DELETE | `/auth/avatar` | Remove profile picture |
| DELETE | `/auth/account` | Delete user account |

### Search & Booking
| Method | Endpoint | Description |
|---|---|---|
| POST | `/flights/search` | Search flights (AviationStack + mock) |
| GET | `/flights/{offer_id}` | Get a single flight offer |
| POST | `/flights/book` | Create a flight booking |
| GET | `/flights/deals` | Featured flight deals |
| POST | `/hotels/search` | Search hotels (RapidAPI → Google Places → OSM) |
| GET | `/hotels/{hotel_id}` | Get hotel detail |
| GET | `/hotels/{hotel_id}/rooms` | Get room offers for a hotel |
| POST | `/hotels/book` | Create a hotel booking |
| POST | `/trains/search` | Search trains (mocked Pakistan Railways) |
| POST | `/trains/book` | Create a train booking |
| POST | `/cars/book` | Book a standalone driver (Sedan/SUV/Van) |
| GET | `/cars/bookings` | List the user's car bookings |
| POST | `/trip-packages/search` | Search a full Naran/Hunza/Swat/Skardu package |
| POST | `/trip-packages/confirm` | Confirm and book a Trip Package |

### Bookings & Passengers
| Method | Endpoint | Description |
|---|---|---|
| GET | `/bookings` | List all user bookings (paginated) |
| GET | `/bookings/{id}` | Get single booking detail |
| PUT | `/bookings/{id}/cancel` | Cancel a booking |
| DELETE | `/bookings/{id}` | Remove a cancelled booking from history |
| GET | `/bookings/{id}/ticket` | Get structured ticket data |
| POST | `/passengers` | Add passengers to a booking |
| GET | `/passengers/{booking_id}` | Get passengers for a booking |
| DELETE | `/passengers/{passenger_id}` | Remove a passenger |

### Payments
| Method | Endpoint | Description |
|---|---|---|
| POST | `/payments/initiate` | Initiate card payment for a booking or package |
| GET | `/payments/{booking_id}` | Get payment history for a booking |

### AI Assistant
| Method | Endpoint | Description |
|---|---|---|
| POST | `/agent/chat` | Send a chat message; drives the full tool-calling agent loop |
| GET | `/agent/conversations` | List the user's conversations |
| GET | `/agent/conversations/{id}/messages` | Get a conversation's message history |
| POST | `/agent/conversations/{id}/notes` | Attach a note to a conversation |
| DELETE | `/agent/conversations/{id}` | Delete a conversation |
| POST | `/agent/book` | Deterministic booking endpoint used by the agent's own tool calls |
| GET | `/agent/proactive-alert` | Proactive alert check (e.g. price/weather changes) |

### Reviews & Wishlist
| Method | Endpoint | Description |
|---|---|---|
| POST | `/reviews` | Submit or update a review for a booking |
| GET | `/reviews/booking/{booking_id}` | Get the review for a booking |
| GET | `/reviews/my` | Get all reviews by the current user |
| GET/POST/DELETE | `/wishlist` | Manage wishlist items |
| GET/POST/DELETE | `/saved-searches` | Manage saved searches |

### Other
| Method | Endpoint | Description |
|---|---|---|
| GET | `/notifications` | Get user notifications |
| PUT | `/notifications/{id}/read` | Mark a notification as read |
| PUT | `/notifications/read-all` | Mark all notifications as read |
| GET | `/weather/{city}` | Get weather for a city |
| GET | `/healthcare/nearby` | Search nearby hospitals/clinics |
| GET | `/healthcare/pharmacies` | Search nearby pharmacies |
| GET | `/healthcare/emergency-numbers` | Get emergency contact numbers |
| POST | `/email/contact-support` | Submit a support request |
| POST | `/email/booking-confirmation` | Resend a booking confirmation email |
| GET/DELETE | `/support/messages` | Manage support messages |
| POST | `/support/reply` | Admin reply to a support message |
| GET | `/health` | Server health check |

Full interactive docs (Swagger) are available at `/docs` on any running backend instance.

---

## 8. Getting Started

### Prerequisites

- Flutter SDK 3.x ([flutter.dev](https://flutter.dev)) with the Android toolchain
- Dart SDK ≥3.4.4
- Python 3.11+
- pip
- A [Supabase](https://supabase.com) project (free tier works)
- Android Studio (emulator) or a physical Android device

---

### Backend Setup

**1. Clone the repository**
```bash
git clone https://github.com/<your-username>/Travello-AI-Project.git
cd Travello-AI-Project/backend
```

**2. Create and activate a virtual environment**
```bash
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

**3. Install dependencies**
```bash
pip install -r requirements.txt
```

**4. Configure environment variables**

Create a `.env` file in `backend/` — see [Environment Variables](#9-environment-variables) below.

**5. Set up the database**

Run the SQL files in order inside your Supabase SQL Editor (all are idempotent — safe to re-run):
```
sql/01_profiles.sql
sql/02_bookings.sql
sql/03_payments.sql
sql/04_passengers.sql
sql/05_wishlist.sql
sql/06_notifications.sql
sql/07_indexes_and_triggers.sql
sql/08_security_fixes.sql
sql/09_ai_agent.sql
sql/10_support_messages.sql
sql/11_car_drivers.sql
sql/12_ai_preferences_columns.sql
sql/13_agent_failure_log.sql
sql/14_trip_packages.sql
```

**6. Start the server**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`
Interactive docs at `http://localhost:8000/docs`

---

### Flutter App Setup

**Android only** — this app has never been built for iOS, Web, or desktop; those platform folders
are unused `flutter create` scaffolding.

**1. Navigate to the app directory**
```bash
cd Travello-AI-Project/app
```

**2. Install Flutter dependencies**
```bash
flutter pub get
```

**3. Point the app at your backend**

`lib/services/api_client.dart` defaults to the deployed Render backend. To use a local backend
instead, pass the URL at run time:
```bash
# Android emulator (10.0.2.2 maps to the host machine's localhost)
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000

# Physical device on the same network (use your machine's LAN IP)
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.x.x:8000
```

**4. Configure Supabase**

Open `lib/config/supabase_config.dart` and add your Supabase project URL and anon key.

**5. Run the app**
```bash
flutter run
```

---

## 9. Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# ── Application ──────────────────────────────────────────
APP_NAME=Travello AI
APP_VERSION=1.0.0
DEBUG=true

# ── Supabase ──────────────────────────────────────────────
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret

# ── Database (direct asyncpg connection) ─────────────────
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres

# ── Flight data ───────────────────────────────────────────
AVIATIONSTACK_KEY=your-aviationstack-key

# ── Hotel data (RapidAPI — TripAdvisor host) ─────────────
RAPIDAPI_KEY=your-rapidapi-key
RAPIDAPI_HOST=tripadvisor16.p.rapidapi.com

# ── Google Maps Platform (Places, Weather, Healthcare) ───
GOOGLE_PLACES_API_KEY=your-google-places-key

# ── LLM providers (AI assistant fallback chain) ──────────
GROQ_API_KEY_1=your-groq-key-1
GROQ_API_KEY_2=your-groq-key-2
GROQ_MODEL=llama-3.3-70b-versatile

OPENROUTER_API_KEY=your-openrouter-key
OPENROUTER_MODEL=openai/gpt-oss-20b:free,nvidia/nemotron-3-super-120b-a12b:free

GEMINI_API_KEY=your-gemini-key
GEMINI_MODEL=gemini-2.5-flash

AGENT_DAILY_MESSAGE_LIMIT=100

# ── Email (Gmail SMTP) ────────────────────────────────────
EMAIL_FROM=Travello AI <your-email@gmail.com>
EMAIL_REPLY_TO=support@travello.ai
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password        # Use a Gmail App Password, not your main password

# ── Currency ──────────────────────────────────────────────
USD_TO_PKR_RATE=278.0
EUR_TO_PKR_RATE=305.0

# ── Admin / deployment ────────────────────────────────────
ADMIN_SECRET_KEY=your-admin-secret
BACKEND_BASE_URL=https://your-backend.onrender.com
CORS_ORIGINS=*
```

> **Gmail SMTP note:** Go to your Google Account → Security → 2-Step Verification → App Passwords.
> Generate an app password and use it as `SMTP_PASSWORD`.

> **Note:** there is no Amadeus, JazzCash, EasyPaisa, or bank-transfer integration anywhere in this
> project — payment is card-only, and flight data comes from AviationStack, not Amadeus.

---

## 10. Third-Party Integrations

| Service | Purpose | Fallback |
|---|---|---|
| **AviationStack** | Live flight schedules (domestic + international) | Seeded mock flight data |
| **RapidAPI (TripAdvisor host)** | Primary hotel search | Google Places → OSM → Mock |
| **Google Places API** | Hotel search fallback + healthcare search | OpenStreetMap Nominatim |
| **OpenStreetMap (Nominatim + Overpass)** | Hotel/location data | Mock hotel data |
| **Google Weather API** | City weather | Open-Meteo → static default |
| **Groq** (Llama 3.3 70B) | AI assistant — primary LLM | OpenRouter |
| **OpenRouter** (free-tier models) | AI assistant — secondary LLM | Google Gemini |
| **Google Gemini** (2.5 Flash) | AI assistant — final LLM fallback | — |
| **Gmail SMTP** | Booking confirmation & support emails | Silent fail (logged) |
| **Supabase** | Database, Auth, Storage | — |

All external API calls include fallback chains, so the app stays functional even if an individual
API is unavailable or quota-limited. Pakistan Railways has no public API at all, so train data is
permanently and deliberately mocked rather than falling back from a live source.

---

## 11. User Journeys

### Flight Booking
```
Home Screen
  └── Flight Search (origin, destination, date, passengers, class)
        └── Flight Results (list with price, duration, airline)
              └── Flight Detail (fare breakdown)
                    └── Passenger Form (name, contact — no CNIC/passport collected in chat)
                          └── Card Payment
                                └── Payment Status (confirmed + email sent)
                                      └── E-Ticket (QR code, PDF download)
```

### Hotel Booking
```
Home Screen
  └── Hotel Search (city, check-in, check-out, rooms, guests)
        └── Hotel Results (list with rating, price/night)
              └── Hotel Detail (amenities, room types, map)
                    └── Guest Form (name, contact)
                          └── Card Payment
                                └── Hotel Booking Confirmation (PDF invoice)
```

### Train Booking
```
Home Screen (Railway Mode)
  └── Train Search (from, to, date, class, passengers)
        └── Train Results (available trains with timings)
              └── Passenger Form
                    └── Card Payment
                          └── E-Ticket
```

### AI-Guided Trip Package (Naran / Hunza / Swat / Skardu)
```
AI Assistant chat (or native Trip Package screens)
  └── User states destination, dates, party size, budget
        └── Assistant searches transport + hotel (+ hub car transfer) and presents options
              └── User picks a flight/train, a hotel, and a transfer
                    └── Assistant returns one priced Trip Plan (budget check included)
                          └── User confirms — the assistant asks for the transfer pickup address
                                └── Passenger/guest details collected once for the whole package
                                      └── One card payment for the entire package
                                            └── One consolidated confirmation email, linked
                                                bookings visible together in My Bookings
```

---

## License

This project was developed as a Final Year Project for academic purposes.
All rights reserved © 2026 Travello AI Team.
