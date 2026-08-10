"""
Every transfer price the traveller sees is either sourced or says it isn't.

Two things this locks in.

CORRECTED FARES. Gilgit Airport -> Hunza was Sedan 7,000 / SUV 9,500. A named
operator (Wonderland Treks & Tours) quotes that exact leg one-way at "10k" for
a normal car and "18k to 20k" for a Prado TX/TZ, corroborated by a 2026 fare
calculator at ~12,720 for the 106km. The old SUV figure was roughly half the
real one — and this is the leg every flight-to-Hunza demo goes through.

LABELLED ESTIMATES. The rest of the table is mixed provenance, and the module
header used to call all of it "Real-researched", contradicting itself two lines
later with "mid estimate used". Anything we cannot attribute now renders as
"(Estimated)" beside the amount, because a comment the traveller never reads is
not a disclosure.

Provenance is a LOOKUP, never text: the label is re-derived from the fare table
every time it is rendered, so it cannot drift away from the price it describes.
"""
import json

import pytest

from agents import trip_selection as ts
from services.northern_routes import fare_is_estimated, price_for_route

FLIGHTS = json.dumps({
    "passengers": 2,
    "flights": [{"flight_number": "PK605", "airline": "PIA", "from": "KHI", "to": "GIL",
                 "depart": "2026-09-10 07:00", "arrive": "08:46", "cabin": "ECONOMY",
                 "total_price_pkr": 85120}],
})
TRAINS = json.dumps({
    "passengers": 2,
    "trains": [{"train_name": "Green Line", "train_number": "5-Up", "from": "Karachi",
                "to": "Rawalpindi", "depart": "2026-09-10 07:00",
                "arrive": "2026-09-11 05:00",
                "classes": [{"class": "AC Business", "total_price_pkr": 24000}]}],
})


def _hotels(city):
    return json.dumps({"city": city, "nights": 3, "rooms": 1, "guests": 2,
                       "hotels": [{"name": f"{city} Inn", "stars": 4,
                                   "price_per_night_pkr": 9000,
                                   "total_stay_pkr": 27000}]})


def _options(destination, mode="flight"):
    transport = ("search_trains", TRAINS) if mode == "train" else ("search_flights", FLIGHTS)
    return ts.build_options([transport, ("search_hotels", _hotels(destination))],
                            destination, preferred_mode=mode)


def _rendered(destination, mode="flight"):
    return ts.render_options(_options(destination, mode))


def _transfer_lines(text):
    return [l.strip() for l in text.splitlines()
            if "·" in l and "→" in l and "PKR" in l
            and any(v in l for v in ("Sedan", "SUV", "Van"))]


# ── The corrected Gilgit -> Hunza fares ──────────────────────────────────────

def test_the_gilgit_hunza_sedan_is_the_sourced_ten_thousand():
    """Wonderland Treks & Tours: "10k from airport to aliabad or Karimabad"."""
    assert price_for_route("Gilgit", "Hunza", "Sedan") == 10000


def test_the_gilgit_hunza_suv_is_the_sourced_eighteen_thousand():
    """Same operator: "18k to 20k" for a Prado TX/TZ — lower bound taken."""
    assert price_for_route("Gilgit", "Hunza", "SUV") == 18000


def test_the_corrected_fares_reach_the_traveller():
    lines = _transfer_lines(_rendered("Hunza"))
    assert any("Sedan" in l and "PKR 10,000" in l for l in lines)
    assert any("SUV" in l and "PKR 18,000" in l for l in lines)


def test_the_sourced_gilgit_hunza_fares_carry_no_estimate_label():
    for vehicle in ("Sedan", "SUV"):
        assert fare_is_estimated("Gilgit", "Hunza", vehicle) is False
    for line in _transfer_lines(_rendered("Hunza")):
        assert "(Estimated)" not in line, line


def test_the_gilgit_hunza_van_is_the_owner_defined_thirty_thousand():
    """Set by the operator, not quoted by anyone and not derived from the
    sedan/SUV figures above — which is precisely why it stays labelled."""
    assert price_for_route("Gilgit", "Hunza", "Van") == 30000


def test_the_unverified_van_price_is_not_presented_as_researched():
    """No van quote exists for this leg, so it must not look like the others."""
    assert fare_is_estimated("Gilgit", "Hunza", "Van") is True


def test_the_owner_defined_van_fare_reaches_the_traveller_labelled():
    """A party of 6-9 gets the van and only the van, so this is the single
    price that whole booking turns on — it must carry its label."""
    options = ts.build_options(
        [("search_flights", FLIGHTS), ("search_hotels", _hotels("Hunza"))],
        "Hunza", passengers=7, preferred_mode="flight")
    vans = [t for t in options["transfers"] if t["vehicle"] == "Van"]
    assert vans and all(t["fare_pkr"] == 30000 and t["estimated"] for t in vans)
    for line in _transfer_lines(ts.render_options(options)):
        assert "Van" in line and line.endswith("PKR 30,000 (Estimated)"), line


def test_the_gilgit_hunza_fares_no_longer_invert_by_vehicle_size():
    """The van briefly undercut the SUV, quoting a 6-9 party less than a
    couple. Bigger vehicle, never a smaller fare."""
    fares = [price_for_route("Gilgit", "Hunza", v) or 0
             for v in ("Sedan", "SUV", "Van")]
    assert all(fares)
    assert fares == sorted(fares) and len(set(fares)) == 3


# ── Estimated routes are labelled, everywhere they appear ────────────────────

@pytest.mark.parametrize("vehicle", ["Sedan", "SUV", "Van"])
def test_every_rawalpindi_hunza_fare_is_an_estimate(vehicle):
    assert fare_is_estimated("Rawalpindi", "Hunza", vehicle) is True


@pytest.mark.parametrize("hub,vehicle", [
    ("Islamabad", "Sedan"), ("Islamabad", "SUV"), ("Islamabad", "Van"),
    ("Rawalpindi", "Sedan"), ("Rawalpindi", "SUV"), ("Rawalpindi", "Van"),
])
def test_every_swat_fare_is_an_estimate(hub, vehicle):
    """The header itself said Swat was "estimated slightly below Naran"."""
    assert fare_is_estimated(hub, "Swat", vehicle) is True


@pytest.mark.parametrize("vehicle", ["Sedan", "SUV", "Van"])
def test_naran_keeps_its_claimed_research_anchor(vehicle):
    """Its ~PKR 18,000 anchor is claimed by the original research, so it is not
    relabelled — but see the module header: it was never re-verified."""
    assert fare_is_estimated("Islamabad", "Naran", vehicle) is False


def test_the_rawalpindi_hunza_options_say_estimated_to_the_traveller():
    lines = _transfer_lines(_rendered("Hunza", mode="train"))
    assert lines
    for line in lines:
        assert "Rawalpindi → Hunza" in line
        assert line.endswith("(Estimated)"), line


def test_the_swat_options_say_estimated_to_the_traveller():
    lines = _transfer_lines(_rendered("Swat"))
    assert lines and all(l.endswith("(Estimated)") for l in lines)


def test_the_naran_options_carry_no_estimate_label():
    lines = _transfer_lines(_rendered("Naran"))
    assert lines and not any("(Estimated)" in l for l in lines)


def test_the_label_is_not_hidden_in_comments_only():
    """The whole point: it is in the text the traveller reads."""
    assert "(Estimated)" in _rendered("Hunza", mode="train")


# ── The label survives options -> selection -> trip plan ─────────────────────

def _pick_through(destination, mode, vehicle_index=1):
    options = ts.parse_options(_rendered(destination, mode))
    picks = ts.merge_picks(
        options, f"Transport 1, Hotel 1, Transfer {vehicle_index}", {}).picks
    return options, picks, ts.build_plan(options, picks)


def test_an_estimated_fare_is_still_labelled_after_the_render_parse_round_trip():
    options = ts.parse_options(_rendered("Hunza", mode="train"))
    assert options["transfers"]
    assert all(t["estimated"] is True for t in options["transfers"])


def test_a_sourced_fare_is_still_unlabelled_after_the_round_trip():
    options = ts.parse_options(_rendered("Hunza"))
    assert options["transfers"]
    assert all(t["estimated"] is False for t in options["transfers"])


def test_the_estimate_label_reaches_the_final_trip_plan():
    options, picks, plan = _pick_through("Hunza", "train")
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Hunza")
    assert "**Transfer**" in text
    assert "(Estimated)" in text


def test_a_sourced_transfer_shows_no_label_in_the_trip_plan():
    options, picks, plan = _pick_through("Hunza", "flight")
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Hunza")
    assert "PKR 10,000" in text
    assert "(Estimated)" not in text


# ── Labelling changed no money ───────────────────────────────────────────────

def test_the_label_never_alters_the_fare_it_describes():
    for destination, mode in (("Hunza", "flight"), ("Hunza", "train"), ("Swat", "flight")):
        options, picks, plan = _pick_through(destination, mode)
        assert plan is not None
        transfer = plan.transfer
        assert transfer is not None
        assert transfer["fare_pkr"] == price_for_route(
            transfer["hub"], transfer["destination"], transfer["vehicle"])


def test_the_package_total_still_includes_the_transfer():
    _, _, plan = _pick_through("Hunza", "flight")
    assert plan is not None
    # bind local name to satisfy static checkers that plan is not None
    p = plan
    assert p.transfer is not None
    assert p.total_pkr == (
        p.transport_pkr + p.hotel_pkr + p.transfer["fare_pkr"])


def test_the_plan_total_equals_the_sum_of_the_selected_components():
    options, picks, plan = _pick_through("Hunza", "train")
    assert plan is not None
    transport = options["transport"][picks["transport"] - 1]["price_pkr"]
    hotel = options["hotels"][picks["hotel"] - 1]["price_pkr"]
    transfer = options["transfers"][picks["transfer"] - 1]["fare_pkr"]
    assert plan.total_pkr == transport + hotel + transfer


def test_the_estimate_flag_is_not_a_price_field():
    """It must never be mistaken for money by anything summing the row."""
    for t in _options("Hunza", "train")["transfers"]:
        assert isinstance(t["estimated"], bool)
        assert isinstance(t["fare_pkr"], int)


# ── Unrelated routes and standalone behaviour ────────────────────────────────

def test_an_ordinary_city_transfer_is_not_an_estimate():
    """It falls back to car_service's published flat rate, not a guess."""
    assert fare_is_estimated("DHA Phase 5, Karachi", "Jinnah Airport", "Sedan") is False


def test_provenance_is_resolved_from_the_same_row_as_the_price():
    """A fare and its label must never come from different table rows."""
    assert price_for_route("Gilgit Airport", "Karimabad, Hunza", "SUV") == 18000
    assert fare_is_estimated("Gilgit Airport", "Karimabad, Hunza", "SUV") is False
    assert fare_is_estimated("Gilgit Airport", "Karimabad, Hunza", "Van") is True


def test_standalone_car_pricing_is_unchanged():
    from services.car_service import estimate_fare

    assert estimate_fare("Sedan", "DHA Phase 5", "Jinnah International Airport") == 3000
    assert estimate_fare("SUV") == 6000
    assert estimate_fare("Van", "", "") == 9000


def test_standalone_tool_selection_is_unchanged():
    from agents.prompt_builder import select_tool_names

    assert select_tool_names("book me a sedan to Naran for tomorrow 9am") == ["book_car"]
    assert select_tool_names("find me a hotel in Islamabad for 3 nights") == ["search_hotels"]


# ── The header no longer overclaims ──────────────────────────────────────────

def test_the_module_header_does_not_call_every_fare_researched():
    import inspect

    import services.northern_routes as nr

    source = inspect.getsource(nr)
    header = source[:source.index("_ROUTE_FARES: dict")]
    assert "Real-researched one-way hub" not in header
    assert "PROVENANCE IS MIXED" in header
    assert "SOURCED" in header and "ESTIMATED" in header
    assert "Wonderland Treks & Tours" in header      # the source is named


# ── The real fare survives a pickup address that never names the hub ────────
#
# Observed live: a traveller answering "what's the pickup address?" with a
# real landmark ("near point to hunza") instead of literally typing "Gilgit"
# — completely normal phrasing — silently repriced the transfer from its
# real PKR 18,000 sourced fare down to the PKR 6,000 flat in-city rate,
# because agent_tools._add_transfer_fare's fare lookup only ever scans the
# pickup/dropoff TEXT for known city names, and that text never happened to
# contain "Gilgit". confirmation_booking_payloads now guarantees the known
# hub name is present in transfer_pickup_location before it ever reaches
# that lookup.

def test_a_pickup_address_that_never_names_the_hub_still_prices_the_real_route():
    options, picks, plan = _pick_through("Hunza", "flight", vehicle_index=2)   # Gilgit -> Hunza, SUV sourced at 18,000
    assert plan is not None and plan.transfer is not None
    assert plan.transfer["vehicle"] == "SUV"
    assert plan.transfer["fare_pkr"] == 18000

    payloads = ts.confirmation_booking_payloads(
        plan, options, picks, pickup_location="near point to hunza")
    transport = payloads[0]
    assert transport["transfer_pickup_location"] == "near point to hunza (Gilgit)"

    # The actual money check: agent_tools._add_transfer_fare (the real
    # downstream fare lookup) must now resolve the SAME sourced fare, not
    # the flat rate.
    from agents.agent_tools import _add_transfer_fare
    verified = dict(transport)
    verified["total_price_pkr"] = 100000   # any positive base; fare is additive
    priced = _add_transfer_fare(verified)
    assert priced["transfer_pkr"] == 18000


def test_a_pickup_address_that_already_names_the_hub_is_left_alone():
    options, picks, plan = _pick_through("Hunza", "flight")
    assert plan is not None
    payloads = ts.confirmation_booking_payloads(
        plan, options, picks, pickup_location="Gilgit International Airport")
    transport = payloads[0]
    # Already names the hub -- no redundant "(Gilgit)" suffix appended.
    assert transport["transfer_pickup_location"] == "Gilgit International Airport"
