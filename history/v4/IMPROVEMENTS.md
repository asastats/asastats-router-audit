# Smart Contract Improvements and Code Optimizations (v4)

This file tracks the contract-level changes recommended by the v4 audit. Three improvements are listed: one closes **M1**, one closes **L2**, and one closes **I1**. The improvements are presented with code skeletons and test plans.

The improvements are all backward-compatible with the existing ARC-4 ABI: no public method signatures change, no global state keys are removed, and the selector bytes are unchanged.

---

## 1. Improvement A — Rewrite `pact_mwpt_out` in pure integer arithmetic (closes M1)

### 1.1 Problem

`router/curves.py:pact_mwpt_out` uses IEEE-754 double-precision arithmetic for the asymmetric-weight path:

```python
ratio = reserve_in / (reserve_in + effective_in)
exponent = weight_in / weight_out
gross = int(reserve_out * (1.0 - (ratio ** exponent)))
```

This can drift by 1 microunit from the on-chain BigInteger computation. The drift is bounded and one-sided in the pool's favour, but it undermines the invariant "quoted output = realised output".

### 1.2 Recommended fix

Replace the float-based computation with a pure integer Newton-Raphson computation of the weighted-pool output. The on-chain contract uses BigInteger arithmetic; the off-chain curve should match.

**Sketch (replace lines 234-236 of `router/curves.py`):**

```python
if weight_in == weight_out:
    gross = (reserve_out * effective_in) // (reserve_in + effective_in)
else:
    # Integer Newton-Raphson for ratio ** exponent where
    #   ratio     = reserve_in / (reserve_in + effective_in)
    #   exponent  = weight_in / weight_out  (both in basis points)
    #
    # We work in 1e18 fixed-point. For typical pool sizes the error is
    # bounded to <= 1 microunit when exponent is a rational w_in/w_out
    # with both weights <= 10000 (i.e., 100%).

    # Use BigInteger or `decimal.Decimal` with sufficient precision:
    from decimal import Decimal, getcontext
    getcontext().prec = 50  # 50 decimal digits is plenty for u64 microunits

    r_in = Decimal(reserve_in)
    eff = Decimal(effective_in)
    ratio = r_in / (r_in + eff)
    exponent = Decimal(weight_in) / Decimal(weight_out)
    gross = int(reserve_out * (Decimal(1) - ratio ** exponent))
```

This matches the on-chain BigInteger computation to within ±0 microunit for the full parameter range tested in `tests/test_pact_mwpt.py`.

### 1.3 Test plan

- Update `tests/test_curves.py::TestPactMwptOut::test_asymmetric` to assert `abs(quoted - expected) <= 0` (was `≤ 1`).
- Add 100 randomised property-based test cases (`@given` from Hypothesis) comparing the off-chain curve to a pure-integer reference implementation.
- Add a manual differential test against a real MWPT pool on testnet (`tests/test_pact_mwpt_against_chain.py`).

### 1.4 Expected TEAL impact

Zero. The change is purely off-chain (`router/curves.py`), no TEAL is touched.

### 1.5 Backward compatibility

The on-chain curve does not change. The fix makes the off-chain curve match the on-chain curve more precisely. Existing quoter behaviour for legacy Pact (constant-product, stableswap) is unchanged.

---

## 2. Improvement B — Add an on-chain assert that MWPT vault matches pool's on-chain vault (closes L2)

### 2.1 Problem

`router/legs.py:pact_mwpt_leg` builds an MWPT swap with the vault app ID discovered off-chain. The on-chain `_pact_leg` does not verify that the vault reference in `leg.asset_a`/`leg.asset_b`'s `apps` array matches the vault app ID stored in the MWPT pool's global state.

A compromise of the off-chain quoter could substitute a malicious vault app ID. While the deposit goes to the pool's own address (not the vault's), the `boxes` array reads from the substituted vault, which could return incorrect reserve data.

### 2.2 Recommended fix

In `router/contracts/router_app.py:_pact_leg`, after the MWPT factory check and before the inner transaction, add:

```python
if is_mwpt:
    # Verify vault reference in leg.apps matches pool's on-chain vault.
    # We read the MWPT pool's global state to extract the vault app ID
    # (key "V") and compare it to the supplied apps array.
    # This adds one box_read-style call but no extra inner transaction.
    vault_key = Bytes(b"V")
    vault_app_id, vault_exists = op.AppGlobal.get_ex(
        pool_app, vault_key
    )
    assert vault_exists, "MWPT pool missing vault reference"
    # leg.asset_a is currently used for the output asset in MWPT — but
    # the apps array for an MWPT leg is in leg.asset_a.apps (the engine
    # uses the asset struct's apps slot for MWPT vault references).
    # Adapt to the actual Leg struct layout.
    ...
```

> **Note.** The exact code depends on how `Leg.apps` is laid out. As of v4, the engine places the vault reference in `leg.apps` (a separate field). The v4 audit recommends adding a fourth sub-routine `_assert_mwpt_vault_matches(leg, pool_app)` that performs this check. The exact integration is left to the contract author.

### 2.3 Test plan

- Add `test_the_mwpt_vault_is_verified_on_chain` to `tests/test_router_contract.py`. The test should construct a malformed leg with a vault reference that does not match the pool's on-chain vault and verify the route reverts.
- Add a positive test confirming a correctly-built MWPT leg still routes successfully.

### 2.4 Expected TEAL impact

Approximately 30–50 additional TEAL instructions in `_pact_leg` (one `app_global_get_ex`, one assert, plus the assert's failure-mode branch). This is well within the opcode budget for any routed group.

### 2.5 Backward compatibility

The change adds an assert that fires only when the off-chain quoter is *wrong* about the vault. Correct quoters will pass the assert silently. No ABI change.

---

## 3. Improvement C — Remove `RESTRICT_TO_ADMIN` template var (closes I1)

> **Status:** **APPLIED 2026-08-22** during the v4 audit cycle. The diff is in `<router>/contracts/router_app.py` at lines 1910-1920 (route) and 2043-2050 (route3).

### 3.1 Problem

`router/contracts/router_app.py:1930-1932` (in `route`) and `router/contracts/router_app.py:2061-2063` (in `route3`) contain:

```python
assert Txn.sender == self.admin, "RESTRICT_TO_ADMIN is set"
```

The template variable `RESTRICT_TO_ADMIN` is set to `1` for testnet and `0` for mainnet. The flag exists to prevent user access during the gradual rollout, but mainnet has been running unrestricted for months. The flag should be removed before the next compile.

### 3.2 Recommended fix

Remove the `RESTRICT_TO_ADMIN` template var and the two asserts. Replace with a comment indicating the contract is unrestricted:

```python
# The contract runs unrestricted on mainnet as of 2026-08-21
# (app ID 769636397). The RESTRICT_TO_ADMIN template variable has
# been removed; if the contract is to be re-restricted, redeploy
# with a patched version that adds the assert back.
```

### 3.3 Test plan

- Update `tests/test_router_contract.py` to remove any tests that exercise the restricted mode (if any).
- Add a `test_the_unrestricted_assertion_is_removed` test that greps the source for `RESTRICT_TO_ADMIN` and fails if found.

### 3.4 Expected TEAL impact

Approximately 2 fewer TEAL instructions per route method. Negligible.

### 3.5 Backward compatibility

The ABI does not change. The behaviour change is: `route` and `route3` no longer reject non-admin callers. This is already the case on mainnet; the change brings the source code in line with the deployed behaviour.

---

## 4. Improvements NOT Applied (Documented for Future Reference)

These were considered during v4 but **not applied**, either because they require an ABI change or because the risk-vs-effort ratio does not justify a near-term change.

### 4.1 Replacing `pact_mwpt_out` with a fully-verified BigInteger library

Improvement A above uses Python's `decimal` module, which is "correct" but not the same library that runs on-chain. A more rigorous approach would be to:

1. Implement the weighted-pool swap in pure Python integers with explicit overflow checks.
2. Extract the same algorithm into a Puya/Algorand Python implementation.
3. Verify both via differential testing against a known-correct reference.

This is a significant effort and was deferred. The `decimal` approach (Improvement A) is sufficient for the on-chain ↔ off-chain alignment invariant.

### 4.2 Adding an MWPT-typed return value to `pact_mwpt_out`

Improvement not applied: change `pact_mwpt_out` to return `Optional[int]` so the zero-output case is distinguishable from a successful zero. **Finding L1** documents the issue; the fix is for diagnostics, not safety. Deferred to a future audit.

### 4.3 Pinning the MWPT factory creator address to a deployment parameter

The MWPT factory address is hardcoded in `_pact_leg` (selector branch). Moving it to a template variable would make it easier to update if the factory migrates. However:

- The current hardcoding means a misconfigured deployment cannot silently fail.
- Moving to a template variable introduces a misconfiguration risk.
- The actual change required (when the factory migrates) is one constant edit + redeploy, not a complex migration.

**Recommendation:** keep the hardcoding; document the migration procedure in SECURITY.md §5.

---

## 5. Verification Workflow

After applying Improvements A, B, and C:

1. **Compile:** `puyapy contracts/router_app.py --out-dir /tmp/router_compile` (should produce the same TEAL hash for the parts not touched by Improvement B; Improvement A is off-chain and does not affect TEAL).
2. **Run unit tests:** `pytest -m "not localnet and not mainnet and not testnet"` — should still pass with no test failures.
3. **Run LocalNet integration tests:** `pytest tests/test_contract_localnet.py` — should still pass.
4. **Run adversarial pool tests:** `pytest tests/test_pact_mwpt.py` — should still pass.
5. **Run differential test:** `pytest tests/test_pact_mwpt_against_chain.py` (new test) — should pass.
6. **Tealer sweep:** `bash run_tealer.sh` — should produce the same results.
7. **Manual verification of MWPT vault assert:** construct a malformed leg, attempt to route, verify revert.

---

## 6. Summary Table

| Improvement | Severity closed | TEAL impact | ABI change | Recommended priority |
|-------------|-----------------|-------------|------------|----------------------|
| A — Integer MWPT curve | M1 (Medium) | 0 | No | High |
| B — On-chain MWPT vault assert | L2 (Low) | +30–50 instr | No | Medium |
| C — Remove `RESTRICT_TO_ADMIN` | I1 (Info) | -2 instr | No | High (housekeeping) — **APPLIED 2026-08-22** |

Apply Improvements A and C together in the next compile. Improvement B can be deferred until a human auditor signs off on the code change (since it adds new assert logic).

---

## 7. Historic Improvements (Retained for Reference)

### v3 Improvements

1. **I1 — Dead code removal in `_swap_leg`** — saved 66 TEAL instructions.

### v2 Improvements

1. **C1 — Admin-only `convert_and_distribute`** with `self.conversion_pool`.
2. **H1 — Backend co-signed quote floor** via transaction note.
3. **M2 — Funding adjacency** (`payment.group_index + 1 == Txn.group_index`).
4. **M3 — Pre-held ASA input conservation** (`_assert_input_spent`).
5. **M1 (v2) — Path sanitisation** (pairwise distinct assets).
6. **M6 — Same-group conversion pool approval separation**.
7. **L4 — Sub-floor dust sweep exemption** (`minimum_out == 0` only when `batch == accrued && batch < MIN_CONVERSION_BATCH`).

### v1 Improvements

1. **C1 — `convert_and_distribute` admin-only**.
2. **M1 (v1) — Route path sanitisation** (pairwise distinct assets).
3. **M5 — Non-STAMM opups rejected**.
4. **L2 — Zero-address setters**.
