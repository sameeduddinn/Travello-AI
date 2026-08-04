from __future__ import annotations
# PURPOSE: One source of truth for "what day is it" in a Pakistan-only travel app.
#
# Everything this backend books happens on Pakistan Standard Time. The user says
# "tomorrow" meaning their tomorrow, in Karachi. But the code was asking the
# SERVER what day it is, two different ways:
#
#   date.today()        -> the host's local date  (correct only on a PKT box)
#   datetime.utcnow()   -> the UTC date           (wrong 00:00-05:00 PKT, always)
#


from datetime import date, datetime, timedelta, timezone

# Pakistan Standard Time. Fixed offset, no daylight saving.
PK_TZ = timezone(timedelta(hours=5), name="PKT")


def pk_now() -> datetime:
    """Current wall-clock time in Pakistan, as a NAIVE datetime. """
    return datetime.now(PK_TZ).replace(tzinfo=None)


def pk_today() -> date:
    """Today's date in Pakistan: the drop-in replacement for date.today()."""
    return pk_now().date()
