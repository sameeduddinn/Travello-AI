"""Shared pytest setup: make `backend/` importable and pin the environment.

Run from the repo root with:  python -m pytest backend/tests -q
or from backend/ with:        python -m pytest tests -q

Nothing here needs network access or a real provider key. Every test in this
suite must pass on a clean checkout with no .env file at all — that is what
makes the suite a usable regression gate for someone else (a marker, a CI job,
a second machine) rather than a description of this laptop.
"""
import os
import sys

import pytest

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# ── Import-time environment ───────────────────────────────────────────────────
# core.config builds its Settings singleton at import, so anything that could
# make that construction *fail* has to be dealt with before the first test
# module is imported — a fixture runs far too late. DEBUG is the one that bites:
# it is a generic name and other tooling (Flutter/Gradle/CI) sets it to things
# like "release", which is not a boolean.
#
# config.py now coerces that itself, so this is belt-and-braces rather than the
# actual fix — but it also keeps the test run reproducible when the developer's
# shell has its own idea of DEBUG.
os.environ["DEBUG"] = "false"

# Fake provider credentials. Real ones must never decide whether a test passes:
# with a key present the suite would exercise one path on the developer's
# machine and a different one in CI. Every test that actually needs a provider
# mocks the call function, so these values are never used to reach a network.
#
# The default shape is ONE Groq key, supplied through the legacy GROQ_API_KEY
# name. That keeps every pre-existing test asserting exactly what it always
# did, and means a developer whose .env has two real keys does not silently get
# a different provider chain than CI. Rotation tests opt in by setting
# GROQ_API_KEY_1/GROQ_API_KEY_2 themselves.
_FAKE_KEYS = {
    "GROQ_API_KEY": "test-groq-key",
    "GROQ_API_KEY_1": "",
    "GROQ_API_KEY_2": "",
    "OPENROUTER_API_KEY": "test-openrouter-key",
    "GEMINI_API_KEY": "test-gemini-key",
}


@pytest.fixture(autouse=True)
def _pinned_provider_config(monkeypatch):
    """
    Pin provider configuration to fixed fake values for every test.

    This runs BEFORE each test's own monkeypatching, so a test that wants a
    provider switched off (`monkeypatch.setattr(svc.settings, "OPENROUTER_API_KEY", "")`)
    still wins, and monkeypatch's teardown restores it to the fake — never to
    whatever happened to be in the developer's .env.
    """
    from core.config import settings
    from services import llm_service

    for name, value in _FAKE_KEYS.items():
        monkeypatch.setattr(settings, name, value, raising=False)
    monkeypatch.setattr(settings, "GROQ_MODEL", "llama-3.3-70b-versatile", raising=False)
    monkeypatch.setattr(settings, "GEMINI_MODEL", "gemini-2.5-flash", raising=False)
    monkeypatch.setattr(
        settings, "OPENROUTER_MODEL", "openai/gpt-oss-20b:free", raising=False
    )

    # The SDK clients are cached module globals built from the keys above. A fake
    # key would build a real client object (no network at construction), but the
    # cache would then outlive this test, so clear it and let any test that needs
    # behaviour patch the client accessor or the call function itself.
    monkeypatch.setattr(llm_service, "_groq_client", None, raising=False)
    monkeypatch.setattr(llm_service, "_groq_client_2", None, raising=False)
    monkeypatch.setattr(llm_service, "_gemini_client", None, raising=False)
    monkeypatch.setattr(llm_service, "_gemini_active_model", None, raising=False)
    yield


@pytest.fixture(autouse=True)
def _clean_provider_state():
    """
    Provider cooldowns are module-level state by design (they must outlive a
    single request). Reset them around every test so one test's simulated 429
    can't silently disable a provider in the next.
    """
    from services import llm_service

    llm_service._reset_provider_state_for_tests()
    yield
    llm_service._reset_provider_state_for_tests()
