# M5 — `opups` field is honoured for non-STAMM providers

**Severity:** Medium  
**Location:** `router/contracts/router_app.py`, `_swap_leg`  
**Status:** Patched in source

## Description

`Leg.opups` is intended to tell STAMM how many opcode-budget no-ops to buy. The off-chain builder sets it to zero for Tinyman, Pact, and AlgoFi.

However, `_swap_leg` would execute the budget call for any provider if `opups > 0`. The call goes to the STAMM budget application, which provides generic opcode budget to the group but charges a transaction fee and consumes a resource reference.

A caller who crafts a `Leg` with `opups > 0` for a non-STAMM provider can waste pooled fees and consume a reference slot.

## Impact

- Wasted transaction fees.
- Potential group-size or reference-count failures.
- Minor griefing vector.

## Fix

Added an assertion in `_swap_leg`:

```python
if provider != PROVIDER_STAMM:
    assert leg.opups.native == 0, "opups are only for STAMM"
```

This ensures the field is only used for its intended purpose.
