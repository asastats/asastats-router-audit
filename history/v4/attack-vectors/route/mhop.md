# Multi-Hop Correctness Attack Vectors

These vectors analyze attacks that exploit the multi-hop composition: intermediate handoff, fee accumulation, rounding direction.

## Vectors

### ROUTE-MHOP-01: Intermediate asset mismatch between legs
- **Verdict:** Defended.
- **Code:** Each leg's `asset_out` is verified to match the next leg's `asset_in`.
- **Test:** Manual.

### ROUTE-MHOP-02: Fee compounding across hops
- **Verdict:** Defended.
- **Code:** Each pool's fee is taken by the pool; the router's fee is taken once on the input amount.
- **Test:** Manual.

### ROUTE-MHOP-03: Rounding direction across hops
- **Verdict:** Defended.
- **Code:** Each pool rounds in its own favour (constant-product, weighted, stableswap all round conservatively). The router does not perform arithmetic on intermediate amounts; it measures by balance delta.
- **Test:** Manual.

### ROUTE-MHOP-04: STAMM tier-merged leg + intermediate handoff
- **Verdict:** Defended.
- **Code:** `stamm_routed_leg` (off-chain) merges multiple tiers of the same pool into one `build_swap_routed` leg, with the handoff to the next pool using the balance delta measurement.
- **Test:** Manual.

### ROUTE-MHOP-05: MWPT → MWPT (two weighted pools in series)
- **Verdict:** Defended.
- **Code:** Each leg uses balance delta; intermediate handoff is correct.
- **Test:** `tests/test_pact_mwpt.py::test_two_mwpt_legs`.

### ROUTE-MHOP-06: `route3` middle leg is MWPT
- **Verdict:** Defended.
- **Code:** `route3` does not have provider-specific restrictions; any provider can be a middle leg.
- **Test:** Manual.
