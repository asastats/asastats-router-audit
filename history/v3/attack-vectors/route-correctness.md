# Attack Vectors: Route Correctness & Path Sanitization

## Overview
Path manipulation attacks include circular routing (e.g. A -> B -> A), self-swaps, intermediate asset spoofing, and precision loss during multi-hop calculations.

---

### Detailed Attack Vector Analysis

#### AV-ROU-01: Circular Routes & Duplicate Intermediate Assets (Finding M1)
- **Attack Description:** An attacker submits a route with identical input/output assets (A -> B -> A) or self-intersecting legs (A -> B -> B -> C) to grief accounting or drain fees.
- **Risk Level:** MEDIUM
- **Verdict:** **Defended**
- **Mechanism:**
  - In `route`:
    - `assert asset_in != asset_out, "a route must change the asset"`
    - `assert middle != asset_in, "route visits the same asset twice"`
    - `assert middle != asset_out, "route visits the same asset twice"`
  - In `route3`:
    - Asserts all four assets (`asset_in`, `first_middle`, `second_middle`, `asset_out`) are pairwise distinct.

#### AV-ROU-02: Pre-Held Asset Input Stranding (Finding M3)
- **Attack Description:** The router already holds a balance of an ASA (e.g., frequently routed asset). Leg 1 consumes only part of the caller's input, leaving the rest stranded in the router account.
- **Risk Level:** HIGH
- **Verdict:** **Patched**
- **Mechanism:** `_assert_input_spent(asset_in, input_before, amount_in)` verifies that `self._held(asset_in) == before - amount`, proving 100% of the caller's input was forwarded to the pool.

#### AV-ROU-03: Intermediate Asset Dust Accumulation
- **Attack Description:** Multi-hop integer divisions leave residual units in intermediate holdings, which accumulate over time and skew subsequent swaps.
- **Risk Level:** LOW
- **Verdict:** **Defended**
- **Mechanism:** At the end of each route call, the router asserts `self._held(middle) == 0` before closing the holding back to the caller. No intermediate dust remains in the contract.

#### AV-ROU-04: Multi-Hop Fee Precision Bleed
- **Attack Description:** Compounding fees across 3-hop routes causes arithmetic underflow or excessive fee deduction.
- **Risk Level:** LOW
- **Verdict:** **Defended**
- **Mechanism:** Fees are skimmed exactly once per route on the ALGO intermediate leg. In 3-leg routes, if both intermediates are ALGO (impossible due to distinctness), or whichever intermediate is ALGO, fee is calculated once with full 64-bit integer precision.
