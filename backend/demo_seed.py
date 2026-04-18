"""
Demo seed script for Travello AI.
Creates realistic pre-populated bookings for the demo account.

Usage:
    python demo_seed.py

Requires:
    - .env with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
    - Demo user must exist: demo@travello.ai (create via Supabase Auth or app signup)
"""

from __future__ import annotations

import sys
import uuid
from datetime import date, datetime, timedelta

from core.config import settings
from supabase import create_client

DEMO_EMAIL = "demo@travello.ai"

supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


def _uuid() -> str:
    return str(uuid.uuid4())


def get_demo_user_id() -> str | None:
    result = supabase.auth.admin.list_users()
    for user in result:
        if hasattr(user, "email") and user.email == DEMO_EMAIL:
            return user.id
    return None


def seed_flight_booking(user_id: str) -> str:
    booking_id = _uuid()
    readable = f"TRV-FL-{datetime.utcnow().strftime('%Y%m%d')}-{booking_id[:4].upper()}"
    departure = datetime.utcnow() + timedelta(days=7)
    arrival = departure + timedelta(hours=1, minutes=30)

    supabase.table("bookings").insert({
        "id": booking_id,
        "user_id": user_id,
        "booking_id": readable,
        "booking_type": "flight",
        "status": "paid",
        "total_amount": 18500,
        "currency": "PKR",
        "contact_email": DEMO_EMAIL,
        "contact_phone": "03001234567",
        "pnr": "PK7" + booking_id[:4].upper(),
        "origin": "Karachi (KHI)",
        "destination": "Lahore (LHE)",
        "departure_at": departure.isoformat(),
        "arrival_at": arrival.isoformat(),
        "raw_payload": {
            "airline": "PIA",
            "flight_number": "PK-301",
            "cabin_class": "Economy",
        },
    }).execute()

    pax = [
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Ali",
            "last_name": "Hassan",
            "title": "Mr",
            "cnic": "42101-1234567-1",
            "passenger_type": "adult",
            "seat_number": "12A",
        },
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Sara",
            "last_name": "Hassan",
            "title": "Mrs",
            "cnic": "42101-7654321-2",
            "passenger_type": "adult",
            "seat_number": "12B",
        },
    ]
    supabase.table("passengers").insert(pax).execute()

    supabase.table("payment_attempts").insert({
        "id": _uuid(),
        "user_id": user_id,
        "booking_id": booking_id,
        "payment_method": "jazzcash",
        "amount": 18500,
        "currency": "PKR",
        "status": "completed",
        "provider_reference": f"JC{datetime.utcnow().strftime('%Y%m%d%H%M%S')}000001",
    }).execute()

    print(f"  ✅ Flight booking created: {readable}  PNR: PK7{booking_id[:4].upper()}")
    return booking_id


def seed_hotel_booking(user_id: str) -> str:
    booking_id = _uuid()
    readable = f"TRV-HT-{datetime.utcnow().strftime('%Y%m%d')}-{booking_id[:4].upper()}"
    check_in = (date.today() + timedelta(days=14)).isoformat()
    check_out = (date.today() + timedelta(days=16)).isoformat()

    supabase.table("bookings").insert({
        "id": booking_id,
        "user_id": user_id,
        "booking_id": readable,
        "booking_type": "hotel",
        "status": "paid",
        "total_amount": 25000,
        "currency": "PKR",
        "contact_email": DEMO_EMAIL,
        "contact_phone": "03001234567",
        "pnr": "HTL" + booking_id[:4].upper(),
        "hotel_name": "Serena Hotel Lahore",
        "destination": "Lahore",
        "check_in": check_in,
        "check_out": check_out,
        "raw_payload": {
            "city": "Lahore",
            "guests": 2,
            "rooms": 1,
            "hotel_name": "Serena Hotel Lahore",
        },
    }).execute()

    supabase.table("payment_attempts").insert({
        "id": _uuid(),
        "user_id": user_id,
        "booking_id": booking_id,
        "payment_method": "card",
        "amount": 25000,
        "currency": "PKR",
        "status": "completed",
        "provider_reference": f"CRD{datetime.utcnow().strftime('%Y%m%d%H%M%S')}000002",
    }).execute()

    print(f"  ✅ Hotel booking created:  {readable}  PNR: HTL{booking_id[:4].upper()}")
    return booking_id


def seed_train_booking(user_id: str) -> str:
    booking_id = _uuid()
    readable = f"TRV-TR-{datetime.utcnow().strftime('%Y%m%d')}-{booking_id[:4].upper()}"
    departure = datetime.utcnow() + timedelta(days=10, hours=8)
    arrival = departure + timedelta(hours=14)

    supabase.table("bookings").insert({
        "id": booking_id,
        "user_id": user_id,
        "booking_id": readable,
        "booking_type": "train",
        "status": "paid",
        "total_amount": 3200,
        "currency": "PKR",
        "contact_email": DEMO_EMAIL,
        "contact_phone": "03001234567",
        "pnr": "TGZ" + booking_id[:4].upper(),
        "origin": "Karachi City",
        "destination": "Lahore Junction",
        "departure_at": departure.isoformat(),
        "arrival_at": arrival.isoformat(),
        "raw_payload": {
            "train_name": "Tezgam Express",
            "train_number": "1-UP",
            "cabin_class": "AC Sleeper",
        },
    }).execute()

    pax = [
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Usman",
            "last_name": "Khan",
            "title": "Mr",
            "cnic": "35202-1122334-5",
            "passenger_type": "adult",
            "seat_number": "B4",
        },
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Fatima",
            "last_name": "Khan",
            "title": "Ms",
            "cnic": "35202-5544332-6",
            "passenger_type": "adult",
            "seat_number": "B5",
        },
    ]
    supabase.table("passengers").insert(pax).execute()

    supabase.table("payment_attempts").insert({
        "id": _uuid(),
        "user_id": user_id,
        "booking_id": booking_id,
        "payment_method": "easypaisa",
        "amount": 3200,
        "currency": "PKR",
        "status": "completed",
        "provider_reference": f"EP{datetime.utcnow().strftime('%Y%m%d%H%M%S')}000003",
    }).execute()

    print(f"  ✅ Train booking created:  {readable}  PNR: TGZ{booking_id[:4].upper()}")
    return booking_id


def seed_second_flight(user_id: str) -> str:
    booking_id = _uuid()
    readable = f"TRV-FL-{datetime.utcnow().strftime('%Y%m%d')}-{booking_id[:4].upper()}"
    departure = datetime.utcnow() + timedelta(days=21)
    arrival = departure + timedelta(hours=2, minutes=10)

    supabase.table("bookings").insert({
        "id": booking_id,
        "user_id": user_id,
        "booking_id": readable,
        "booking_type": "flight",
        "status": "paid",
        "total_amount": 32000,
        "currency": "PKR",
        "contact_email": DEMO_EMAIL,
        "contact_phone": "03001234567",
        "pnr": "PA9" + booking_id[:4].upper(),
        "origin": "Islamabad (ISB)",
        "destination": "Skardu (KDU)",
        "departure_at": departure.isoformat(),
        "arrival_at": arrival.isoformat(),
        "raw_payload": {
            "airline": "PIA",
            "flight_number": "PK-455",
            "cabin_class": "Economy",
        },
    }).execute()

    pax = [
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Sameed",
            "last_name": "Fareed",
            "title": "Mr",
            "cnic": "61101-9876543-3",
            "passenger_type": "adult",
            "seat_number": "8C",
        },
        {
            "id": _uuid(),
            "booking_id": booking_id,
            "user_id": user_id,
            "first_name": "Ayesha",
            "last_name": "Fareed",
            "title": "Ms",
            "cnic": "61101-3456789-4",
            "passenger_type": "adult",
            "seat_number": "8D",
        },
    ]
    supabase.table("passengers").insert(pax).execute()

    supabase.table("payment_attempts").insert({
        "id": _uuid(),
        "user_id": user_id,
        "booking_id": booking_id,
        "payment_method": "card",
        "amount": 32000,
        "currency": "PKR",
        "status": "completed",
        "provider_reference": f"CRD{datetime.utcnow().strftime('%Y%m%d%H%M%S')}000004",
    }).execute()

    print(f"  ✅ Flight booking created: {readable}  PNR: PA9{booking_id[:4].upper()}")
    return booking_id


def main() -> None:
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        print("❌ SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")
        sys.exit(1)

    print(f"\n🌱 Travello AI Demo Seed — {DEMO_EMAIL}")
    print("=" * 55)

    user_id = get_demo_user_id()
    if not user_id:
        print(
            f"❌ Demo user '{DEMO_EMAIL}' not found.\n"
            "   Create the account first via the app or Supabase Dashboard."
        )
        sys.exit(1)

    print(f"✅ Demo user found: {user_id[:8]}...\n")
    print("Creating bookings...")

    try:
        seed_flight_booking(user_id)
        seed_hotel_booking(user_id)
        seed_train_booking(user_id)
        seed_second_flight(user_id)

        print("\n✅ All demo bookings created successfully!")
        print(f"   Login with: {DEMO_EMAIL}")
        print("   Go to My Bookings to see all 4 bookings.\n")
    except Exception as exc:
        print(f"\n❌ Seed failed: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
