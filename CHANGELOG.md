# Changelog — Agent Performance & Correctness Pass

Scope: the agentic tool-calling loop in `backend/agents/master_agent.py` and its
supporting modules. For the earlier security/compliance hardening pass (price
injection, slot-completeness gates, refusal policy, date validation, grounded
facts, party-size limits, identity-form handoff), see
[CHANGELOG_agent_hardening.md](CHANGELOG_agent_hardening.md).

Everything below was driven against the real `process_message_agentic` loop —
no metric here is estimated.

## 2026-07-31

**Performance**
- Implemented deterministic round-trip prefetch — when origin, destination,
  and both dates are already known, both legs are searched in parallel from
  code-derived state (`derive_state`/`_wants_round_trip`), before spending an
  LLM turn asking for the tool call. A plain round-trip search now often
  resolves in **zero** LLM calls instead of two.
- Eliminated the redundant car-booking synthesis call — a standalone
  `book_car` booking broke the tool loop but the post-loop guard didn't know
  about it, so every successful car booking paid for one extra
  `generate_with_tools` call whose output was discarded unread. Fixed to 1
  call; response byte-identical.
- Fixed `prepare_booking` exposure on clarification turns — a numbered
  *clarifying question* ("1. dates? 2. passengers?") was matched as a priced
  offer list, sending `prepare_booking` a turn early; the model then failed
  the missing-fields gate and needed a second call just to ask. The offer-list
  detector now requires an actual price token (`PKR`, `Rs.`, `₨`), not just
  numbered-list shape.

**Correctness**
- Fixed a hotel/car search silently dropped when a round-trip render
  short-circuited — the deterministic renderer (both the prefetch fast path
  and the existing in-loop renderer) could answer from two same-tool transport
  results and end the turn even when a hotel or car was also requested in the
  same conversation. Now gated on `_outstanding_other_components`.
- Fixed a standalone car booking silently discarded when it completes
  alongside a package or single booking in the same model reply — the
  response contract carries only one action per turn, and the return cascade
  always picked the package/booking, dropping a fully valid, gate-passed car
  booking with no trace. Now acknowledged in the response text instead of
  disappearing.

**Review & hygiene**
- Ran a full senior-engineering production-readiness review (correctness,
  state management, concurrency, retry behaviour, logging, test coverage) —
  one High-severity bug found (the car+package omission above, now fixed);
  Medium/Low findings on duplicated dispatch logic, fire-and-forget task
  references, and router-layer test coverage recorded for the backlog.
- Fixed 23 static type-safety findings (Pylance) surfaced during the review —
  all narrowing/typing issues, no behavior changes.
- Added 81 new regression/adversarial tests across 4 new test files
  (round-trip prefetch, car-booking synthesis guard, car-alongside-package,
  offer-list detection). Full suite: **344 tests passing**.

### Benchmark: 12 representative production scenarios

Measured by `backend/tests/benchmark_production_scenarios.py` against the real
agent loop with a scripted model (one-way/round-trip flights, trains, hotels,
packages, healthcare, ambiguous requests, follow-ups):

| Metric | Before | After | Change |
|---|---|---|---|
| LLM calls (total across 12 scenarios) | 19 | 11 | **42% fewer** |
| Input tokens (total) | 60,213 | 33,103 | **45% fewer** |
| End-to-end latency (total, simulated) | 25.0s | 14.8s | **41% fewer** |

Reproduce with `python backend/tests/benchmark_production_scenarios.py`.
