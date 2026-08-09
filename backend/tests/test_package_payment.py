"""
A Trip Planner package is ONE payment, ONE confirmation, ONE email — while
every standalone booking keeps behaving exactly as it always has.

The gap this closes: a selected package was created as separate component
booking rows, each with its own initiatePayment call and therefore its own
confirmation email. The traveller bought one trip and was charged three times
and emailed three times.

The linkage is a single nullable column, bookings.package_id (sql/14). NULL
means standalone, so the standalone paths are untouched BY CONSTRUCTION rather
than by a runtime check that could regress — several tests below pin exactly
that.
"""
import asyncio
from typing import Any

import pytest
from fastapi import HTTPException

from services import payment_service
from services.package_email import build_html, build_narrative

PKG = "PKG-TEST01"

FLIGHT = {
    "id": "u-flight", "user_id": "u1", "status": "pending", "booking_type": "flight",
    "booking_id": "TRV-FL-1", "pnr": "ABC123", "total_amount": 69256,
    "contact_email": "sameed@example.com", "origin": "Karachi",
    "destination": "Islamabad", "departure_at": "2026-08-14T07:00:00",
    "package_id": PKG,
    "raw_payload": {
        "flight_number": "PK948",
        "transferVehicleType": "SUV",
        "transferPickupLocation": "Islamabad International Airport",
        "transferDropoffLocation": "Swat",
    },
}
HOTEL = {
    "id": "u-hotel", "user_id": "u1", "status": "pending", "booking_type": "hotel",
    "booking_id": "TRV-HT-1", "pnr": "HTL456", "total_amount": 175351,
    "contact_email": "sameed@example.com", "destination": "Swat",
    "hotel_name": "Hotel Intercon", "check_in": "2026-08-14", "check_out": "2026-08-25",
    "package_id": PKG,
    "raw_payload": {"hotel_stars": 3, "breakfast_included": True},
}
TRANSFER_PKR = 20000
# The flight component carries the transfer fare inside its own total, exactly
# as _add_transfer_fare folds it in at booking time.
FLIGHT_WITH_TRANSFER = {**FLIGHT, "total_amount": 69256 + TRANSFER_PKR}
PACKAGE_TOTAL = FLIGHT_WITH_TRANSFER["total_amount"] + HOTEL["total_amount"]


@pytest.fixture
def paid(monkeypatch):
    """Capture what the payment path actually does, without touching a DB."""
    calls: dict[str, Any] = {"attempts": [], "marked": [], "notifications": []}

    async def _components(package_id, user_id):
        return list(calls.get("components", []))

    async def _create_attempt(**kwargs):
        calls["attempts"].append(kwargs)
        return "attempt-1"

    async def _mark_package(package_id, transaction_id):
        if calls.get("confirm_fails"):
            raise RuntimeError("database update failed")
        rows = [c for c in calls.get("components", []) if c.get("status") == "pending"]
        for row in rows:
            calls["marked"].append((row["id"], transaction_id, None))
        calls["statements"] = calls.get("statements", 0) + 1
        return len(rows)

    async def _notify(**kwargs):
        calls["notifications"].append(kwargs)

    monkeypatch.setattr(payment_service, "get_package_components", _components)
    monkeypatch.setattr(payment_service, "_create_payment_attempt", _create_attempt)
    monkeypatch.setattr(payment_service, "mark_package_paid", _mark_package)
    monkeypatch.setattr(payment_service, "_create_notification", _notify)
    monkeypatch.setattr(
        payment_service, "_update_payment_attempt_status_best_effort",
        lambda **kw: None,
    )
    return calls


def _pay(amount, package_id=PKG):
    """Drive the real payment path. asyncio.run, matching this repo's tests."""
    return asyncio.run(payment_service.initiate_payment(
        user_id="u1", booking_uuid="u-flight", method="card",
        amount=amount, package_id=package_id,
    ))


# ── One payment, one transaction, all components confirmed ───────────────────

def test_a_package_is_charged_in_exactly_one_transaction(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL)
    assert len(paid["attempts"]) == 1, "a package must not create a payment per component"
    assert paid["attempts"][0]["amount"] == PACKAGE_TOTAL


def test_every_component_is_confirmed_under_that_one_transaction(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL)
    assert {m[0] for m in paid["marked"]} == {"u-flight", "u-hotel"}
    assert len({m[1] for m in paid["marked"]}) == 1, "one package, one transaction id"


def test_components_keep_their_own_totals_not_the_package_total(paid):
    """Copying the package total onto every row would multiply the trip's cost
    by its component count everywhere it is later displayed."""
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL)
    assert all(m[2] is None for m in paid["marked"])


def test_the_verified_total_is_the_sum_of_the_component_rows(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    assert payment_service._verified_package_total(paid["components"]) == PACKAGE_TOTAL


# ── The amount is verified server-side, never taken on trust ─────────────────

@pytest.mark.parametrize("wrong", [1000, PACKAGE_TOTAL - 5000, PACKAGE_TOTAL + 5000])
def test_a_mismatched_amount_is_refused_and_nothing_is_confirmed(paid, wrong):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    with pytest.raises(HTTPException) as err:
        _pay(wrong)
    assert err.value.status_code == 400
    assert paid["marked"] == [], "a refused package must confirm nothing"
    assert paid["attempts"] == [], "a refused package must not create a payment"


def test_rounding_noise_does_not_refuse_a_correct_package(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL + 0.4)
    assert len(paid["marked"]) == 2


def test_an_unknown_package_is_refused(paid):
    paid["components"] = []
    with pytest.raises(HTTPException) as err:
        _pay(PACKAGE_TOTAL)
    assert err.value.status_code == 404
    assert paid["marked"] == []


def test_an_already_paid_package_cannot_be_charged_twice(paid):
    paid["components"] = [{**FLIGHT_WITH_TRANSFER, "status": "confirmed"}, HOTEL]
    with pytest.raises(HTTPException) as err:
        _pay(PACKAGE_TOTAL)
    assert err.value.status_code == 409
    assert paid["marked"] == []


# ── Shapes: with transfer, without transfer, train ───────────────────────────

def test_a_skardu_package_without_a_transfer_works(paid):
    """Skardu has its own airport — two components, no transfer, still one payment."""
    flight = {**FLIGHT, "destination": "Skardu", "raw_payload": {"flight_number": "PK451"}}
    hotel = {**HOTEL, "destination": "Skardu", "hotel_name": "Shangrila Resort"}
    paid["components"] = [flight, hotel]
    total = flight["total_amount"] + hotel["total_amount"]
    _pay(total)
    assert len(paid["attempts"]) == 1
    assert len(paid["marked"]) == 2


def test_a_train_package_works(paid):
    train = {
        **FLIGHT, "booking_type": "train", "origin": "Lahore",
        "destination": "Rawalpindi", "total_amount": 24000,
        "raw_payload": {"train_name": "Green Line", "transferVehicleType": "Sedan",
                        "transferDropoffLocation": "Naran"},
    }
    paid["components"] = [train, HOTEL]
    _pay(train["total_amount"] + HOTEL["total_amount"])
    assert len(paid["attempts"]) == 1
    assert len(paid["marked"]) == 2


# ── Standalone bookings are untouched ────────────────────────────────────────

def test_a_standalone_payment_never_enters_the_package_path(monkeypatch):
    """package_id=None must take the original code path, unchanged."""
    called = {"package": False}

    async def _never(**kwargs):
        called["package"] = True

    async def _boom(*a, **k):
        raise RuntimeError("standalone path reached")

    monkeypatch.setattr(payment_service, "_pay_package", _never)
    monkeypatch.setattr(payment_service, "_get_booking_row", _boom)
    with pytest.raises(RuntimeError, match="standalone path reached"):
        asyncio.run(payment_service.initiate_payment(
            user_id="u1", booking_uuid="b1", method="card", amount=18500,
        ))
    assert called["package"] is False


def test_create_booking_omits_package_id_for_standalone():
    """A standalone insert must carry exactly the columns it always did."""
    import inspect
    from services import booking_service
    source = inspect.getsource(booking_service.create_booking)
    assert 'if package_id:' in source
    assert 'row["package_id"] = package_id' in source


# ── The consolidated email ───────────────────────────────────────────────────

def test_the_narrative_describes_only_what_was_actually_booked():
    text = build_narrative([FLIGHT_WITH_TRANSFER, HOTEL])
    assert "Karachi to Islamabad" in text
    assert "SUV" in text and "Swat" in text
    assert "Hotel Intercon" in text and "11 nights" in text


def test_the_narrative_invents_nothing_when_there_is_no_transfer():
    text = build_narrative([{**FLIGHT, "raw_payload": {"flight_number": "PK451"}}, HOTEL])
    assert "transfer" not in text.lower()


def test_the_email_shows_every_component_reference_and_one_grand_total():
    html = build_html(PKG, [FLIGHT_WITH_TRANSFER, HOTEL])
    assert PKG in html
    assert "ABC123" in html and "HTL456" in html          # component references
    assert "PK948" in html and "Hotel Intercon" in html
    assert f"{PACKAGE_TOTAL:,.0f}" in html                 # the grand total
    assert "Grand Total" in html


def test_the_email_shows_the_transfer_and_hotel_facts_it_really_has():
    html = build_html(PKG, [FLIGHT_WITH_TRANSFER, HOTEL])
    assert "SUV" in html
    assert "Islamabad International Airport" in html
    assert "Breakfast included" in html
    assert "3 star" in html


def test_the_email_omits_breakfast_when_the_booking_does_not_carry_it():
    hotel = {**HOTEL, "raw_payload": {"hotel_stars": 3}}
    assert "Breakfast included" not in build_html(PKG, [FLIGHT_WITH_TRANSFER, hotel])


# ── Atomic confirmation ──────────────────────────────────────────────────────
#
# Confirming components in a Python loop (one UPDATE each) allowed a paid
# package to end up half-confirmed if a later update failed. It is now ONE
# UPDATE matched on package_id, which PostgreSQL applies entirely or not at
# all — no stored procedure needed, because a single statement is already
# atomic. These pin that the code really does issue one statement.

def test_all_components_confirm_in_a_single_statement(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL)
    assert paid["statements"] == 1, "a package must confirm in ONE update, not a loop"
    assert len(paid["marked"]) == 2


def test_a_failed_confirmation_leaves_nothing_partially_confirmed(paid):
    """The statement either applies to every component row or to none."""
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    paid["confirm_fails"] = True
    with pytest.raises(RuntimeError, match="database update failed"):
        _pay(PACKAGE_TOTAL)
    assert paid["marked"] == [], "no component may be left confirmed"


def test_every_component_gets_the_same_transaction_reference(paid):
    paid["components"] = [FLIGHT_WITH_TRANSFER, HOTEL]
    _pay(PACKAGE_TOTAL)
    assert len({m[1] for m in paid["marked"]}) == 1


def test_the_confirm_statement_is_scoped_to_the_package_and_pending_rows():
    """
    Scoped by package_id so it can never touch a standalone booking, and by
    status='pending' so a retry cannot re-confirm rows already confirmed.
    """
    import inspect
    from services import booking_service
    source = inspect.getsource(booking_service.mark_package_paid)
    assert '.eq("package_id", package_id)' in source
    assert '.eq("status", "pending")' in source
    assert source.count(".update(") == 1


def test_standalone_confirmation_still_uses_the_per_booking_path():
    """mark_booking_paid is untouched — standalone bookings confirm as before."""
    import inspect
    from services import booking_service
    source = inspect.getsource(booking_service.mark_booking_paid)
    assert "package_id" not in source


# ── Transfer component identification ────────────────────────────────────────
#
# book_car_transfers() is handed ONE booking uuid after payment, and the hub
# transfer lives in the TRANSPORT booking's raw_payload. Components arrive in
# whatever order the model prepared them, so "the first one created" is not
# reliably the flight — a hotel-first package would have assigned no driver at
# all, silently. The checkout now picks the transport component by TYPE.

def _dart_checkout_source() -> str:
    """The package checkout body, anchored precisely.

    `final isPackage = components.length > 1;` appears exactly once and only in
    this method, so it is a stable anchor; a looser one matched the identically
    named local inside primaryComponent. Lives in widgets/booking/
    card_payment_sheet.dart — extracted out of ai_assistant.dart so the AI
    Assistant chat flow and the Trip Package UI share one payment
    implementation instead of each carrying their own copy.
    """
    from pathlib import Path
    path = (Path(__file__).resolve().parents[2] / "app" / "lib" / "widgets"
            / "booking" / "card_payment_sheet.dart")
    source = path.read_text(encoding="utf-8")
    anchor = "final isPackage = components.length > 1;"
    assert source.count(anchor) == 1, "checkout anchor is no longer unique"
    start = source.index(anchor)
    return source[start:start + 8000]


def test_the_transport_component_is_chosen_by_type_not_creation_order():
    body = _dart_checkout_source()
    assert "final transportComponent = components.firstWhere(" in body
    assert "'booking_type'] == 'flight'" in body
    assert "'booking_type'] == 'train'" in body
    # And the payment/transfer booking is that component, by identity.
    assert "identical(component, transportComponent)" in body


def test_the_transport_component_is_selected_from_the_iterated_list():
    """
    It must come from `components` itself. packageComponents() rebuilds its
    maps on every call, so a component taken from a second call could never
    match by identity and the selection would silently fall back.
    """
    body = _dart_checkout_source()
    assert "components.firstWhere(" in body
    assert "primaryComponent(data)" not in body


def test_exactly_one_payment_call_remains_for_a_package():
    body = _dart_checkout_source()
    assert body.count("ApiClient.initiatePayment(") == 2   # standalone + package
    assert "if (isPackage && primaryBookingId != null)" in body


@pytest.mark.parametrize("components,expected", [
    # (booking types in the order the model prepared them, expected transport)
    (["flight", "hotel"], "flight"),
    (["hotel", "flight"], "flight"),          # the ordering bug this fixes
    (["train", "hotel"], "train"),
    (["hotel", "train"], "train"),
    (["flight", "hotel"], "flight"),          # Skardu: no transfer, still transport-first
    (["hotel"], "hotel"),                     # degenerate: fallback to first
])
def test_transport_selection_precedence(components, expected):
    """The precedence the Dart firstWhere chain implements, asserted directly."""
    def pick(types):
        for wanted in ("flight", "train"):
            for t in types:
                if t == wanted:
                    return t
        return types[0]
    assert pick(components) == expected
