# Travello AI — Intelligent Travel Booking Platform

> A full-stack AI-powered travel booking application built as a Final Year Project.  
> Covers flight, train, and hotel booking for Pakistan with an integrated AI assistant, real-time notifications, and a professional booking management system.

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
11. [Screenshots & Flows](#11-screenshots--flows)
12. [Team](#12-team)

---

## 1. Project Overview

**Travello AI** is a cross-platform mobile and web travel booking system tailored for Pakistan. It lets users search, compare, and book flights, trains, and hotels through a single unified interface. The platform includes an AI travel assistant, saved search history, post-booking review system, real-time in-app notifications, and transactional email confirmations.

The backend is a RESTful API built with Python FastAPI, connected to a Supabase (PostgreSQL) database. The frontend is a Flutter application targeting Android, iOS, and Web from a single codebase.

---

## 2. Features

### Booking & Search
- **Flight Search** — Search domestic and international flights via Amadeus GDS API with cabin class, passenger count, and trip type filters
- **Hotel Search** — Search hotels by city with multi-source fallback: RapidAPI Hotels → Google Places → OpenStreetMap Nominatim → OSM Overpass → Mock data
- **Train Search** — Pakistan Railways train search with class, route, and date filters
- **Saved Searches** — Searches are auto-saved to the database; accessible from the Profile screen with one-tap re-run

### Booking Management
- **Full Booking Flow** — Passenger details, seat selection, baggage add-ons, and payment in a step-by-step flow
- **Multiple Payment Methods** — Credit/Debit Card, JazzCash, EasyPaisa, Bank Transfer
- **Booking History** — View all bookings (confirmed, pending, cancelled) with status badges
- **Booking Detail & E-Ticket** — Detailed ticket view with QR code, barcode, and PDF download/share
- **Cancel Booking** — Cancel pending or confirmed bookings with appropriate refund warnings
- **Remove from History** — Permanently delete cancelled bookings from the user's history

### Post-Booking
- **Email Confirmations** — Booking confirmation emails sent via Gmail SMTP after every successful payment
- **In-App Notifications** — Push-style in-app notifications for booking events
- **Review System** — Leave star ratings and comments on completed bookings; stored in Supabase
- **PDF Ticket Generation** — Download e-ticket as a PDF directly from the app

### User Profile
- **Authentication** — Email/password signup and login via Supabase Auth with JWT
- **Profile Management** — Edit name, phone, profile picture
- **Wishlist** — Save favourite flights, hotels, or trains
- **Saved Searches** — Browse and re-run past searches by type (flight, train, hotel)
- **FAQ, Terms, Privacy Policy, Cancellation Policy**

### AI Assistant
- **Integrated chat interface** for travel queries, recommendations, and booking guidance

### Explore
- City destinations, promotional offers, package deals, vouchers, weather information, healthcare facility search

---

## 3. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                            │
│              Flutter App (Android / iOS / Web)              │
│   Screens → Widgets → Controllers (GetX) → Services        │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS / REST API
┌─────────────────────▼───────────────────────────────────────┐
│                    API LAYER                                 │
│              Python FastAPI Backend                         │
│   Routers → Services → Models → Core (Auth / DB / Email)   │
└──────┬──────────────┬───────────────────────┬───────────────┘
       │              │                       │
┌──────▼──────┐ ┌─────▼──────┐  ┌────────────▼──────────────┐
│  Supabase   │ │ Third-Party│  │      Gmail SMTP           │
│ PostgreSQL  │ │    APIs    │  │  (Email Confirmations)    │
│  + Auth     │ │ Amadeus    │  └───────────────────────────┘
│  + Storage  │ │ RapidAPI   │
└─────────────┘ │ Google     │
                │ Places     │
                │ OSM / OWM  │
                └────────────┘
```

### Data Flow — Booking
```
User fills form → Flutter calls POST /flights/book (or /hotels/book, /trains/book)
→ Backend creates booking (status: pending) in Supabase
→ Flutter calls POST /payments/initiate
→ Backend marks booking as confirmed, creates payment_attempt row
→ Backend triggers email confirmation (Gmail SMTP)
→ Flutter shows payment_status / hotel_booking_confirmation screen
→ In-app notification pushed to user
```

---

## 4. Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile Frontend | Flutter (Dart) | 3.x / Dart 3.4+ |
| State Management | GetX | 4.7.3 |
| Backend Framework | FastAPI | 0.115.6 |
| Backend Runtime | Python | 3.11+ |
| ASGI Server | Uvicorn | 0.32.1 |
| Database | Supabase (PostgreSQL) | — |
| Auth | Supabase JWT | — |
| Async DB Driver | asyncpg | 0.30.0 |
| HTTP Client (backend) | httpx | 0.26–0.28 |
| HTTP Client (Flutter) | http | 1.2.2 |
| Local Storage | SharedPreferences | 2.3.2 |
| PDF Generation | pdf + printing | 3.12.0 / 5.13.4 |
| QR / Barcode | qr_flutter, barcode_widget | 4.1.0 / 2.0.4 |
| Maps | flutter_map + latlong2 | 7.0.2 / 0.9.1 |
| Email | Gmail SMTP | — |
| Flight Data | Amadeus GDS API | — |
| Hotel Data | RapidAPI Hotels4 + Google Places + OSM | — |
| Train Data | Pakistan Railways | — |
| Deployment | Render | — |
| JSON | orjson | 3.10.12 |
| Fonts | Ubuntu (Regular, Medium, Bold) | — |

---

## 5. Project Structure

```
Travello-AI-Project/
│
├── app/                            # Flutter mobile application
│   └── lib/
│       ├── main.dart               # App entry point
│       ├── app/                    # Routing & navigation
│       │   ├── app_link.dart       # Named route constants
│       │   ├── app_routes.dart     # GetX route definitions
│       │   └── routes_*.dart       # Per-module route files
│       │
│       ├── models/                 # Dart data models
│       │   ├── user.dart
│       │   ├── flight.dart
│       │   ├── hotel.dart
│       │   ├── train.dart
│       │   ├── booking.dart
│       │   ├── payment.dart
│       │   ├── airport.dart
│       │   ├── railway_station.dart
│       │   └── ...
│       │
│       ├── screens/                # Feature screens
│       │   ├── auth/               # Login, Register, OTP, Reset Password
│       │   ├── home/               # Unified home screen
│       │   ├── flight/             # Search, Results, Detail
│       │   ├── hotel/              # Search, Results, Detail, Checkout
│       │   ├── railway/            # Train search, Results, Detail
│       │   ├── booking/            # Flight/train booking flow
│       │   ├── railway_booking/    # Train-specific booking flow
│       │   ├── payment/            # Payment methods, Status
│       │   ├── orders/             # My Bookings, Booking Detail, E-Ticket
│       │   ├── profile/            # Profile, Saved Searches, FAQ, etc.
│       │   ├── promo/              # Promotions, Vouchers, Packages
│       │   ├── explore/            # Destination discovery
│       │   ├── ai/                 # AI Assistant chat
│       │   ├── healthcare/         # Hospital/clinic search
│       │   ├── wishlist/           # Saved favourites
│       │   └── intro/              # Onboarding & splash
│       │
│       ├── widgets/                # Reusable UI components
│       │   ├── cards/              # Flight, Hotel, Train, Ticket cards
│       │   ├── booking/            # Seat picker, baggage, passenger forms
│       │   ├── payment/            # Card, wallet, bank transfer forms
│       │   ├── search_filters/     # Search forms, filters, sorting
│       │   ├── home/               # Banners, sliders, sections
│       │   ├── bottom_navigation/  # App navigation bar
│       │   └── ...
│       │
│       ├── controllers/            # GetX state controllers
│       ├── services/               # API & integration clients
│       │   ├── api_client.dart     # Central HTTP client for backend
│       │   ├── ai_service.dart     # AI assistant integration
│       │   ├── notification_service.dart
│       │   └── transactional_service.dart
│       │
│       ├── utils/                  # Helpers & utilities
│       │   ├── auth_service.dart
│       │   ├── booking_service.dart    # Local booking storage
│       │   ├── search_history_service.dart
│       │   └── responsive_helper.dart
│       │
│       ├── constants/              # App constants & image paths
│       ├── config/                 # Supabase configuration
│       └── ui/
│           ├── themes/             # TravelloTheme design system
│           └── layouts/            # Shared layout wrappers
│
│   ├── assets/
│   │   ├── images/                 # Banners, logos, empty state SVGs
│   │   └── fonts/                  # Ubuntu font family
│   └── (android/ ios/ web/ windows/ linux/ macos/)
│
│
├── backend/                        # Python FastAPI server
│   ├── main.py                     # App entry point, router registration
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── render.yaml                 # Render deployment config
│   │
│   ├── core/
│   │   ├── config.py               # Settings from .env (pydantic-settings)
│   │   ├── auth.py                 # JWT verification (Supabase tokens)
│   │   ├── database.py             # asyncpg pool init/close
│   │   ├── email.py                # Gmail SMTP email sender
│   │   └── supabase_client.py      # Supabase admin + anon clients
│   │
│   ├── models/                     # Pydantic request/response schemas
│   │   ├── user.py
│   │   ├── flight.py
│   │   ├── hotel.py
│   │   ├── train.py
│   │   ├── booking.py
│   │   └── payment.py
│   │
│   ├── routers/                    # REST API route handlers
│   │   ├── auth.py                 # POST /auth/login, /auth/signup
│   │   ├── flights.py              # POST /flights/search, POST /flights/book
│   │   ├── hotels.py               # POST /hotels/search, POST /hotels/book
│   │   ├── trains.py               # POST /trains/search, POST /trains/book
│   │   ├── bookings.py             # GET/PUT/DELETE /bookings
│   │   ├── passengers.py           # POST /passengers
│   │   ├── payments.py             # POST /payments/initiate, /payments/verify-otp
│   │   ├── reviews.py              # POST /reviews, GET /reviews/booking/{id}
│   │   ├── notifications.py        # GET /notifications
│   │   ├── email.py                # POST /email/send
│   │   ├── wishlist.py             # GET/POST/DELETE /wishlist
│   │   ├── saved_searches.py       # GET/POST/DELETE /saved-searches
│   │   ├── weather.py              # GET /weather
│   │   └── healthcare.py           # GET /healthcare
│   │
│   ├── services/                   # Business logic
│   │   ├── flight_service.py       # Amadeus GDS integration + fallback
│   │   ├── hotel_service.py        # RapidAPI → Google Places → OSM → Mock
│   │   ├── train_service.py        # Pakistan Railways data & search
│   │   ├── booking_service.py      # Booking CRUD, status management
│   │   ├── payment_service.py      # Payment initiation, OTP, confirmation
│   │   ├── email_service.py        # Gmail SMTP transactional emails
│   │   └── weather_service.py      # Weather API integration
│   │
│   └── sql/                        # Database schema (run in order)
│       ├── 01_profiles.sql
│       ├── 02_bookings.sql
│       ├── 03_payments.sql
│       ├── 04_passengers.sql
│       ├── 05_wishlist.sql
│       ├── 06_notifications.sql
│       ├── 07_indexes_and_triggers.sql
│       ├── 08_security_fixes.sql
│       └── 09_ai_agent.sql
│
└── documentation/
    └── Overview.md
```

---

## 6. Database Schema

All tables live in Supabase (PostgreSQL) with Row Level Security (RLS) enabled.

| Table | Purpose |
|---|---|
| `profiles` | Extended user data linked to Supabase Auth (`auth.users`) |
| `bookings` | All booking records — flights, hotels, trains. Status: `pending → confirmed → cancelled` |
| `payment_attempts` | Payment transaction log per booking |
| `passengers` | Passenger details attached to each booking |
| `reviews` | Post-booking star ratings and comments (one per booking) |
| `wishlist` | User-saved favourite routes/hotels |
| `saved_searches` | Auto-saved search parameters per user |
| `notifications` | In-app notification log per user |

### Booking Status Flow
```
pending  →  confirmed  →  (completed)
    ↓
 cancelled
```

---

## 7. API Reference

Base URL: `http://<your-server>/` (local: `http://10.0.2.2:8000/` for Android emulator)

### Authentication
| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/signup` | Register a new user |
| POST | `/auth/login` | Login, returns JWT token |
| POST | `/auth/refresh` | Refresh access token |
| DELETE | `/auth/account` | Delete user account |

### Search
| Method | Endpoint | Description |
|---|---|---|
| POST | `/flights/search` | Search flights (Amadeus) |
| POST | `/hotels/search` | Search hotels (RapidAPI / Google Places / OSM) |
| POST | `/trains/search` | Search Pakistan Railways trains |

### Booking
| Method | Endpoint | Description |
|---|---|---|
| POST | `/flights/book` | Create a flight booking |
| POST | `/hotels/book` | Create a hotel booking |
| POST | `/trains/book` | Create a train booking |
| GET | `/bookings` | List all user bookings (paginated) |
| GET | `/bookings/{id}` | Get single booking detail |
| PUT | `/bookings/{id}/cancel` | Cancel a booking |
| DELETE | `/bookings/{id}` | Remove cancelled booking from history |
| GET | `/bookings/{id}/ticket` | Get structured ticket data |

### Passengers
| Method | Endpoint | Description |
|---|---|---|
| POST | `/passengers` | Add passengers to a booking |

### Payments
| Method | Endpoint | Description |
|---|---|---|
| POST | `/payments/initiate` | Start payment (card / bank transfer / wallet) |
| POST | `/payments/verify-otp` | Verify OTP for wallet payments |
| GET | `/payments/{booking_id}` | Get payment history for a booking |

### Reviews
| Method | Endpoint | Description |
|---|---|---|
| POST | `/reviews` | Submit or update a review for a booking |
| GET | `/reviews/booking/{booking_id}` | Get review for a booking |
| GET | `/reviews/my` | Get all reviews by current user |

### Other
| Method | Endpoint | Description |
|---|---|---|
| GET | `/notifications` | Get user notifications |
| GET/POST/DELETE | `/wishlist` | Manage wishlist items |
| GET/POST/DELETE | `/saved-searches` | Manage saved searches |
| GET | `/weather` | Get weather data for a city |
| GET | `/healthcare` | Search hospitals/clinics |
| GET | `/health` | Server health check |

---

## 8. Getting Started

### Prerequisites

- Flutter SDK 3.x ([flutter.dev](https://flutter.dev))
- Dart SDK 3.4+
- Python 3.11+
- pip
- A [Supabase](https://supabase.com) project (free tier works)
- Android Studio / Xcode (for mobile targets)

---

### Backend Setup

**1. Clone the repository**
```bash
git clone https://github.com/your-username/Travello-AI-Project.git
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
```bash
cp .env.example .env
# Edit .env with your credentials (see Environment Variables section)
```

**5. Set up the database**

Run the SQL files in order inside your Supabase SQL Editor:
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
```

**6. Start the server**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`  
Interactive docs at `http://localhost:8000/docs`

---

### Flutter App Setup

**1. Navigate to the app directory**
```bash
cd Travello-AI-Project/app
```

**2. Install Flutter dependencies**
```bash
flutter pub get
```

**3. Configure the backend URL**

Open `lib/services/api_client.dart` and update `_baseUrl` to point to your running backend:
```dart
// For Android emulator
static const String _baseUrl = 'http://10.0.2.2:8000';

// For physical device (use your machine's local IP)
static const String _baseUrl = 'http://192.168.x.x:8000';

// For production
static const String _baseUrl = 'https://your-backend.onrender.com';
```

**4. Configure Supabase**

Open `lib/config/supabase_config.dart` and add your Supabase project URL and anon key.

**5. Run the app**
```bash
# Android
flutter run

# Web
flutter run -d chrome

# iOS (macOS only)
flutter run -d ios
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

# ── Database (direct connection) ─────────────────────────
DATABASE_URL=postgresql://postgres:password@db.your-project.supabase.co:5432/postgres

# ── JWT ───────────────────────────────────────────────────
SUPABASE_JWT_SECRET=your-jwt-secret

# ── Email (Gmail SMTP) ────────────────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password        # Use a Gmail App Password, not your main password

# ── Flight API ────────────────────────────────────────────
AMADEUS_CLIENT_ID=your-amadeus-client-id
AMADEUS_CLIENT_SECRET=your-amadeus-client-secret

# ── Hotel APIs ────────────────────────────────────────────
RAPIDAPI_KEY=your-rapidapi-key
GOOGLE_PLACES_API_KEY=your-google-places-key

# ── Weather ───────────────────────────────────────────────
OPENWEATHER_API_KEY=your-openweather-key
```

> **Gmail SMTP note:** Go to your Google Account → Security → 2-Step Verification → App Passwords. Generate an app password and use it as `SMTP_PASSWORD`.

---

## 10. Third-Party Integrations

| Service | Purpose | Fallback |
|---|---|---|
| **Amadeus GDS** | Live flight search | Mock flight data |
| **RapidAPI Hotels4** | Hotel search | Google Places → OSM → Mock |
| **Google Places API** | Hotel search fallback | OSM Nominatim |
| **OpenStreetMap (Nominatim + Overpass)** | Hotel/location data | Mock hotel data |
| **Gmail SMTP** | Booking confirmation emails | Silent fail (logged) |
| **OpenWeatherMap** | City weather data | — |
| **Supabase** | Database, Auth, Storage | — |

All external API calls include fallback chains so the app remains functional even if individual APIs are unavailable or quota-limited.

---

## 11. Screenshots & Flows

### User Journey — Flight Booking
```
Home Screen
  └── Flight Search (origin, destination, date, passengers, class)
        └── Flight Results (list with price, duration, airline)
              └── Flight Detail (amenities, fare breakdown)
                    └── Passenger Form (name, CNIC, passport)
                          └── Extras (baggage, seat selection)
                                └── Payment Screen (card / wallet / bank)
                                      └── Payment Status (confirmed + email sent)
                                            └── E-Ticket (QR code, PDF download)
```

### User Journey — Hotel Booking
```
Home Screen
  └── Hotel Search (city, check-in, check-out, rooms, guests)
        └── Hotel Results (list with rating, price/night)
              └── Hotel Detail (amenities, room types, map)
                    └── Guest Form (name, contact)
                          └── Hotel Checkout (price breakdown)
                                └── Payment Screen
                                      └── Hotel Booking Confirmation (PDF invoice)
```

### User Journey — Train Booking
```
Home Screen (Railway Mode)
  └── Train Search (from, to, date, class, passengers)
        └── Train Results (available trains with timings)
              └── Train Detail (seats, class options)
                    └── Passenger Form
                          └── Payment
                                └── E-Ticket
```

---

## 12. Team

**Institution:** [Your University Name]  
**Department:** Computer Science / Software Engineering  
**Supervisor:** [Supervisor Name]  
**Academic Year:** 2025–2026

| Name | Role |
|---|---|
| Sameed Fareed | Full-Stack Developer (Flutter + FastAPI) |
| [Team Member 2] | [Role] |
| [Team Member 3] | [Role] |

---

## License

This project was developed as a Final Year Project for academic purposes.  
All rights reserved © 2026 Travello AI Team.
