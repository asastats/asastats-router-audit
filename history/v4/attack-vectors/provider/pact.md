# Pact (Constant-Product + Stableswap) Attack Vectors

Pact pools are applications; the router interacts via inner ApplicationCall. The pool's creator address is pinned in `PACT_POOL_CREATORS`.

## Vectors

### PACT-01: Pool deployed by wrong creator
- **Verdict:** Defended (M4 v3).
- **Code:** `_assert_created_by` checks `AppParamsGet.app_creator(pool) ∈ PACT_POOL_CREATORS`.
- **Test:** `tests/test_router_contract.py::test_pact_creator_pinned`.

### PACT-02: Pool creator migration
- **Verdict:** Accepted by design (residual).
- **Code:** `PACT_POOL_CREATORS` is a template variable; updating requires recompile + redeploy.
- **Test:** Manual.

### PACT-03: Constant-product vs. stableswap selector confusion
- **Verdict:** Defended.
- **Code:** The router uses `PACT_SWAP` selector for both pool types; the pool's own state determines which curve to apply.
- **Test:** Manual.

### PACT-04: Stableswap pool with extreme amplification factor
- **Verdict:** Defended.
- **Code:** The router measures output by balance delta; the pool's curve doesn't matter for measurement.
- **Test:** Manual.

### PACT-05: Stableswap pool with imbalanced reserves
- **Verdict:** Defended.
- **Code:** Same as above; balance delta measurement is independent of pool's curve.
- **Test:** Manual.

### PACT-06: Pact pool with paused state
- **Verdict:** Defended.
- **Code:** Pool reverts on swap; route reverts.
- **Test:** Manual.

### PACT-07: Pact pool with one asset = 0
- **Verdict:** Defended.
- **Code:** Pool is invalid; route rejects.
- **Test:** Manual.

### PACT-08: Pact pool reserves manipulable in same group
- **Verdict:** Not applicable.
- **Code:** Algorand atomic groups prevent external manipulation.
- **Test:** n/a.

### PACT-09: Pact pool reserves change between quote and execution
- **Verdict:** Defended.
- **Code:** Floor mechanism protects user.
- **Test:** Manual.

### PACT-10: Pact pool overpays (rounding direction)
- **Verdict:** Defended.
- **Code:** Output is the actual amount received, regardless of pool's rounding.
- **Test:** Adversarial pool test.

### PACT-11: Pact pool underpays
- **Verdict:** Defended.
- **Code:** Output is the actual amount received; if less than floor, route reverts.
- **Test:** Adversarial pool test.

### PACT-12: Pact pool takes input but returns nothing
- **Verdict:** Defended.
- **Code:** Output = 0; floor assertion fails.
- **Test:** Adversarial pool test.

### PACT-13: Pact pool sends to wrong recipient
- **Verdict:** Defended.
- **Code:** Router measurement on its own holding; pool's recipient error results in zero measurement.
- **Test:** Adversarial pool test.

### PACT-14: Pact pool with foreign asset array mismatched
- **Verdict:** Defended.
- **Code:** The router includes the pool's two assets in the inner txn's foreign_assets array. Mismatch causes pool call to fail.
- **Test:** Manual.

### PACT-15: Pact pool with extra fee box read
- **Verdict:** Defended.
- **Code:** The pool reads its own boxes; the router doesn't need to know.
- **Test:** Manual.

---

## MWPT sub-type

Pact MWPT pools are a sub-type with weighted reserves and a vault reference. See [`../pact/mwpt.md`](../pact/mwpt.md) for the 27 MWPT-specific vectors.
