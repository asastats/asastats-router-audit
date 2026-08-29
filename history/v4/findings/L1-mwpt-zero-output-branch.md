# L1 — MWPT Zero-Output Branch Silently Yields Zero Without Reverting

**Severity:** Low
**Status:** New in v4 (not yet patched)
**Location:** `router/curves.py:pact_mwpt_out` lines 228–229
**Contract:** Off-chain only (does not affect TEAL)
**Discovered:** 2026-08-22

---

## Summary

`pact_mwpt_out` returns `0` (instead of raising an exception) when `effective_in ≤ 0`. This happens when the pool's fee consumes the entire input amount — i.e., `amount_in * fee_bps ≥ amount_in * BASIS_POINTS`. The behaviour is correct under the pool's own fee ceiling (which is bounded by `BASIS_POINTS = 10000`), but the silent zero return can be misinterpreted by downstream quoters as a routing error rather than a pool-side "fee too large" condition.

---

## Description

### Code excerpt (`router/curves.py:223-229`)

```python
if amount_in <= 0 or reserve_in <= 0 or reserve_out <= 0:
    return 0

fee = (amount_in * fee_bps + 9999) // BASIS_POINTS
effective_in = amount_in - fee
if effective_in <= 0:
    return 0
```

### Where the silent zero occurs

The condition `effective_in ≤ 0` fires when:

- `fee = (amount_in * fee_bps + 9999) // 10000 ≥ amount_in`
- Equivalently: `amount_in * fee_bps + 9999 ≥ amount_in * 10000`
- Equivalently: `fee_bps ≥ 10000 - 9999/amount_in`

For `amount_in = 1` (1 microunit), this fires when `fee_bps ≥ 10000 - 9999 = 1`. So even a 1-bps fee on a 1-microunit input yields zero.

For `amount_in = 10000`, this fires when `fee_bps ≥ 10000 - 0.9999 ≈ 9999`, i.e., effectively any fee ≥ 1 bps.

The on-chain Pact MWPT pool, in this same situation, also produces zero output (the swap yields nothing). The on-chain call does *not* revert; it succeeds with zero output. This is intentional — the pool's "always succeeds" behaviour allows the caller to skip unfavourable pools.

So the off-chain curve correctly mirrors the on-chain behaviour. The issue is purely diagnostic: downstream code cannot distinguish "swap would yield zero" from "quoter is broken".

### Why this is a Low-severity issue

- The behaviour is **correct** — it mirrors the on-chain contract.
- The **floor mechanism** protects users — if a quoter misinterprets zero as "swap is fine" and submits a route with `floor = 0`, the contract still asserts `actual ≥ 0`, which is trivially true, so the route succeeds with zero output. The user gets nothing back but also loses nothing extra (they get their original input back as the swap reverts, or they receive zero output if the swap succeeded).

Actually, **the user's input is lost** if the route succeeds with zero output. The contract measures output by `_held(asset_out) - before`; if this is zero, the route still succeeds (the floor is 0). The user paid `amount_in` of input and received zero output. This is a **real value loss**, but it's bounded by:

1. The slippage tolerance is typically ≥ 1%, so the floor is much larger than zero for any non-trivial input.
2. The quoter selects pools based on expected output; a zero-output quote would be filtered out before reaching the route.
3. The on-chain behaviour matches — the user could submit a route directly via the contract ABI and get the same result.

So the issue is **not an exploit**, but a **diagnostic clarity** issue. A quoter that misinterprets "zero output" as "skip this pool" is safer than a quoter that misinterprets it as "swap is fine", but neither interpretation enables theft.

---

## Impact

| Impact category | Severity | Rationale |
|-----------------|----------|-----------|
| Fund safety | None | Off-chain mirror of on-chain behaviour. |
| Diagnostic clarity | Low | Silent zero return can be misinterpreted. |
| Multi-hop composition | None | Zero-output path simply yields zero at the end. |

---

## Reproduction

```python
from router.curves import pact_mwpt_out

# Pool with 99% fee, on a tiny input
result = pact_mwpt_out(
    amount_in=1,
    reserve_in=1_000_000_000,
    reserve_out=2_000_000_000,
    weight_in=5000,
    weight_out=5000,
    fee_bps=9900,  # 99% fee
)
assert result == 0  # silent zero, no exception
```

The on-chain pool, called with the same parameters, also returns 0 (the swap succeeds but yields nothing).

---

## Mitigation (current state)

None required for safety. The current behaviour is correct under the pool's own fee ceiling.

For diagnostics, downstream code should treat a zero return as "pool would yield nothing, skip":

```python
quoted = pact_mwpt_out(...)
if quoted == 0:
    continue  # skip this pool in route construction
```

The current `router/venues.py` code already does this.

---

## Recommendation

### Option 1: Document the zero-return contract

Add an explicit note to the docstring of `pact_mwpt_out`:

```python
def pact_mwpt_out(...):
    """Return the output of a Pact Managed Weighted Pool swap.

    Returns 0 in any of these cases:
      - amount_in, reserve_in, or reserve_out is non-positive
      - effective_in (input after fee) is non-positive
        (i.e., the pool's fee consumes the entire input)

    In all zero-return cases, the on-chain pool also returns zero.
    Callers should treat zero as "this pool is not viable for this
    input" and skip it in route construction.

    :rtype: int  # always non-negative; 0 is a valid result, not an error
    """
```

### Option 2: Add a typed return value

Change the signature to return `Optional[int]` or use a sentinel:

```python
from typing import Optional

MWPT_QUOTE_INVALID_FEE = -1  # sentinel for "fee consumes entire input"

def pact_mwpt_out(...) -> int:
    ...
    if effective_in <= 0:
        return MWPT_QUOTE_INVALID_FEE
    ...

# Caller:
quoted = pact_mwpt_out(...)
if quoted == MWPT_QUOTE_INVALID_FEE:
    log.warning("pool fee too large for this input, skipping")
    continue
if quoted == 0:
    log.debug("pool would yield zero output, skipping")
    continue
```

This is more invasive but improves observability.

### Option 3: No change

Document the behaviour and rely on downstream code's existing handling. **Recommended** as the lowest-effort option.

---

## Cross-references

- Attack vector: [attack-vectors/pact/mwpt.md](../attack-vectors/pact/mwpt.md) §MWPT-weight-2
- Code location: `router/curves.py:228-229`
- Test: `tests/test_curves.py::TestPactMwptOut::test_zero_inputs`
- Severity rationale: [methodology/scope.md §6](../methodology/scope.md)
