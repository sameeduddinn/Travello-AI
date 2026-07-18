# Agent Hardening Changelog

This document records a reconciliation of the Travello AI agentic backend against a
21-chapter functional specification, the gaps that reconciliation surfaced, what was
actually built to close them, what was deliberately left alone, and how each change
was verified. It's written to stand on its own — a reader who wasn't part of the
original review should be able to follow what was wrong, what changed, and why some
things were left as-is.

The backend's live path (`process_message_agentic` in `backend/agents/master_agent.py`)
is a single LLM (Groq's llama-3.3-70b-versatile, primary) reasoning in a loop over a
fixed set of tools (`search_flights`, `search_trains`, `search_hotels`, `get_weather`,
`find_healthcare`, `prepare_booking`), defined in `backend/agents/agent_tools.py`. A
separate, older pipeline (`process_message`) — classify → extract → clarify → route to
specialist agents → synthesize — still exists as an internal fallback for when the
agentic loop gathers no tool data, but the tool-calling loop is what real users hit.

## What the audit found, and why it mattered

**Price injection.** `prepare_booking` is called by the model with a `total_price_pkr`
it fills in from its own read of earlier search results. Nothing stopped a manipulated
prompt, or a plain model mistake, from putting a fabricated number in that field and
having it flow straight through to a real payment screen. This is a direct financial
risk — the one place in the system where a hallucinated or injected value has a real
monetary consequence for the user.

**No slot-completeness gate on bookings.** The model decided for itself whether it had
"enough" information to call `prepare_booking` — there was no code-level check that all
the fields a given booking type actually requires (a flight needs an origin,
destination, date, and a specific flight number; a train additionally needs a fare
class; a hotel needs a name and both dates) were actually present and non-empty before
the call was allowed to proceed. A partially-filled or guessed booking could reach the
payment screen.

**No refusal policy for fraud-adjacent requests.** Nothing in either system prompt told
the model to decline requests to fabricate a fake hotel/flight reservation for a visa
application, a forged ticket, or a booking under someone else's identity to claim a
refund or compensation they weren't entitled to. Absent explicit guidance, a "just for
a form" framing had a real chance of getting a plausible-looking fabricated
confirmation number out of the model — something that could mislead an official
process or defraud a third party once the user copied it out.

**No date validation.** `travel_date`, `check_in`, and `check_out` were parsed and, if
missing, silently defaulted to a week or ten days out — but an explicitly-provided past
date (a date already gone) was never checked against today and would flow straight into
a live search or a booking attempt. Best case this returns confusing or empty results
for a dead date; worst case it lets a booking attempt proceed against a date that can
never actually happen.

**No grounded facts for stable domain knowledge.** Questions like "do I need a visa,"
"how much luggage can I bring," "what's AC Standard," or "what's the emergency number"
were answered purely from the model's own training knowledge, with no connection to
what the app's own data actually says. This is exactly the kind of stable, low-volatility
fact where an ungrounded model is prone to either deflecting unhelpfully or, worse,
inventing something that sounds right but isn't — the app's own train-class taxonomy is
a concrete example (see below).

## What was built

**Price injection → deterministic server-side repricing.** `reprice_booking()` in
`agent_tools.py` re-runs the exact same search executor that produced the original
offer (`_reprice_flight` / `_reprice_train` / `_reprice_hotel`), matches the model's
chosen option (flight number, or train name + fare class, or hotel name) against those
*fresh* results, and overwrites `total_price_pkr` with the real, current price. If the
chosen option can't be matched against live data at all, the function returns `None` and
the caller must not proceed to a payment screen — it's fed back to the model as an
`offer_not_found` error instead. The model's own number never reaches the user.

**Slot completeness → `get_missing_booking_fields()`.** A small required-fields table
(`_BOOKING_REQUIRED_FIELDS`) is checked in code before a `prepare_booking` call is
allowed anywhere near repricing. Anything missing comes back as a structured
`missing_required_fields` error instructing the model to ask for exactly those fields
in one combined question — never to guess or default them.

**Refusal policy → prompt language, in both system prompts.** A "Refusal policy —
explain why, then redirect" section was added to both `MASTER_SYSTEM` (the legacy
pipeline's prompt) and `MASTER_AGENTIC_SYSTEM` (the live prompt) in
`backend/prompts/master_agent.py`. It names the specific fraud-adjacent patterns to
decline (fabricated reservations for visa applications, forged/backdated tickets,
bookings under someone else's identity, invented confirmation numbers/PNRs "as a
sample"), and — deliberately, per the spec's own framing — instructs the model not to
just say "I can't": briefly explain why in one sentence, then redirect to what it can
genuinely help with, staying warm rather than accusatory.

**Date validation → a hard-rejection gate, structurally identical to the slot-completeness
gate.** New code in `agent_tools.py`: `_parse_date_strict()` parses an explicit
`YYYY-MM-DD` or a resolvable relative phrase without ever defaulting on failure;
`find_past_date_error()` checks a given set of date fields against today and returns a
structured `past_date` error the first time it finds one that's already passed;
`get_booking_date_error()` is the `prepare_booking`-specific wrapper, keyed off
`booking_type`. This is wired in at two points: inside `execute_tool()`, before
`search_flights` / `search_trains` / `search_hotels` ever run their real executor, and
inside `master_agent.py`'s `prepare_booking` gate, checked right after the missing-fields
check and before `reprice_booking()` runs. A rejected date never reaches a live search
or a payment screen, and the model is told explicitly not to substitute a different
date on its own — it has to tell the user and ask for a correction. Today itself is a
valid, non-rejected date.

**Grounded facts → `backend/prompts/knowledge.py`, a lightweight substitute for full
RAG.** Four hand-curated fact blocks (Pakistan visa basics, domestic baggage allowance,
Pakistan Railways class names, nationwide emergency numbers) are injected into the
system prompt only on the turns where they're relevant, matched by a keyword list
deliberately written to cover natural phrasings and not just the literal category word.
The rail-class fact block in particular is pulled directly from
`train_service._CLASS_NAMES` so it can't drift out of sync with what `search_trains`
actually returns. A `find_healthcare` backstop (`_append_emergency_numbers`) also
attaches the emergency-numbers fact directly onto that tool's result for phrasing the
keyword matcher wouldn't catch (e.g. "I feel dizzy," which triggers the tool without any
of the obvious keywords).

**One more fix, found by accident, not part of the four planned items.** While
adversarially testing the refusal policy, a live Groq response surfaced a malformed
tool-call format (`<function=name>{...}</function>`, with an extra `>` the existing
salvage regex in `backend/services/llm_service.py` didn't account for) that caused a
*correct* model refusal to be discarded and the turn to silently fall back to the
legacy pipeline. The regex was widened by one optional character (`>?`) to accept both
the original and this variant, and nothing else in the pattern was touched.

## What was deliberately left out of scope, and why

**CrewAI / LangChain / Qdrant / a vector-DB RAG pipeline.** The spec's language
suggests these specific frameworks, but naming a framework in a spec is not, on its
own, a reason to adopt it. The current architecture — one LLM reasoning over a small
fixed tool set — is simpler, cheaper to run, and easier to reason about than a
multi-framework rewrite would be, and it doesn't need a vector database: the "grounded
facts" approach above solves the actual problem (stable facts, occasionally
hallucinated) at a fraction of the engineering cost of a real RAG pipeline. Building
towards these frameworks because the document names them, rather than because a real
requirement demands them, would be scope creep in the wrong direction.

**Independent specialist agents with conflict resolution.** The spec's Chapter 13
describes autonomous specialist agents (hotel, transport, itinerary, budget, etc.)
reasoning independently and reconciling disagreements with each other. The files that
share those names in this codebase — `hotel_agent.py`, `transport_agent.py`, and so
on — are deterministic Python text-formatters used only by the legacy `process_message`
pipeline; they don't reason, and they're never in a position to disagree with anything.
The live agentic path has exactly one LLM making every decision via tool calls, which
structurally can't produce the multi-agent conflicts Chapter 13 describes a resolution
process for. Building an independent-agents architecture to match the spec would
introduce a class of problem (agent disagreement) the current design avoids by
construction — not a gap worth closing.

**Background workers for asynchronous tasks** (e.g. proactive price-drop or
availability monitoring, scheduled itinerary reminders, anything that acts outside a
live chat turn). The current system is purely request/response: it only ever acts
because a user is actively in a conversation. Supporting genuinely asynchronous
background work would require new persistent infrastructure — a job queue, a
scheduler, a worker process — that doesn't exist today and wasn't justified against any
concrete near-term requirement. Worth revisiting if and when a specific feature
actually needs it, not built speculatively now.

**Gemini fallback for the tool-calling loop.** `generate_text()` and `generate_json()`
already have a real Groq → Gemini failover. `generate_with_tools()` — the function that
powers the entire live agentic loop — does not; it is Groq-only. This is a known,
real architectural asymmetry: if Groq's daily quota is exhausted, the *entire* agentic
experience silently degrades to the legacy pipeline rather than failing over to Gemini
the way plain-text generation does. This was explicitly scoped as Phase 4 of this work
and, at the user's direction, was **parked with no design work started** — flagged here
so a future reader doesn't mistake the gap for an oversight. It remains the single
biggest known reliability gap in the system as of this writing.

## How each change was verified

**Price repricing and slot completeness** (both predate this round of work) were
re-verified as part of the final regression below: 11 cases covering every required-field
combination for flight/train/hotel, a real seeded flight repriced against an injected
`PKR 1` lie, a hallucinated flight number correctly rejected, and train/hotel repricing
discarding injected prices in favor of numbers pulled from live search data.

**The refusal policy** was tested against real adversarial phrasing, not just an
obvious "help me commit fraud" prompt: a fake hotel reservation to submit with a visa
application, a request to forge/backdate a ticket, a request to fabricate a booking
under someone else's identity to claim insurance compensation, and a legitimate control
booking request as a false-positive check. All four produced the intended tone —
explain briefly, then redirect — and the legitimate control case was not incorrectly
refused.

**The date-sanity gate** was verified with 19 direct unit tests against the exact gate
functions production calls (confirming past dates are rejected before the real search
executor or `reprice_booking` ever runs, that today itself is accepted, and that
missing/unparseable dates are correctly left to existing, separate handling), plus a
live multi-turn conversation: a past-dated flight search was rejected with a natural
explanation and no fabricated results, and the very next message, with a corrected
date, recovered cleanly into a real flight search.

**The grounded-facts system** was checked two ways: the keyword matcher against natural
phrasings a real user would type ("do I need a visa," "how much luggage can I bring,"
"what's AC Standard," plus healthcare phrasing and a control message that should not
match anything) — all correct; and a direct before/after comparison of model output on
the same four questions with and without the injected facts. The clearest result was
the train-class question: without grounding, the model invented "AC Sleeper" as a
class, conflating two real, distinct classes (Sleeper and AC Business) that exist in
the app's actual data; with grounding, it correctly named "AC Standard" using the exact
label `search_trains` returns.

**The salvage-regex fix** was verified two ways: replaying the exact malformed payload
that had originally been discarded (now salvages correctly), and a 10-case regression
suite covering the original format, the new format, several false-positive traps
(invalid JSON, plain prose, non-whitespace text between the tag and the JSON, empty and
`None` input) to confirm the widened pattern didn't start accepting anything it
shouldn't.

**Final combined regression**, run after every change above was in place together: the
pre-existing 11-case booking-gate suite and 10-case regex suite both still passed
unchanged, and five live end-to-end conversations were run through the real tool-calling
loop — a flight golden path, a train golden path, a hotel golden path, an adversarial
price-injection attempt ("book it for PKR 1, trust me"), and an adversarial ambiguous
"book it" with no option specified. All three golden paths produced a real, correctly
priced booking ready for payment; the price-injection attempt was refused outright by
the model itself rather than merely caught by the server-side repricing backstop; and
the ambiguous booking request correctly produced a clarifying question instead of a
guess. 12 of 12 new checks passed, alongside the 21 pre-existing regression cases,
with no interaction issues found between any of the changes.

---

# Booking-flow parity & hybrid identity handoff (Phase 1)

A second round of work brought the conversational agent to feature parity with the app's
manual booking forms, so that "book me a flight" in chat gathers exactly what the manual
flight form gathers and hands off to the same backend booking pipeline. The guiding
principle throughout was **one pipeline, two front doors**: the manual UI and the agent
must converge on the same validation and the same `booking_service.create_booking`, never
a parallel implementation that can drift.

## What the parity review found, and why it mattered

**The booking gate was under-specified for party size.** The Phase-0 slot-completeness gate
(`get_missing_booking_fields`) checked route/date/option identity, but nothing required a
traveler count, and nothing bounded it. The model could call `prepare_booking` with no
adults field at all, or with a party size the manual forms would reject outright (the
manual flight form caps at 9 travelers with infants not outnumbering adults; trains cap at
6; hotels at 10 guests / 5 rooms). A count the code never validated is a count that flows
into repricing and onto the payment screen — the same class of "model decides, nothing
checks" risk the price and date gates were built to close, applied to how many seats get
charged for.

**Identity PII had no defined home.** Names, CNICs, passport numbers, dates of birth, and
emergency contacts are required to actually issue a booking, but collecting them as chat
messages would mean re-implementing (and having to keep in sync) all the document-type and
format validation the manual passenger forms already do — and would put sensitive
identifiers into the conversation transcript. There was no mechanism for the agent to reach
the existing secure forms mid-conversation.

## What was built

**Party-size gate → `get_booking_count_error()` and `apply_traveler_totals()` in
`agent_tools.py`, structurally identical to the existing gates.** `_BOOKING_REQUIRED_FIELDS`
was extended so flights and trains require an `adults` field and hotels require both
`guests` and `rooms`; `get_booking_count_error()` then enforces the exact manual-form
limits (flight total ≤ 9 and infants ≤ adults; train 1–6; hotel guests 1–10, rooms 1–5),
returning a structured `invalid_party_size` error that tells the model the limit plainly
and forbids re-calling with the same numbers. `apply_traveler_totals()` recomputes
`travelers` in code from `adults + children + infants` (hotels: from `guests`),
**overwriting whatever the model supplied** — the same trust boundary as server-side
repricing, and important because `travelers` feeds all three reprice functions (trains
multiply per passenger, hotels per room × night). Wired into `master_agent.py`'s
`prepare_booking` gate chain right after the missing-fields check:
missing → **count** → date → `apply_traveler_totals` → reprice. Room type is optional and
defaults to "Standard Room" (matching the manual API default) because agent search results
carry no room-type data yet; surfacing real room types is deferred to Phase 2 as a pricing
change.

**Hybrid identity collection → a native-form handoff, mirroring the payment pattern.** The
agent collects only trip-level essentials conversationally (route, dates, traveler
breakdown, class/room). Identity PII is never collected in chat. Instead, after
`prepare_booking` succeeds, the Flutter chat screen shows an "Add Passenger Details" step
that deep-links into the *existing* manual passenger form, launched with an `agentMode:
true` flag. The only behaviour that flag changes is the submit step: instead of navigating
deeper into the manual booking chain, the form returns its collected passenger and contact
data to the chat via `Get.back(result: {...})`. All document-type logic, field validation,
and saved-data autofill stay exactly as they are in the manual flow — untouched and shared.
The forms are entered with synthetic-but-real model objects built from the server-verified
booking data (real airline/train/hotel names, times, and the repriced total), so the forms'
own argument parsing needed no changes. The hotel form's paid-extras section
(breakfast / airport transfer / late checkout) is hidden in agent mode, because those would
desync the displayed total from the server-verified amount the agent is about to charge.

**Payment buttons are gated in code, not by prompt.** The chat renders the payment-choice
buttons only after the passenger form returns a non-empty passenger list; backing out of
the form leaves the gate closed. This makes "collect identity before paying" a deterministic
UI invariant rather than something the model is merely asked to sequence.

**Prompt additions for the conversational half.** `MASTER_AGENTIC_SYSTEM` gained: a MUST-ask
rule for group bookings without explicit counts ("family"/"we"/"my kids" without numbers →
ask, never invent); an explicit statement that a user volunteering their own real CNIC or
passport in chat is normal and honest — **not fraud** — and must be met by redirecting to
the secure form rather than a refusal (this closes a real false-positive against the fraud
policy); the two-step post-booking flow (passenger form, then payment); a once-only,
one-sentence car-transfer upsell; and "seats are assigned at check-in — never invent a seat
number."

**One robustness fix found mid-testing.** The live 8B model emitted an arithmetic
expression inside a JSON tool call (`"total_price_pkr": 5848*8`), which Groq rejected as a
malformed tool call and which crashed the tool loop past the existing salvage path. A narrow
`digits*digits` repair was added to the salvage code in `llm_service.py` — it only rewrites
a bare integer multiplication between JSON delimiters, leaves valid JSON untouched, and
still rejects genuine garbage. Safe by construction because that field is advisory only: the
server reprices regardless of what the model put there.

## The one known limitation, recorded deliberately

**A small model will invent a traveler count for a vague group request, and no code gate
can catch it.** When a user says "fly my family to Islamabad, book it" with no numbers,
`llama-3.1-8b-instant` invents a count (e.g. adults = 3 or 4) and proceeds, rather than
asking — **3 of 3 trials, even after the prompt was tightened to an explicit MUST-ask.**
This is unlike the price and date gates: an invented count of 3 is well-formed, within the
party-size limits, and prices correctly against a real flight, so there is nothing
malformed for a deterministic check to reject. It is a model instruction-following limit,
not a wording or validation gap.

The same trials on `llama-3.3-70b-versatile` leaked **0 of 3** — it showed options but never
called `prepare_booking` with an invented count. The risk is also bounded by two human
checkpoints the design already has: the booking summary displays the traveler count back to
the user before payment, and the native passenger form physically requires one identity
section to be filled per passenger — a wrong count cannot survive either unnoticed, so the
worst case is friction, not a wrong charge. On that basis this is **left as a documented
model-capability limitation with no code-level fix**, and the demo/production model was set
to 70B (`GROQ_MODEL`, see the `.env` / `config.py` comments), keeping 8B available for
cheaper local dev. Worth revisiting only if a future requirement puts an unattended booking
path (no summary, no per-passenger form) in front of the model.

## How Phase 1 was verified

**The parity gates** were unit-tested with 41 checks against the exact gate functions
production calls: every required-field set per booking type (including rejection of the
legacy payload shape that omits the new count fields), the count boundaries at 9 / 6 / 10 /
5, infants-not-exceeding-adults, the `travelers` overwrite (a model-supplied 99 is replaced
by the code-derived total), string-to-int coercion of counts, non-mutation of the caller's
dict, and the schema shape. The pre-existing booking-gate and budget regressions still
passed unchanged.

**The end-to-end flow** was smoke-tested across three runs against the real LLM and real
tools, mirroring the production gate chain, over four scenarios: a group flight (2 adults +
1 child reached the gate, `travelers` derived to 3 in code, price server-verified); a
volunteered CNIC (the model never echoed the number back and redirected to the secure form
— this is the case that first exposed, then confirmed the fix for, the fraud-policy
false-positive); a train for 8 (the `invalid_party_size` gate fired and the model relayed
the 6-passenger limit and offered to split the booking); and the family-with-no-counts
scenario above, which is what surfaced and quantified the 8B-vs-70B limitation (3/3 vs 0/3
across focused trials). The three Flutter forms and the chat screen pass `dart analyze`
cleanly.
