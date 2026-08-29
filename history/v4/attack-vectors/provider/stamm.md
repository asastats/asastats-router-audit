# STAMM Attack Vectors

STAMM pools are stratified constant-product AMMs with multiple tiers. The router interacts via inner ApplicationCall, with `STAMM_POOL_CREATORS` pinning the pool creator.

The STAMM-specific complication is the multi-tier routing: a single STAMM pool can route across multiple fee tiers within the same application call. This is handled by the `Leg.routed` field (when `true`, the leg is a single-call multi-tier swap).

## Vectors

### STAMM-01: Pool deployed by wrong creator
- **Verdict:** Defended (M4 v3).
- **Code:** `_assert_created_by` checks against `STAMM_POOL_CREATORS`.
- **Test:** `tests/test_router_contract.py::test_stamm_creator_pinned`.

### STAMM-02: STAMM pool with opups > MAX
- **Verdict:** Defended (M5 v3).
- **Code:** `_swap_leg` asserts `leg.opups.native <= MAX_STAMM_OPUPS = 8`.
- **Test:** `tests/test_stamm_opups.py`.

### STAMM-03: STAMM pool with `routed = false` but multi-tier expected
- **Verdict:** Defended.
- **Code:** `Leg.routed` is set by the off-chain quoter based on whether the pool has multiple tiers with similar prices.
- **Test:** Manual.

### STAMM-04: STAMM pool with extreme tier weight skew
- **Verdict:** Defended.
- **Code:** Output is measured by balance delta; tier distribution doesn't matter.
- **Test:** Manual.

### STAMM-05: STAMM pool with empty tier
- **Verdict:** Defended.
- **Code:** The pool reverts on swap to an empty tier.
- **Test:** Manual.

### STAMM-06: STAMM pool reserves manipulable
- **Verdict:** Not applicable.
- **Code:** Algorand atomic groups.
- **Test:** n/a.

### STAMM-07: STAMM pool hook application is malicious
- **Verdict:** By design (STAMM v3 audit M2/M3).
- **Code:** The hook is admin-controlled; the router does not interact with the hook directly.
- **Test:** n/a.

### STAMM-08: STAMM pool admin upgrades tier fees
- **Verdict:** Defended.
- **Code:** Output is the actual amount received; floor protects user.
- **Test:** Manual.

### STAMM-09: STAMM pool admin pauses trading
- **Verdict:** Defended.
- **Code:** Pool reverts on swap; route reverts.
- **Test:** Manual.

### STAMM-10: STAMM pool notification hub missing from foreign_apps
- **Verdict:** Defended.
- **Code:** The router includes the hub in the leg's `apps` field.
- **Test:** Manual.

### STAMM-11: STAMM pool takes a different fee than declared
- **Verdict:** Defended.
- **Code:** Output is the actual amount received.
- **Test:** Adversarial pool test.

### STAMM-12: STAMM pool tier merge collision (two `pool_budget` calls)
- **Verdict:** Defended.
- **Code:** `stamm_routed_leg` merges multiple tiers of the same pool into one `build_swap_routed` leg; two separate opup calls would cause "transaction already in ledger" collision.
- **Test:** `tests/test_stamm_opups.py::test_tier_merge`.

### STAMM-13: STAMM opup application is wrong
- **Verdict:** Defended.
- **Code:** The STAMM opup application ID is supplied by the leg's `apps` field.
- **Test:** Manual.

### STAMM-14: STAMM pool reserves overflow uint64
- **Verdict:** Not applicable.
- **Code:** STAMM uses BigInteger (128-bit) internally; the router receives uint64 outputs.
- **Test:** Manual.

### STAMM-15: STAMM TWAP oracle manipulation
- **Verdict:** Not applicable.
- **Code:** The router does not read the TWAP oracle.
- **Test:** n/a.
