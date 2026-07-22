from __future__ import annotations
# =============================================================================
# PURPOSE: One source of truth for "what day is it" in a Pakistan-only travel app.
#
# Everything this backend books happens on Pakistan Standard Time. The user says
# "tomorrow" meaning their tomorrow, in Karachi. But the code was asking the
# SERVER what day it is, two different ways:
#
#   date.today()        -> the host's local date  (correct only on a PKT box)
#   datetime.utcnow()   -> the UTC date           (wrong 00:00-05:00 PKT, always)
#
# PKT is UTC+5, so between midnight and 5am Pakistan time the UTC date is still
# YESTERDAY. A user chatting at 2am — which is exactly when this app gets tested —
# is told "today is the 21st" when it is the 22nd, and their "tomorrow" resolves
# one day early. That is a real flight, on the wrong date, paid for.
#
# Pakistan has observed no DST since 2009, so a fixed offset is correct and needs
# no tzdata (which is not shipped on Windows by default — zoneinfo would raise).
# =============================================================================

from datetime import date, datetime, timedelta, timezone

# Pakistan Standard Time. Fixed offset, no daylight saving.
PK_TZ = timezone(timedelta(hours=5), name="PKT")


def pk_now() -> datetime:
    """Current wall-clock time in Pakistan, as a NAIVE datetime.

    Naive on purpose: every date/time value in this codebase (search results,
    departure times, stored bookings) is naive wall-clock, and mixing an aware
    datetime into those comparisons raises TypeError. This returns what a clock
    on a wall in Karachi reads.
    """
    return datetime.now(PK_TZ).replace(tzinfo=None)


def pk_today() -> date:
    """Today's date in Pakistan — the drop-in replacement for date.today()."""
    return pk_now().date()
