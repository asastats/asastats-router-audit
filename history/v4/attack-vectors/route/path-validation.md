# Path Validation Attack Vectors

These vectors analyze attacks that exploit the route's path structure: cycles, duplicate assets, malformed legs, and provider confusion.

The router's defence is the pairwise-distinctness assertion in `route` and `route3` (H1 invariant).

## Vectors

### ROUTE-PATH-01: Cycle A → B → A in `route`
- **Verdict:** Defended (M1 v3).
- **Code:** `route` asserts `asset_in != asset_middle` and `asset_middle != asset_out` and `asset_in != asset_out`.
- **Test:** `tests/test_router_contract.py::test_route_rejects_cycle`.

### ROUTE-PATH-02: Duplicate asset in `route3`
- **Verdict:** Defended (M1 v3).
- **Code:** `route3` asserts all pairwise distinct.
- **Test:** `tests/test_router_contract.py::test_route3_rejects_duplicates`.

### ROUTE-PATH-03: Cycle in 4-hop route
- **Verdict:** Defended.
- **Code:** `route3` (3-leg) + `route` (2-leg) chained would require a separate group, so atomicity breaks across groups.
- **Test:** Manual.

### ROUTE-PATH-04: Invalid asset ID (asset that doesn't exist)
- **Verdict:** Defended.
- **Code:** Asset opt-in fails; route reverts.
- **Test:** Manual.

### ROUTE-PATH-05: Asset ID = 0 (ALGO) used incorrectly
- **Verdict:** Defended.
- **Code:** ALGO is handled specially; asset_in == 0 means ALGO input. Asset opt-in not needed.
- **Test:** Manual.

### ROUTE-PATH-06: Asset ID overflow (> 2^64)
- **Verdict:** Defended.
- **Code:** `arc4.UInt64` rejects overflow at the ABI level.
- **Test:** Verified at compile time.

### ROUTE-PATH-07: Leg with provider not in {Tinyman, Pact, STAMM, AlgoFi}
- **Verdict:** Defended.
- **Code:** `_swap_leg` switch statement covers all 4 providers; default case asserts false.
- **Test:** Manual.

### ROUTE-PATH-08: Leg with `opups > 0` for non-STAMM provider
- **Verdict:** Defended (M5 v3).
- **Code:** `_swap_leg` asserts `leg.opups.native == 0` for non-STAMM.
- **Test:** `tests/test_router_contract.py::test_non_stamm_opups_rejected`.
