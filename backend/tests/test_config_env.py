"""
Settings must survive a hostile ambient environment.

DEBUG is the problem child: it is a completely generic variable name, and
Flutter/Gradle/CI tooling routinely exports it with a build flavour in it. A
value pydantic can't read as a boolean used to abort Settings() construction —
which happens at import of core.config, so it takes down the whole process
before a single request is served, and takes down pytest collection with it.
There is no request to fail and no error to log: the container just never comes
up. Hence a validator, and hence these tests.
"""
import pytest
from pydantic import ValidationError

from core.config import Settings


@pytest.mark.parametrize("value", ["release", "Release", "RELEASE", "profile", "banana"])
def test_a_non_boolean_debug_does_not_abort_startup(value):
    """
    Anything we can't read resolves to False. That is the production-SAFE
    direction — worst case the app runs with debug output off, which is what a
    deployment wants anyway. It is never silent; config.py logs the coercion.
    """
    assert Settings(DEBUG=value).DEBUG is False


@pytest.mark.parametrize("value", ["true", "True", "1", "yes", "on", "debug", "development"])
def test_debug_still_turns_on_when_that_is_what_was_meant(value):
    assert Settings(DEBUG=value).DEBUG is True


@pytest.mark.parametrize("value", ["false", "False", "0", "no", "off", "production", ""])
def test_debug_off_words(value):
    assert Settings(DEBUG=value).DEBUG is False


def test_real_booleans_are_untouched():
    assert Settings(DEBUG=True).DEBUG is True
    assert Settings(DEBUG=False).DEBUG is False


def test_the_tolerance_is_scoped_to_debug_only():
    """
    Loosening one field must not loosen the rest — a typo'd port is still a
    startup error, because guessing a port silently is how you serve traffic
    nobody is listening for.
    """
    with pytest.raises(ValidationError):
        Settings(SMTP_PORT="not-a-port")


def test_provider_defaults_are_the_ones_verified_against_the_live_keys():
    """
    gemini-2.5-flash returns 404 "no longer available to new users" for this
    project's key, which silently disabled the entire Gemini fallback. The
    default must stay on the alias that actually resolves.

    Asserted against the FIELD DEFAULT, not a constructed Settings: reading the
    resolved value would make this test pass or fail on whatever .env happens to
    be on the machine, and a suite that depends on the local .env is the thing
    these tests exist to stamp out.
    """
    defaults = Settings.model_fields
    assert defaults["GEMINI_MODEL"].default == "gemini-flash-latest"
    assert defaults["GROQ_MODEL"].default == "llama-3.3-70b-versatile"
    assert defaults["DEBUG"].default is False
