# Travello AI — Demo Checklist

## Before Demo (30 min before)

- [ ] Backend running: `python main.py` OR deployed on Render.com
- [ ] SQL migrations run (01–08 in Supabase SQL Editor, in order)
- [ ] `.env` filled: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `RESEND_API_KEY`
- [ ] Test email: `GET /email/test` (with Bearer token in Swagger `/docs`)
- [ ] Test login on physical device or emulator
- [ ] Check backend startup logs — should show ✅ for Supabase and ✅ for Resend

## Demo Flow (8 minutes)

1. [ ] Open app → home screen with deals, destinations, and weather widget
2. [ ] Search KHI → LHE flight, select tomorrow's date
3. [ ] Select PIA flight → tap Book
4. [ ] Fill passenger details (CNIC format: `42101-1234567-1`)
5. [ ] Select JazzCash → OTP arrives on contact email
6. [ ] Enter OTP → Booking Confirmed screen with PNR
7. [ ] View e-ticket → show QR code and barcode
8. [ ] Check My Bookings → booking appears with PAID status
9. [ ] Check Notifications → "Flight Booking Confirmed ✅" notification
10. [ ] Open Healthcare → show hospitals near location
11. [ ] Show Weather widget on home screen
12. [ ] Show Wishlist — save a hotel deal
13. [ ] Show Profile → change currency preference

## If API Fails During Demo

- [ ] Run `python demo_seed.py` → creates 4 pre-seeded paid bookings
- [ ] Show My Bookings with seeded data (2 flights, 1 hotel, 1 train)
- [ ] Say: "Backend is live on Render — this is cached demo data"

## Email Troubleshooting

- [ ] `GET /email/test` in Swagger → check `status` field in response
- [ ] `email_configured: false` → set `RESEND_API_KEY` in `.env`
- [ ] `status: "sent"` → email working correctly
- [ ] OTP still appears in backend logs even if email delivery fails

## Environment Variables Checklist

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_JWT_SECRET=your-jwt-secret
RESEND_API_KEY=re_...
EMAIL_FROM=Travello AI <onboarding@resend.dev>
```

## Quick Commands

```bash
# Start backend
cd backend && python main.py

# Seed demo data
cd backend && python demo_seed.py

# Build Flutter web (with backend URL)
cd app && flutter build web --release \
  --dart-define=BACKEND_BASE_URL=https://travello-backend.onrender.com

# Run Flutter (Android emulator)
cd app && flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```
