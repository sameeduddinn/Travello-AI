"""
The interactive Trip Planner: the traveller chooses every component.

What this replaces: the planner used to compose Budget/Standard/Premium tiers
itself, which meant it picked their flight, their hotel and their vehicle in
order to have a package to show. Worse, "Flight 2, Hotel 1, SUV" was read by
_selected_index as a single number and silently booked package 2 — a trip
nobody chose.

Now every category is resolved independently from the rendered option block,
and anything ambiguous or out of range asks instead of guessing. Composition,
totals, package_id, the single payment and the one consolidated email all stay
on the existing deterministic path — this file covers the selection layer and
its hand-off to that path.
"""
import json

import pytest

from agents import trip_selection as ts

# ── Fixtures: realistic search payloads ──────────────────────────────────────

FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 4,
    "flights": [
        {"flight_number": "PA900", "airline": "Airblue", "from": "Karachi", "to": "Gilgit",
         "depart": "2026-08-14 07:00", "arrive": "09:05", "cabin": "BUSINESS",
         "total_price_pkr": 113640},
        {"flight_number": "ER628", "airline": "AirSial", "from": "Karachi", "to": "Gilgit",
         "depart": "2026-08-14 08:00", "arrive": "10:05", "cabin": "BUSINESS",
         "total_price_pkr": 96712},
    ],
})
HOTELS = json.dumps({
    "city": "Hunza", "nights": 11, "rooms": 1, "guests": 4,
    "hotels": [
        {"name": "Old Hunza Inn", "stars": 4.3, "price_per_night_pkr": 13900,
         "total_stay_pkr": 152900},
        {"name": "Paradise Valley Guest House", "stars": 3, "price_per_night_pkr": 26504,
         "total_stay_pkr": 291544},
    ],
})
TRAINS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "trains": [
        {"train_name": "Green Line", "train_number": "5-Up", "from": "Karachi",
         "to": "Rawalpindi", "depart": "2026-08-14 07:00", "arrive": "2026-08-15 05:00",
         "classes": [
             {"class": "AC Business", "total_price_pkr": 24000},
             {"class": "Economy", "total_price_pkr": 9000},
         ]},
    ],
})
HUNZA_HOTELS_2PAX = json.dumps({
    "city": "Hunza", "nights": 4, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Old Hunza Inn", "stars": 4, "price_per_night_pkr": 13900,
                "total_stay_pkr": 55600}],
})
SKARDU_FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 2,
    "flights": [{"flight_number": "PK451", "airline": "PIA", "from": "Islamabad",
                 "to": "Skardu", "depart": "2026-08-14 06:00", "arrive": "07:15",
                 "cabin": "ECONOMY", "total_price_pkr": 42000}],
})
SKARDU_HOTELS = json.dumps({
    "city": "Skardu", "nights": 3, "rooms": 1, "guests": 2,
    "hotels": [{"name": "Shangrila Resort", "stars": 4, "price_per_night_pkr": 15000,
                "total_stay_pkr": 45000}],
})


def _options(flights=FLIGHTS, hotels=HOTELS, destination="Hunza", pax=0):
    kind = "search_trains" if flights is TRAINS else "search_flights"
    return ts.build_options(
        [(kind, flights), ("search_hotels", hotels)], destination, passengers=pax)


def _round_trip(options):
    """Render, then read back — the path a real turn actually takes."""
    return ts.parse_options(ts.render_options(options))


# ── 1-3. Selecting each component ────────────────────────────────────────────

def test_a_flight_is_selected_by_number():
    assert ts.parse_picks("Flight 2", _round_trip(_options())).picks == {"transport": 2}


def test_a_hotel_is_selected_by_number():
    assert ts.parse_picks("Hotel 1", _round_trip(_options())).picks == {"hotel": 1}


def test_a_transfer_is_selected_by_number():
    assert ts.parse_picks("Transfer 1", _round_trip(_options())).picks == {"transfer": 1}


def test_a_transfer_is_selected_by_vehicle_name():
    """"SUV" names a vehicle, not a position — it resolves against what's offered."""
    assert ts.parse_picks("SUV", _round_trip(_options())).picks == {"transfer": 1}


# ── 4, 12, 13. Combined selections ───────────────────────────────────────────

@pytest.mark.parametrize("message,expected", [
    ("Flight 2, Hotel 1, SUV", {"transport": 2, "hotel": 1, "transfer": 1}),
    ("Flight 2, Hotel 1, Transfer 1", {"transport": 2, "hotel": 1, "transfer": 1}),
    ("Flight 2 and Hotel 1", {"transport": 2, "hotel": 1}),
    ("I'll take option 2 for the flight, hotel 1 and SUV",
     {"transport": 2, "hotel": 1, "transfer": 1}),
])
def test_combined_selections_resolve_every_component(message, expected):
    assert ts.parse_picks(message, _round_trip(_options())).picks == expected


def test_the_first_number_is_never_read_as_a_package_choice():
    """
    The verified bug this closes: "Flight 2, Hotel 1, SUV" hit _selected_index,
    which returns only the FIRST number, and silently booked package 2 — a
    different flight AND a different hotel than the traveller asked for.
    """
    picks = ts.parse_picks("Flight 2, Hotel 1, SUV", _round_trip(_options())).picks
    assert picks["transport"] == 2 and picks["hotel"] == 1
    assert len(picks) == 3


# ── 5. Train + hotel + transfer ──────────────────────────────────────────────

def test_each_train_fare_class_is_its_own_selectable_option():
    """
    Collapsing a train to its cheapest class chose the class for the traveller.
    AC Business and Economy are different products at different prices.
    """
    options = _options(TRAINS, HUNZA_HOTELS_2PAX)
    classes = [r["travel_class"] for r in options["transport"]]
    assert "AC Business" in classes and "Economy" in classes


def test_a_train_class_selection_survives_the_render_round_trip():
    options = _round_trip(_options(TRAINS, HUNZA_HOTELS_2PAX))
    picks = ts.merge_picks(options, "Train 1, Hotel 1, Transfer 1", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan and plan.transport_kind == "train"
    assert options["transport"][0]["travel_class"] in ("AC Business", "Economy")


# ── 6-7. Northern hubs ───────────────────────────────────────────────────────

def test_a_hunza_flight_transfers_from_gilgit():
    transfers = ts.transfer_options("Hunza", 4, "flight")
    assert transfers and all(t["hub"] == "Gilgit" for t in transfers)


def test_a_hunza_train_transfers_from_rawalpindi_not_gilgit():
    """
    Gilgit has an airport but NO railway station. A train traveller told to
    meet their driver at Gilgit is being sent to a platform that doesn't exist.
    """
    transfers = ts.transfer_options("Hunza", 2, "train")
    assert transfers
    assert all(t["hub"] == "Rawalpindi" for t in transfers)
    assert not any(t["hub"] == "Gilgit" for t in transfers)


def test_the_rawalpindi_hunza_leg_is_not_priced_as_the_gilgit_hop():
    by_flight = {t["vehicle"]: t["fare_pkr"] for t in ts.transfer_options("Hunza", 2, "flight")}
    by_train = {t["vehicle"]: t["fare_pkr"] for t in ts.transfer_options("Hunza", 2, "train")}
    assert by_train["Sedan"] > by_flight["Sedan"] * 3


@pytest.mark.parametrize("destination,mode,hub", [
    ("Naran", "flight", "Islamabad"),
    ("Naran", "train", "Rawalpindi"),
    ("Swat", "flight", "Islamabad"),
    ("Swat", "train", "Rawalpindi"),
])
def test_each_destination_uses_the_hub_for_the_mode_actually_travelled(destination, mode, hub):
    transfers = ts.transfer_options(destination, 2, mode)
    assert transfers and all(t["hub"] == hub for t in transfers)


# ── 8. Skardu needs no transfer ──────────────────────────────────────────────

def test_skardu_has_no_transfer_because_it_has_its_own_airport():
    assert ts.transfer_options("Skardu", 2, "flight") == []


def test_a_skardu_trip_is_complete_with_only_transport_and_hotel():
    options = _round_trip(_options(SKARDU_FLIGHTS, SKARDU_HOTELS, destination="Skardu"))
    picks = ts.merge_picks(options, "Flight 1, Hotel 1", {}).picks
    assert ts.complete(options, picks)
    plan = ts.build_plan(options, picks)
    assert plan and plan.transfer is None
    assert plan.total_pkr == 42000 + 45000


# ── 9-11, 14. Invalid and ambiguous selections ───────────────────────────────

def test_an_out_of_range_flight_number_asks_instead_of_guessing():
    result = ts.parse_picks("Flight 9", _round_trip(_options()))
    assert not result.picks and result.problems


def test_an_out_of_range_hotel_number_asks_instead_of_guessing():
    result = ts.parse_picks("Hotel 7", _round_trip(_options()))
    assert not result.picks and result.problems


def test_a_vehicle_that_cannot_carry_the_party_is_refused_not_substituted():
    result = ts.parse_picks("Sedan", _round_trip(_options()))
    assert not result.picks
    assert "Sedan" in result.problems[0] and "SUV" in result.problems[0]


def test_a_bare_number_with_several_categories_open_asks_which():
    result = ts.parse_picks("2", _round_trip(_options()))
    assert not result.picks
    assert result.problems and "not sure which" in result.problems[0].lower()


def test_a_bare_number_is_accepted_once_only_one_category_is_left():
    options = _round_trip(_options())
    prior = {"transport": 2, "hotel": 1}
    assert ts.parse_picks("1", options, prior).picks == {"transfer": 1}


def test_a_clarification_names_what_is_still_needed():
    options = _round_trip(_options())
    text = ts.clarification(["Hotel 7 isn't on the list."], options, {"transport": 1})
    assert "Hotel 7" in text and "hotel" in text.lower()


# ── 15-16. Changing a selection ──────────────────────────────────────────────

def test_a_traveller_can_change_their_flight_after_seeing_the_options():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 1", {"transport": 2, "hotel": 1}).picks
    assert picks == {"transport": 1, "hotel": 1}


def test_a_traveller_can_change_their_hotel_after_seeing_the_options():
    options = _round_trip(_options())
    result = ts.merge_picks(options, "Hotel 2", {"transport": 2, "hotel": 1, "transfer": 1})
    assert result.picks["hotel"] == 2
    assert result.picks_changed is True


def test_a_confirmation_is_not_mistaken_for_a_re_selection():
    options = _round_trip(_options())
    result = ts.merge_picks(options, "yes", {"transport": 2, "hotel": 1, "transfer": 1})
    assert result.picks_changed is False
    assert ts.is_confirmation("yes")


# ── 17-18. Budget ────────────────────────────────────────────────────────────

def _plan_text(budget):
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 1, Hotel 2, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    return plan, ts.render_plan(plan, options, picks, "Hunza", budget_pkr=budget)


def test_a_selection_over_budget_is_reported_never_silently_swapped():
    plan, text = _plan_text(300000)
    assert plan is not None
    assert plan.total_pkr > 300000
    assert "Over budget by" in text
    assert "Nothing has been changed for you" in text


def test_a_selection_within_budget_shows_what_is_left():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Hunza", budget_pkr=300000)
    assert "Remaining: PKR" in text
    assert "Over budget" not in text


def test_the_total_is_the_sum_of_the_selected_components_only():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    assert plan.total_pkr == 96712 + 152900 + 18000


# ── 23. Vehicle capacity ─────────────────────────────────────────────────────

@pytest.mark.parametrize("pax,expected", [
    (1, ["Sedan", "SUV"]),
    (3, ["Sedan", "SUV"]),
    (4, ["SUV"]),
    (5, ["SUV"]),
    (7, ["Van"]),
])
def test_only_vehicles_the_party_fits_in_are_offered(pax, expected):
    assert ts.vehicles_for(pax) == expected


def test_a_single_valid_vehicle_is_explained_rather_than_padded():
    text = ts.render_options(_options(pax=4))
    assert "only vehicle that seats 4" in text


# ── Rendering and reading back ───────────────────────────────────────────────

def test_options_are_numbered_so_the_offer_tracker_recognises_them():
    """The pick pipeline keys off digit-prefixed rows with prices."""
    from agents.prompt_builder import _looks_like_offer_list

    assert _looks_like_offer_list(ts.render_options(_options()))


def test_every_rendered_component_survives_being_read_back():
    options = _options()
    back = _round_trip(options)
    assert len(back["transport"]) == len(options["transport"])
    assert len(back["hotels"]) == len(options["hotels"])
    assert len(back["transfers"]) == len(options["transfers"])
    assert back["transport"][1]["flight_number"] == "ER628"
    assert back["transport"][1]["price_pkr"] == 96712
    assert back["hotels"][0]["name"] == "Old Hunza Inn"
    assert back["transfers"][0]["vehicle"] == "SUV"


def test_the_selection_state_rides_on_the_rendered_block():
    """A pick has to survive to the next turn without the model remembering it."""
    options = _options()
    text = ts.render_options({**options, "picks": {"transport": 2, "hotel": 1}})
    assert ts.find_picks([{"role": "assistant", "content": text}]) == {
        "transport": 2, "hotel": 1}


def test_the_plan_also_carries_the_selection_forward():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    text = ts.render_plan(plan, options, picks, "Hunza")
    assert ts.find_picks([{"role": "assistant", "content": text}]) == picks
    assert ts.plan_was_shown([{"role": "assistant", "content": text}])


# ── Hand-off to the existing package/payment path ────────────────────────────

def test_the_booking_brief_names_the_exact_chosen_components():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    brief = ts.booking_instruction(plan, options, picks)
    assert "ER628" in brief                      # their flight, not the other one
    assert "Old Hunza Inn" in brief              # their hotel
    assert 'transfer_vehicle_type="SUV"' in brief
    assert 'transfer_dropoff_location="Hunza"' in brief
    assert "PA900" not in brief


def test_the_booking_brief_forbids_substitution_and_re_pricing():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    brief = ts.booking_instruction(plan, options, picks)
    assert "do not re-price" in brief.lower()
    assert "do not substitute" in brief.lower()
    assert "SAME reply" in brief                 # one checkout, one payment


def test_the_brief_keeps_the_car_inside_the_package():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    brief = ts.booking_instruction(plan, options, picks)
    assert "Do NOT use book_car" in brief


def test_a_cabin_class_the_traveller_chose_reaches_the_booking_brief():
    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    brief = ts.booking_instruction(plan, options, picks)
    assert "BUSINESS" in brief


# ── confirmation_booking_payloads: the deterministic booking-confirmation ────
# path (see master_agent._complete_trip_planner_confirmation)

def test_confirmation_payloads_carry_the_traveller_chosen_flight_and_hotel():
    options = _options()  # fresh, NOT round-tripped -- depart keeps its full date
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    transport, hotel = ts.confirmation_booking_payloads(
        plan, options, picks, pickup_location="123 Airport Road Gilgit")

    assert transport["booking_type"] == "flight"
    assert transport["flight_number"] == "ER628"          # Flight 2, not PA900
    assert transport["origin"] == "Karachi"
    assert transport["destination"] == "Gilgit"
    assert transport["travel_date"] == "2026-08-14"
    assert transport["cabin_class"] == "BUSINESS"
    assert transport["adults"] == 4
    assert transport["total_price_pkr"] == plan.transport_pkr
    assert transport["transfer_vehicle_type"] == "SUV"
    assert transport["transfer_pickup_location"] == "123 Airport Road Gilgit"
    assert transport["transfer_dropoff_location"] == "Hunza"

    assert hotel["booking_type"] == "hotel"
    assert hotel["hotel_name"] == "Old Hunza Inn"
    assert hotel["destination"] == "Hunza"
    assert hotel["check_in"] == "2026-08-14"
    assert hotel["guests"] == 4
    assert hotel["total_price_pkr"] == plan.hotel_pkr


def test_confirmation_payloads_omit_transfer_fields_without_a_pickup_location():
    options = _options()
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None
    transport, _hotel = ts.confirmation_booking_payloads(plan, options, picks)

    assert "transfer_vehicle_type" not in transport
    assert "transfer_pickup_location" not in transport
    assert "transfer_dropoff_location" not in transport


def test_confirmation_payloads_fall_back_to_the_given_date_after_a_render_round_trip():
    """
    parse_options() (the text-reconstruction fallback path -- see
    find_options) never recovers a full date: render_options only ever shows
    the TIME ("07:00 -> 08:38"), so depart on a round-tripped row is time-only.
    fallback_date covers exactly this gap; reprice_booking's own
    flight-number match is what keeps a wrong guess from ever mattering.
    """
    options = _round_trip(_options())
    assert options["transport"][1]["depart"] == "08:00"     # time only, confirmed
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    plan = ts.build_plan(options, picks)
    assert plan is not None

    transport, hotel = ts.confirmation_booking_payloads(
        plan, options, picks, fallback_date="2026-08-14")
    assert transport["travel_date"] == "2026-08-14"
    assert hotel["check_in"] == "2026-08-14"

    # No fallback given -- stays blank, so the existing date gate rejects it
    # exactly as it would for any other incomplete payload (never a guess).
    transport_no_fb, _ = ts.confirmation_booking_payloads(plan, options, picks)
    assert transport_no_fb["travel_date"] == ""


# ── merge_fresh_search: a partial refinement can't silently go stale ────────
#
# Real on-device bug: "I want business class flights" re-searches transport
# only. build_options() on THAT turn's gathered data alone sees no hotel
# results and returns {} -- so the deterministic renderer used to bow out,
# the model wrote its own (accurate) prose from the fresh search, and the
# SAVED state kept the old economy flight. A later "Flight 1, Hotel 3,
# Transfer 2" then silently resolved against the STALE economy fare while
# the traveller had just been shown business-class prices.

BUSINESS_FLIGHTS = json.dumps({
    "search_date": "2026-08-14", "passengers": 4,
    "flights": [
        {"flight_number": "PK107", "airline": "PIA", "from": "Karachi", "to": "Gilgit",
         "depart": "2026-08-14 07:00", "arrive": "08:11", "cabin": "BUSINESS",
         "total_price_pkr": 67118},
    ],
})


def test_merge_fresh_search_replaces_the_stale_category_with_the_new_one():
    economy = ts.build_options(
        [("search_flights", json.dumps({
            "search_date": "2026-08-14", "passengers": 2,
            "flights": [{"flight_number": "PK107", "airline": "PIA", "from": "Karachi",
                         "to": "Gilgit", "depart": "2026-08-14 07:00", "arrive": "08:11",
                         "cabin": "ECONOMY", "total_price_pkr": 22066}],
        })), ("search_hotels", HUNZA_HOTELS_2PAX)],
        "Hunza", passengers=2, preferred_mode="flight")
    assert economy["transport"][0]["cabin"] == "ECONOMY"

    # This turn only re-searched flights -- build_options() alone can't see
    # a full block (no hotels this turn), which is exactly the gap this
    # closes.
    only_flights_gathered = [("search_flights", BUSINESS_FLIGHTS)]
    assert ts.build_options(only_flights_gathered, "Hunza") == {}

    merged = ts.merge_fresh_search(economy, only_flights_gathered, passengers=2)
    assert merged
    assert merged["transport"][0]["cabin"] == "BUSINESS"
    assert merged["transport"][0]["flight_number"] == "PK107"
    assert merged["transport"][0]["price_pkr"] == 67118
    # The untouched category carries over from the EXISTING options, unchanged.
    assert merged["hotels"] == economy["hotels"]
    assert merged["destination"] == "Hunza"
    # A refreshed category renumbers -- any earlier pick can't be trusted.
    assert merged["picks"] == {}


def test_merge_fresh_search_is_a_noop_without_an_active_block_or_fresh_data():
    assert ts.merge_fresh_search({}, [("search_flights", BUSINESS_FLIGHTS)]) == {}
    existing = _options()
    assert ts.merge_fresh_search(existing, []) == {}
    assert ts.merge_fresh_search(existing, [("get_weather", "{}")]) == {}


def test_looks_like_a_bare_number_recognises_only_lone_digits():
    assert ts.looks_like_a_bare_number("2")
    assert ts.looks_like_a_bare_number("Option 2")
    assert ts.looks_like_a_bare_number("#2")
    assert not ts.looks_like_a_bare_number("123 Street North Karachi")
    assert not ts.looks_like_a_bare_number("Islamabad Airport")
    assert not ts.looks_like_a_bare_number("")


def test_clean_pickup_reply_strips_only_the_echoed_question_frame():
    """A real answer that echoes "pickup address is..." back naturally must
    not be mistaken for agent_tools._TRANSFER_PLACEHOLDER_RE's actual
    target (a MODEL parroting the field name with nothing filled in)."""
    assert ts.clean_pickup_reply("Pickup address is Gilgit Baltistan airport") == \
        "Gilgit Baltistan airport"
    assert ts.clean_pickup_reply("The pickup address is 123 Main Street") == "123 Main Street"
    assert ts.clean_pickup_reply("pickup location: 123 Main Street") == "123 Main Street"
    assert ts.clean_pickup_reply("my pickup address is Gate 2, Gilgit Airport") == \
        "Gate 2, Gilgit Airport"
    # A plain answer with no echoed frame is untouched.
    assert ts.clean_pickup_reply("123 Street North Karachi") == "123 Street North Karachi"
    assert ts.clean_pickup_reply("Islamabad Airport") == "Islamabad Airport"


# ── Non-planner traffic is untouched ─────────────────────────────────────────

def test_a_non_northern_destination_produces_no_option_block():
    assert _options(destination="Lahore") == {}


def test_options_need_both_transport_and_a_hotel():
    assert ts.build_options([("search_flights", FLIGHTS)], "Hunza") == {}
    assert ts.build_options([("search_hotels", HOTELS)], "Hunza") == {}


def test_ordinary_text_is_not_mistaken_for_an_option_block():
    assert ts.parse_options("Here are your flights:\n1. PK304 — PKR 20,000") == {}
    assert ts.find_options([{"role": "assistant", "content": "sure, when would you like to go?"}]) == {}


@pytest.mark.parametrize("message", ["thanks", "what's the weather in Hunza?", ""])
def test_a_message_that_picks_nothing_changes_nothing(message):
    result = ts.parse_picks(message, _round_trip(_options()))
    assert not result.picks and not result.problems


# ── 19-20. Hotel star preference actually filters ────────────────────────────
#
# The prompt collected "4-star" and search_hotels had no way to use it, so a
# 3-star was shown as though it satisfied the request. min_stars filters the
# WHOLE result set before it's trimmed to the top few — filtering after would
# report "no 4-star hotels" whenever they sat outside the first six.

class _Hotel:
    def __init__(self, name, star_rating):
        self.name, self.star_rating = name, star_rating


def test_a_star_preference_keeps_only_hotels_at_or_above_it():
    from agents.agent_tools import _stars_filter

    hotels = [_Hotel("Three", 3), _Hotel("Four", 4), _Hotel("Five", 5)]
    kept, honoured = _stars_filter(hotels, 4)
    assert honoured is True
    assert [h.name for h in kept] == ["Four", "Five"]


def test_no_star_preference_leaves_every_hotel_in_place():
    from agents.agent_tools import _stars_filter

    hotels = [_Hotel("Three", 3), _Hotel("Four", 4)]
    for absent in (None, 0, ""):
        kept, honoured = _stars_filter(hotels, absent)
        assert honoured is True and len(kept) == 2


def test_an_unmet_star_preference_is_reported_not_silently_downgraded():
    """A 3-star shown as if it were the 4-star they asked for is a substitution."""
    from agents.agent_tools import _stars_filter

    hotels = [_Hotel("Three", 3), _Hotel("Two", 2)]
    kept, honoured = _stars_filter(hotels, 4)
    assert honoured is False
    assert len(kept) == 2          # alternatives still shown, just not as 4-star


def test_the_star_filter_runs_before_the_top_six_trim():
    from agents.agent_tools import _stars_filter

    hotels = [_Hotel(f"Three{i}", 3) for i in range(6)] + [_Hotel("Four", 4)]
    kept, honoured = _stars_filter(hotels, 4)
    assert honoured is True and [h.name for h in kept] == ["Four"]


def test_search_hotels_accepts_a_star_preference():
    from agents.agent_tools import TOOL_SCHEMAS

    schema = next(t["function"] for t in TOOL_SCHEMAS if t["function"]["name"] == "search_hotels")
    assert "min_stars" in schema["parameters"]["properties"]
    assert "min_stars" not in schema["parameters"]["required"]


# ── 24-30. The existing package/payment path is reused, not replaced ─────────

def test_the_plan_reuses_TripPackage_rather_than_a_second_total():
    """One composition/total implementation, shared with the package flow."""
    from agents.trip_package import TripPackage

    options = _round_trip(_options())
    picks = ts.merge_picks(options, "Flight 2, Hotel 1, SUV", {}).picks
    assert isinstance(ts.build_plan(options, picks), TripPackage)


def test_no_second_payment_or_package_architecture_was_introduced():
    """
    The selection layer composes and hands off; it must not grow its own
    booking, payment, email or persistence path alongside the existing one.
    Checked by IMPORTS rather than by text, so the module's own prose about
    reusing package_id doesn't read as a violation of it.
    """
    import ast
    import inspect

    tree = ast.parse(inspect.getsource(ts))
    imported = {
        (node.module or "")
        for node in ast.walk(tree)
        if isinstance(node, (ast.Import, ast.ImportFrom))
        for _ in [0]
        if isinstance(node, ast.ImportFrom)
    }
    for module in imported:
        assert not module.startswith("services.payment"), module
        assert not module.startswith("services.booking"), module
        assert "email" not in module, module
        assert "supabase" not in module, module
    # What it DOES reuse: the existing composition and the route data.
    assert "agents.trip_package" in imported
    assert "services.northern_routes" in imported


def test_standalone_car_booking_is_untouched_by_the_planner():
    from agents.prompt_builder import select_tool_names

    assert select_tool_names("book me a sedan from DHA phase 5 to the airport tomorrow 9am") == [
        "book_car"]


def test_standalone_flight_search_is_untouched_by_the_planner():
    from agents.prompt_builder import select_tool_names

    assert select_tool_names("I want to fly Lahore to Karachi on 20 August for 2") == [
        "search_flights"]


def test_standalone_hotel_search_is_untouched_by_the_planner():
    from agents.prompt_builder import select_tool_names

    assert select_tool_names("find me a hotel in Islamabad for 3 nights") == ["search_hotels"]


def test_a_plain_hotel_search_produces_no_option_block():
    """The interactive layer must only wake up for a northern trip plan."""
    assert ts.build_options([("search_hotels", HOTELS)], "Lahore") == {}


# ── The whole conversation, through the REAL loop ────────────────────────────
#
# Same harness as test_northern_trip_planning.py. Everything here is what
# process_message_agentic actually produced, not a hand-written expectation.
import asyncio

from agents import master_agent as ma


class _Fn:
    def __init__(self, name, arguments):
        self.name, self.arguments = name, arguments


class _Call:
    def __init__(self, cid, name, args):
        self.id, self.type = cid, "function"
        self.function = _Fn(name, json.dumps(args))


class _Msg:
    def __init__(self, content=None, tool_calls=None):
        self.content, self.tool_calls = content, tool_calls or []


OPENING = (
    "I want to travel from Karachi to Hunza from 14 August 2026 to 25 August 2026 "
    "for 2 adults and 2 children. My budget is 300,000. Business class flight."
)


@pytest.fixture
def planner(monkeypatch):
    history: list[dict] = []
    calls = {"model": 0}

    async def _model(messages, tools=None, **kw):
        calls["model"] += 1
        if calls["model"] == 1:
            return _Msg(tool_calls=[
                _Call("c1", "search_flights", {
                    "origin_city": "Karachi", "destination_city": "Gilgit",
                    "travel_date": "2026-08-14", "passengers": 4, "cabin_class": "BUSINESS"}),
                _Call("c2", "search_hotels", {
                    "city": "Hunza", "check_in": "2026-08-14",
                    "check_out": "2026-08-25", "guests": 4}),
            ])
        return _Msg(tool_calls=[
            _Call("b1", "prepare_booking", {
                "booking_type": "flight", "origin": "Karachi", "destination": "Gilgit",
                "travel_date": "2026-08-14", "flight_number": "ER628", "adults": 4,
                "cabin_class": "BUSINESS", "total_price_pkr": 96712,
                "transfer_vehicle_type": "SUV",
                "transfer_pickup_location": "Gilgit Airport",
                "transfer_dropoff_location": "Hunza"}),
            _Call("b2", "prepare_booking", {
                "booking_type": "hotel", "hotel_name": "Old Hunza Inn",
                "destination": "Hunza", "check_in": "2026-08-14",
                "check_out": "2026-08-25", "rooms": 1, "guests": 4,
                "total_price_pkr": 152900}),
        ])

    async def _dispatch(*, name, args, **kw):
        return {"search_flights": FLIGHTS, "search_hotels": HOTELS}.get(name, json.dumps({}))

    async def _reprice(bd):
        out = dict(bd)
        out["total_price_pkr"] = bd.get("total_price_pkr") or 1000
        return out

    async def _history(_c, limit=20):
        return list(history)

    async def _no_planner_state(_cid):
        return None

    async def _noop_save_planner_state(*a, **k):
        pass

    async def _save(cid, uid, msg, reply, **kw):
        history.append({"role": "user", "content": msg})
        history.append({"role": "assistant", "content": reply})

    async def _noop(*a, **k):
        return None

    async def _memory(_u):
        return {}

    async def _profile(_u):
        return {"display_name": "Sameed"}

    monkeypatch.setattr(ma, "get_user_memory", _memory)
    monkeypatch.setattr(ma, "get_user_profile", _profile)
    monkeypatch.setattr(ma, "get_conversation_history", _history)
    monkeypatch.setattr(ma, "save_turn", _save)
    monkeypatch.setattr(ma, "get_active_planner_state", _no_planner_state)
    monkeypatch.setattr(ma, "save_planner_state", _noop_save_planner_state)
    monkeypatch.setattr(ma, "_log_task", _noop)
    monkeypatch.setattr(ma, "generate_with_tools", _model)
    monkeypatch.setattr(ma, "reprice_booking", _reprice)
    monkeypatch.setattr(ma, "all_providers_exhausted", lambda: False)
    monkeypatch.setattr(ma.self_improvement, "detect_user_correction", lambda _m: False)
    monkeypatch.setattr(ma.self_improvement, "log_agent_failure", _noop)
    monkeypatch.setattr(ma.self_improvement, "dispatch_tool_with_retry", _dispatch)

    class _Planner:
        model_calls = calls

        def say(self, message):
            return asyncio.run(ma.process_message_agentic("u1", "c1", message))

    return _Planner()


def test_the_search_turn_offers_components_not_ready_made_packages(planner):
    reply = planner.say(OPENING)["response"]
    assert "AVAILABLE FLIGHTS" in reply and "AVAILABLE HOTELS" in reply
    assert "AVAILABLE TRANSFERS" in reply
    assert "Budget —" not in reply and "Premium —" not in reply


def test_each_selection_is_answered_without_calling_the_model(planner):
    planner.say(OPENING)
    before = planner.model_calls["model"]
    planner.say("Flight 2.")
    planner.say("Hotel 1.")
    assert planner.model_calls["model"] == before      # pure deterministic turns


def test_the_final_selection_produces_the_trip_plan(planner):
    planner.say(OPENING)
    planner.say("Flight 2.")
    planner.say("Hotel 1.")
    reply = planner.say("SUV.")["response"]
    assert "YOUR TRIP PLAN" in reply
    assert "ER628" in reply and "Old Hunza Inn" in reply and "SUV" in reply
    assert "Would you like to proceed" in reply


def test_the_plan_totals_only_the_chosen_components(planner):
    planner.say(OPENING)
    reply = planner.say("Flight 2, Hotel 1, SUV")["response"]
    assert f"{96712 + 152900 + 18000:,}" in reply


def test_the_plan_compares_against_the_stated_budget(planner):
    planner.say(OPENING)
    reply = planner.say("Flight 2, Hotel 1, SUV")["response"]
    assert "Budget: PKR 300,000" in reply
    assert "Remaining: PKR" in reply


def test_confirming_the_plan_creates_one_package_not_separate_bookings(planner):
    """
    "yes" completes transport+hotel deterministically, in code — see
    _complete_trip_planner_confirmation. Since this plan also has a car
    transfer, "yes" first asks for the pickup address (a genuinely unknown
    field can't be filled deterministically) rather than have the model
    unreliably juggle "ask for it" and "book everything together" in the
    same reply, which is the bug this closes. The traveller's next reply
    supplies it and completes the SAME checkout.
    """
    planner.say(OPENING)
    planner.say("Flight 2, Hotel 1, SUV")
    ask = planner.say("yes")
    assert "action" not in ask
    assert "pickup address" in ask["response"].lower()
    out = planner.say("123 Street North Gilgit")
    assert out["action"] == "package_choice"
    components = out["booking_data"]["components"]
    assert len(components) == 2                        # flight (+transfer) + hotel
    assert {c["booking_type"] for c in components} == {"flight", "hotel"}


def test_the_booked_components_are_the_ones_the_traveller_chose(planner):
    planner.say(OPENING)
    planner.say("Flight 2, Hotel 1, SUV")
    planner.say("yes")
    components = planner.say("123 Street North Gilgit")["booking_data"]["components"]
    flight = next(c for c in components if c["booking_type"] == "flight")
    hotel = next(c for c in components if c["booking_type"] == "hotel")
    assert flight["flight_number"] == "ER628"          # not PA900
    assert hotel["hotel_name"] == "Old Hunza Inn"
    assert flight["transfer_vehicle_type"] == "SUV"


def test_the_car_rides_inside_the_package_with_no_separate_booking(planner):
    planner.say(OPENING)
    planner.say("Flight 2, Hotel 1, SUV")
    planner.say("yes")
    out = planner.say("123 Street North Gilgit")
    assert out["action"] != "car_booking_choice"
    flight = next(c for c in out["booking_data"]["components"]
                  if c["booking_type"] == "flight")
    assert flight["transfer_dropoff_location"] == "Hunza"


def test_an_invalid_selection_asks_rather_than_booking_something_else(planner):
    planner.say(OPENING)
    reply = planner.say("Flight 9")["response"]
    assert "isn't on the list" in reply
    assert "YOUR TRIP PLAN" not in reply


def test_an_ambiguous_bare_number_asks_which_component_it_is_for(planner):
    planner.say(OPENING)
    reply = planner.say("2")["response"]
    assert "not sure which" in reply.lower()


def test_a_changed_selection_is_re_priced_not_ignored(planner):
    planner.say(OPENING)
    planner.say("Flight 2, Hotel 1, SUV")
    reply = planner.say("Actually flight 1")["response"]
    assert "PA900" in reply
    assert f"{113640 + 152900 + 18000:,}" in reply
