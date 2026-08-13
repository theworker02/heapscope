# HS005 — callback_accumulation

## What it means

Listeners, subscribers, or observer lists grow over time (often repeated registration without unsubscribe).

## Evidence used

- Listener count series (via adapters)
- Proc/Array growth near event buses

## Fixes

Unsubscribe on teardown; register once at boot; use weak references where appropriate.
