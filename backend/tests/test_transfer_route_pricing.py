"""
Unit tests for folding the northern hub->destination car leg into the SAME
prepare_booking package payment, instead of a separate standalone book_car
confirm — the route-aware transfer pricing, the money-correctness gate on
get_transfer_error, and the post-payment DB-write path.
"""
import asyncio

import pytest

from agents.agent_tools import _add_transfer_fare, get_transfer_error
from services import car_service


# ── _add_transfer_fare ────────────────────────────────────────────────────────

def test_ordinary_transfer_still_gets_the_flat_rate():
    verified = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "House 12, Block A, DHA Phase 5, Karachi",
        "total_price_pkr": 20000,
    }
    out = _add_transfer_fare(dict(verified))
    assert out["transfer_pkr"] == 3000
    assert out["total_price_pkr"] == 23000


def test_northern_hub_pickup_with_matching_dropoff_gets_the_routed_fare():
    verified = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Naran",
        "total_price_pkr": 32000,
    }
    out = _add_transfer_fare(dict(verified))
    assert out["transfer_pkr"] == 18000
    assert out["total_price_pkr"] == 50000


def test_already_priced_transfer_is_not_charged_twice():
    verified = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Naran",
        "transfer_pkr": 18000,
        "total_price_pkr": 50000,
    }
    out = _add_transfer_fare(dict(verified))
    assert out["total_price_pkr"] == 50000  # unchanged, not 68000


def test_no_vehicle_or_pickup_means_no_transfer_charged():
    verified = {"total_price_pkr": 20000}
    out = _add_transfer_fare(dict(verified))
    assert "transfer_pkr" not in out
    assert out["total_price_pkr"] == 20000


# ── get_transfer_error — backward compatibility (no new kwargs passed) ────────

def test_default_args_behave_exactly_as_before_this_field_existed():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "House 12, Block A, DHA Phase 5, Karachi",
    }
    assert get_transfer_error(bd) is None


def test_no_transfer_fields_at_all_is_not_an_error():
    assert get_transfer_error({}) is None


# ── get_transfer_error — new dropoff validation ────────────────────────────────

def test_placeholder_dropoff_is_rejected():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "your destination",
    }
    err = get_transfer_error(bd, user_texts=["take me to Naran please"])
    assert err is not None


def test_dropoff_never_mentioned_by_the_user_is_rejected():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Hunza",
    }
    err = get_transfer_error(bd, user_texts=["book me a car from the airport to Naran"])
    assert err is not None


def test_well_formed_grounded_dropoff_is_accepted():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Naran",
    }
    err = get_transfer_error(
        bd,
        user_texts=["plan a trip to Naran from Karachi for 2 people"],
        trip_destination="Naran",
    )
    assert err is None


# ── get_transfer_error — money-correctness gate ────────────────────────────────

def test_hub_pickup_missing_dropoff_is_blocked_not_flat_rate_fallback():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
    }
    err = get_transfer_error(
        bd,
        user_texts=["plan a trip to Naran from Karachi"],
        trip_destination="Naran",
    )
    assert err is not None


def test_hub_pickup_with_mismatched_dropoff_is_blocked():
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Islamabad International Airport",
        "transfer_dropoff_location": "Murree",
    }
    err = get_transfer_error(
        bd,
        user_texts=["plan a trip to Naran from Karachi", "actually drop me at Murree"],
        trip_destination="Naran",
    )
    assert err is not None


def test_ordinary_destination_never_triggers_the_hub_gate():
    # trip_destination="Lahore" is not a northern destination — hub_options_for
    # returns None, so the missing dropoff is simply an ordinary transfer.
    bd = {
        "transfer_vehicle_type": "Sedan",
        "transfer_pickup_location": "Jinnah International Airport",
    }
    err = get_transfer_error(
        bd,
        user_texts=["book me a flight to Lahore"],
        trip_destination="Lahore",
    )
    assert err is None


# ── Post-payment DB write path ────────────────────────────────────────────────

class _FakeResult:
    def __init__(self, data):
        self.data = data


class _FakeQuery:
    """Minimal chainable stand-in for the supabase-py query builder."""

    def __init__(self, table_name, store):
        self._table = table_name
        self._store = store
        self._single = False
        self._row = None

    def insert(self, row):
        self._row = row
        return self

    def select(self, *_a, **_k):
        return self

    def eq(self, *_a, **_k):
        return self

    def single(self):
        self._single = True
        return self

    def execute(self):
        if self._row is not None:
            self._store.setdefault(self._table, []).append(self._row)
            return _FakeResult([self._row])
        if self._table == "bookings":
            return _FakeResult(self._store["_booking_fixture"])
        return _FakeResult([])


class _FakeSupabase:
    def __init__(self, booking_fixture):
        self._store = {"_booking_fixture": booking_fixture}

    def table(self, name):
        return _FakeQuery(name, self._store)

    @property
    def inserted(self):
        return self._store.get("car_bookings", [])


def test_create_car_booking_row_writes_dropoff_and_the_routed_fare(monkeypatch):
    fake = _FakeSupabase(booking_fixture=None)
    monkeypatch.setattr(car_service, "supabase_admin", fake)

    driver = {"id": "d1", "name": "Ali"}
    row = car_service._create_car_booking_row(
        booking_uuid="b1",
        user_id="u1",
        driver=driver,
        transfer_type="departure",
        pickup_location="Islamabad International Airport",
        vehicle_type="Sedan",
        contact_email="x@example.com",
        verification_code="1234",
        dropoff_location="Naran",
    )
    assert row is not None
    assert row["dropoff_location"] == "Naran"
    assert row["total_amount"] == 18000  # routed fare, not the flat 3000


def test_create_car_booking_row_ordinary_transfer_keeps_flat_rate_and_no_dropoff(monkeypatch):
    fake = _FakeSupabase(booking_fixture=None)
    monkeypatch.setattr(car_service, "supabase_admin", fake)

    driver = {"id": "d1", "name": "Ali"}
    row = car_service._create_car_booking_row(
        booking_uuid="b1",
        user_id="u1",
        driver=driver,
        transfer_type="departure",
        pickup_location="House 12, Block A, DHA Phase 5, Karachi",
        vehicle_type="Sedan",
        contact_email="x@example.com",
        verification_code="1234",
    )
    assert row is not None
    assert row["dropoff_location"] is None
    assert row["total_amount"] == 3000


def test_book_car_transfers_threads_dropoff_from_raw_payload_through_to_the_row(monkeypatch):
    booking_fixture = {
        "id": "b1",
        "user_id": "u1",
        "contact_email": "x@example.com",
        "origin": "Karachi",
        "destination": "Islamabad",
        "departure_at": "2026-09-01T10:00:00",
        "booking_id": "TRV-1",
        "pnr": "ABC123",
        "raw_payload": {
            "transferAdded": True,
            "transferVehicleType": "Sedan",
            "transferPickupLocation": "Islamabad International Airport",
            "transferDropoffLocation": "Naran",
        },
    }
    fake = _FakeSupabase(booking_fixture=booking_fixture)
    monkeypatch.setattr(car_service, "supabase_admin", fake)
    monkeypatch.setattr(car_service, "_pick_driver", lambda vehicle: {"id": "d1", "name": "Ali"})
    monkeypatch.setattr(car_service, "_generate_verification_code", lambda: "1234")

    async def _fake_consolidated_email(**kwargs):
        return {"sent": False}

    async def _fake_internal_summary(**kwargs):
        return None

    import services.email_service as email_service
    monkeypatch.setattr(email_service, "send_consolidated_car_booking_email", _fake_consolidated_email)
    monkeypatch.setattr(email_service, "send_internal_car_booking_summary", _fake_internal_summary)

    asyncio.run(car_service.book_car_transfers("b1"))

    assert len(fake.inserted) == 1
    row = fake.inserted[0]
    assert row["dropoff_location"] == "Naran"
    assert row["total_amount"] == 18000
    assert row["transfer_type"] == "departure"
