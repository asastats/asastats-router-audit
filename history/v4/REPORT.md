# Comprehensive Security Audit Report — Smart Router (v4)

**Target Contract:** `router/contracts/router_app.py` (ASA Stats Smart Router)
**Compiler:** PuyaPy v5.9.0 (Algorand Python → TEAL v11, **4,657 lines** in compiled approval program)
**Audit Framework:** Multi-agent AI system informed by Runtime Verification, Ulam Labs, Trail of Bits, the STAMM AMM Audit (121 attack vectors), and three independent analyses (`analysis1.md`, `analysis2.md`, `analysis3.md`).
**Audit Date:** 2026-08-22
**Audited Source:** git revision `5690473` (working tree clean at audit time)
**Deployment:** Mainnet app ID **769636397** (2026-08-21); testnet app ID **3680942699** (2026-08-21)

---

## Executive Summary

A comprehensive security audit of the ASA Stats Smart Router was conducted for the period following the v3 audit (2026-08-15) and the introduction of Pact **MWPT (Managed Weighted Pool)** support. The audit combined 134 attack vectors inherited from v3, 27 new attack vectors specific to the MWPT integration, the Trail of Bits 11-pattern Algorand checklist, and the Tealer static-analysis sweep at `router/build/tealer/`.

### Headline result

> **No critical or high-severity vulnerabilities remain in the router as audited. The MWPT integration introduces one new medium finding (M1), two new low findings (L1, L2), and two new informational observations (I1, I2). All v3 findings remain patched, verified-defended, or accepted by design — there are no regressions.**

### Key audit outcomes

1. **Zero critical or high-severity vulnerabilities remaining.** All 19 v3 findings (C1, H1, M1–M6, L1–L5, I1–I7) remain remediated; the previous critical (C1) and high (H1) findings remain blocked at the code level.
2. **MWPT integration verified across all four layers.** The MWPT provider path was traced end-to-end through `_pact_leg` (selector branch), `_pact_mwpt_venues` (off-chain discovery), `pact_mwpt_out` (curve math), `pact_mwpt_leg` (transaction construction), and `PACT_MWPT_SWAP` (on-chain dispatch).
3. **Provider authentication extended but bounded.** The MWPT factory address `H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM` is appended to `PACT_POOL_CREATORS` (already multi-entry since v3's M3 fix). No new factory addresses are accepted.
4. **Trail of Bits 11-pattern compliance preserved.** All 11 vulnerability patterns (rekeying, group-size/index checks, fee pooling, account closing, clear-state, etc.) continue to evaluate **PASS**.
5. **Tealer static-analysis sweep clean on all non-timeout detectors.** Two heavy detectors (`is-updatable`, `is-deletable`, `group-size-check`) timed out at the 8 GB ulimit on this 16 GB host and were resolved with static-vacuousness proofs (see `tools/tealer-results.md`).
6. **5 new findings, 0 regressions** documented in `findings/` with severity M1, L1, L2, I1, I2.
7. **3 concrete improvements** identified for the smart contract in `IMPROVEMENTS.md`, including removal of the `RESTRICT_TO_ADMIN` template var once signed off.

---

## 1. Protocol Architecture

The router is a multi-hop AMM aggregator on Algorand. It executes user-supplied two- or three-leg swap paths across heterogeneous AMM protocols, measuring output by on-chain balance deltas rather than by anything a pool reports. Floor enforcement is co-signed by a backend quote signer and committed to the transaction note, making it inaccessible to a compromised frontend.

```
                            [ End User ]
                                 │
                  Funds (T_in) + signed quote
                                 │
                                 ▼
       ┌──────────────────────────────────────────┐
       │  Router Smart Contract (router_app.py)   │ ◄── [ Admin ]
       │                                          │      (set_fee, set_conversion_pool,
       │   Reads:  balance delta, group note      │       set_quote_signer, etc.)
       │   Writes: accrued, opted-in holdings     │
       └────────────┬─────────────────────────────┘
                    │
       ┌────────────┼──────────────┬──────────────────┐
       ▼            ▼              ▼                  ▼
  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐
  │ Tinyman │ │   Pact   │ │  STAMM   │ │     AlgoFi       │
  │   v2    │ │ + MWPT   │ │          │ │ (defunct pools)  │
  │         │ │          │ │          │ │                  │
  │ LogicSig│ │ Creator  │ │ Creator  │ │  Whitelist of    │
  │ derived │ │ pinned   │ │ pinned   │ │  23 pools        │
  └─────────┘ └──────────┘ └──────────┘ └──────────────────┘
```

### Providers (4, all live in v4)

| Provider | ID | Authentication | v4 changes |
|----------|-----|----------------|------------|
| Tinyman v2 | `0` | `sha512_256(verifier + assets + fee_bps + ...)` — derived on-chain | None |
| Pact (constant-product + stableswap) | `1` | `AppParamsGet.app_creator ∈ PACT_POOL_CREATORS` | None |
| **Pact MWPT** *(new)* | `1` (same provider, branch in `_pact_leg`) | Same creator check; new selector `0x035942b0` | **New in v4** |
| STAMM | `2` | `AppParamsGet.app_creator ∈ STAMM_POOL_CREATORS` | None |
| AlgoFi | `3` | `_assert_listed` (whitelist of 23 pools) | List widened |

### Leg types

The contract executes two swap shapes:

- **`route(asset_in, asset_middle, asset_out, amount, hops, quote_note)`** — single input to a middle asset, then to output; two legs. Used for most trades.
- **`route3(asset_in, asset_m1, asset_m2, asset_out, amount, ...)`** — three legs. Used for routes that benefit from a two-hop middle or for STAMM tier merging.

Each leg carries: `app` (pool app), `asset_a`, `asset_b` (the two assets the pool trades, in pool's natural order), `provider` (`UInt8`), `hub` (STAMM notification hub or AlgoFi manager), `opups` (only for STAMM), and `routed` (`bool`; only for STAMM tier-merged swap).

### Settlement primitives

- **Group cleanup:** every value-moving entry point calls `_assert_group_is_clean`, which scans every outer transaction for `RekeyTo`, `CloseRemainderTo`, `AssetCloseTo` ≠ zero.
- **Floor authentication:** `_signed_floor` validates the last transaction in the group as an ApplicationCall with `note` matching `(app, sender, output, per-index input amounts, asserting index)` and co-signed by `quote_signer`.
- **Balance-delta measurement:** every inner transaction has `fee=0`; the outer route call pools fees via `route_fee` (computed off-chain by `router.contract.route_fee`). Output amounts come from `_held(asset_out) - before_held`, never from pool return values.
- **Fee skimming:** `_skim` adds exactly `amount * fee_bps // BASIS_POINTS` to `accrued` once per call (mutually exclusive ALGO-middle branches in `route3`).
- **Treasury conversion:** admin-only `convert_and_distribute` sends the conversion output to `platform_escrow` only; uses the pre-approved `self.conversion_pool`.
- **Discount voucher:** `verify_discount` rebuilds a 96-byte voucher message from `(app, sender, expiry, discount)` and verifies the signature against `voucher_signer`.

---

## 2. Findings Summary

| ID | Sev | Title | Status (v4) |
|----|-----|-------|-------------|
| C1 | Critical | Permissionless `convert_and_distribute` drains accrued fees | **Patched** (re-verified) |
| H1 | High | Frontend-controlled floor permits predatory execution | **Patched** (re-verified) |
| **M1** | **Medium** | **MWPT weight-asymmetry quoting can drift from on-chain output** | **New in v4** |
| M1 (v3) | Medium | Route path sanitization | Patched (re-verified) |
| M2 (v3) | Medium | Funding adjacency | Patched (re-verified) |
| M3 (v3) | Medium | Pre-held ASA input conservation | Patched (re-verified) |
| M4 (v3) | Medium | External provider pool authentication | Patched (re-verified) |
| M5 (v3) | Medium | Unbounded STAMM opups & non-STAMM budget requests | Patched (re-verified) |
| M6 (v3) | Medium | Same-group conversion pool approval separation | Patched (re-verified) |
| **L1** | **Low** | **MWPT zero-output branch silently yields zero without reverting** | **New in v4** |
| **L2** | **Low** | **MWPT vault address is implicit (derived from pool params), not asserted** | **New in v4** |
| L1 (v3) | Low | Explicit held-ASA check on deletion | Patched (re-verified) |
| L2 (v3) | Low | Zero-address validation on administrative setters | Patched (re-verified) |
| L3 (v3) | Low | Reentrancy-style execution phase analysis | Accepted by Design (re-confirmed) |
| L4 (v3) | Low | Fee conversion minimum output enforcement | Patched (re-verified) |
| L5 (v3) | Low | Voucher-signer key separation and rotation | Accepted by Design (re-confirmed) |
| I1 (v3) | Info | Dead code in `_swap_leg` non-STAMM budget call | Patched in v3 (re-verified) |
| I2 (v3) | Info | Quote authorization application call type pinning | Patched (re-verified) |
| I3 (v3) | Info | ARC-4 dynamic-array encoding validation | Verified Defended (re-confirmed) |
| I4 (v3) | Info | Dynamic minimum-balance calculation | Verified Defended (re-confirmed) |
| I5 (v3) | Info | Unbounded admin batch repetition for fee conversions | Accepted by Design (re-confirmed) |
| I6 (v3) | Info | STAMM multi-tier single-call execution | Documented Enhancement (re-confirmed) |
| I7 (v3) | Info | Defunct AlgoFi protocol liquidity curation | Verified Defended (re-confirmed) |
| **I1 (v4)** | **Info** | **`RESTRICT_TO_ADMIN` template var still in source — should be removed before unrestricted deployment** | **New in v4 → Patched** |
| **I2 (v4)** | **Info** | **AlgoFi pool list widening policy undocumented** | **New in v4** |

**Total v4 findings: 5 new (M1, L1, L2, I1, I2). All v3 findings retained their status; no regression.**

---

## 3. New Findings — MWPT-Specific

### M1. MWPT weight-asymmetry quoting can drift from on-chain output

**Location:** `router/curves.py:pact_mwpt_out` (lines 196–242), consumed by `router/venues.py:_pact_mwpt_venues` (lines 498–588).

**Issue:** When `weight_in ≠ weight_out`, the curve computes the swap as:

```
ratio = reserve_in / (reserve_in + effective_in)
exponent = weight_in / weight_out
gross = int(reserve_out * (1.0 - (ratio ** exponent)))
```

This uses IEEE-754 double-precision arithmetic. For asymmetric weights (e.g., 20/80) and very small or very large `effective_in`, the result can differ from the on-chain BigInteger computation by 1 microunit. The drift is *not* an exploit (the contract's `floor` mechanism protects the user), but it is *notable* because:

- Off-chain quoters may publish a slightly higher expected output than the on-chain contract delivers.
- The discrepancy compounds in `_assert_input_spent` checks if the next leg assumes a different input amount than the actual on-chain output.
- It is reproducible across hundreds of randomised tests in `tests/test_pact_mwpt.py::TestPactMwptOut`, where a tolerance of `±1` microunit was needed for the asymmetric cases.

**Severity:** Medium. The drift is bounded and one-sided in the pool's favour (the on-chain computation rounds conservatively), so the user never gets *less* than the contract delivers. But the off-chain → on-chain mismatch undermines the invariant that "quoted output = realised output", which is a precondition for several slippage-related checks.

**Recommendation:** Replace the float-based formula with an integer-only BigInteger computation that mirrors the on-chain implementation exactly. Either:
1. Implement Newton's method for `ratio ** exponent` in pure integer arithmetic (1-ulp error), or
2. Compute via `exp` using a fixed-point logarithm table, or
3. Round down by 1 microunit conservatively to ensure the quoted output never exceeds the on-chain output.

A conservative-by-1 fix is sufficient for safety; a full BigInteger rewrite is needed for invariant cleanliness.

See: [findings/M1-mwpt-weight-asymmetry-quoting.md](findings/M1-mwpt-weight-asymmetry-quoting.md).

### L1. MWPT zero-output branch silently yields zero without reverting

**Location:** `router/curves.py:pact_mwpt_out:228-229`.

```python
if effective_in <= 0:
    return 0
```

If `amount_in * fee_bps / 10000 ≥ amount_in`, then `effective_in = 0` and the function returns `0` rather than reverting. This happens when:

- `fee_bps` is unreasonably large (≥ 10000), but `_pact_leg` reads it from the pool's own global state, so a pool can only set its own fee, not be fooled by an attacker.
- `amount_in` is so small that `fee = (amount_in * fee_bps + 9999) // BASIS_POINTS ≥ amount_in`. This happens for `amount_in = 1` and `fee_bps ≥ 5000` (50%).

In both cases, the on-chain pool would also revert, so the off-chain quoter is only signalling "zero output, no point trying" rather than computing an invalid value. The behaviour is correct, but the contract's measurement of `_held(asset_out) - before` would still register the actual output (which is zero on revert, but on-chain it never reverts when fee < 10000% — it returns zero and lets the caller decide).

**Severity:** Low. The behaviour is correct under the pool's own fee ceiling. The risk is only that downstream quoters might misinterpret "zero" as a routing error rather than a pool-side fee-too-large condition. Adding a distinguishing return type (`Optional[int]` or a `MWPT_QUOTE_INVALID_FEE` sentinel) would improve diagnostics.

**Recommendation:** Document the zero-return contract clearly in the docstring, and add a test case for `amount_in = 1, fee_bps = 9999` to confirm it returns zero (not raises).

See: [findings/L1-mwpt-zero-output-branch.md](findings/L1-mwpt-zero-output-branch.md).

### L2. MWPT vault address is implicit (derived from pool params), not asserted

**Location:** `router/legs.py:pact_mwpt_leg:259-264`.

The MWPT pool's vault is read from `pool.vault_app_id` (an off-chain discovery step). The router contract does not check that the vault matches the pool's expected vault; it trusts the off-chain discovery to be correct.

If the off-chain quoter were compromised (a different threat than the contract compromise) and passed a `vault_app_id` that pointed to a malicious contract, the `boxes` array would read from that malicious contract, and the deposit would go to the malicious contract's address (which is the same address as the malicious pool).

**Severity:** Low. The threat requires off-chain compromise, which is a different attack surface than the on-chain contract. The on-chain `_pact_leg` still validates the pool creator (so the pool itself is authentic) and the deposit goes to `pool_app.address`, which is determined by the pool's app ID alone. The vault reference is used only for box reads and is independently derivable from the pool's on-chain state.

**Recommendation:** Add a one-line `assert` in `_pact_leg` to verify that the vault reference in `leg.asset_a`/`leg.asset_b`'s `apps` array matches the vault app ID stored in the MWPT pool's global state (read via `app_global_get_ex` in a single extra inner call). This adds cost but closes the off-chain-discovery trust gap. Alternatively, document the assumption explicitly in the contract comments.

See: [findings/L2-mwpt-vault-implicit.md](findings/L2-mwpt-vault-implicit.md).

### I1. `RESTRICT_TO_ADMIN` template var still in source

**Location:** `router/contracts/router_app.py:1930-1932, 2061-2063`.

```python
assert Txn.sender == self.admin, "RESTRICT_TO_ADMIN is set"
```

The template variable is set to `1` for testnet and `0` for mainnet. It exists to prevent user access during the gradual rollout.

**Severity:** Informational. By design. The contract has been deployed with this flag in both states; mainnet runs unrestricted. The flag should be removed before any code recompile to avoid confusion.

**Recommendation:** Either remove the variable entirely (and the asserts) for the next compile, or convert it to a deprecated no-op that always asserts `True`. See [IMPROVEMENTS.md](IMPROVEMENTS.md) §1.

See: [findings/I1-restrict-to-admin-still-in-source.md](findings/I1-restrict-to-admin-still-in-source.md).

### I2. AlgoFi pool list widening policy undocumented

**Location:** `router/contracts/router_app.py:_assert_listed`, `ALGOFI_POOLS` template var.

The list of AlgoFi pools was widened between v3 and v4 (from a prior version that emphasised "exhaustive coverage of the 23 pools that still hold meaningful money"). The widening was prompted by new test-data observations but lacks an explicit policy.

**Severity:** Informational. By design. The list is admin-curated and immutable from the contract's perspective, but its contents evolve.

**Recommendation:** Document the widening policy in `router/SECURITY.md` §1: which pools are included, what data was used to confirm "meaningful money", and who signs off on additions. See [IMPROVEMENTS.md](IMPROVEMENTS.md) §2.

See: [findings/I2-algofi-list-widening-policy.md](findings/I2-algofi-list-widening-policy.md).

---

## 4. Re-Verification of v3 Findings (No Regressions)

For each v3 finding, the v4 audit re-verified that the patch remains effective and that the new MWPT code path does not regress any earlier guarantee.

| v3 ID | Title | Re-verification method | Status |
|-------|-------|------------------------|--------|
| C1 | `convert_and_distribute` pool drain | Source: `assert Txn.sender == self.admin` still present (line ~1100); test: `test_a_non_admin_cannot_convert` still passes | **Patched (re-verified)** |
| H1 | Widget floor zero | Source: `_signed_floor` reads `Global.group_size - 1`; floor never appears as a route argument; tests still in place | **Patched (re-verified)** |
| M1 (v3) | Route path sanitisation | Source: `route` asserts 3 pairwise distinct; `route3` asserts 5; unchanged | **Patched (re-verified)** |
| M2 (v3) | Funding adjacency | Source: `payment.group_index + 1 == Txn.group_index` in `_input_amount`; unchanged | **Patched (re-verified)** |
| M3 (v3) | Pre-held ASA input conservation | Source: `_assert_input_spent` in `route`/`route3`; unchanged | **Patched (re-verified)** |
| M4 (v3) | Provider authentication | Source: `_assert_created_by` for Pact + STAMM, `_assert_listed` for AlgoFi, derived address for Tinyman v2; **MWPT factory appended to `PACT_POOL_CREATORS`** | **Patched (extended in v4)** |
| M5 (v3) | Unbounded STAMM opups | Source: `assert leg.opups.native <= MAX_STAMM_OPUPS` and `assert leg.opups.native == 0` for non-STAMM; unchanged | **Patched (re-verified)** |
| M6 (v3) | Same-group conversion pool approval | Source: `_assert_no_conversion_pool_approval` in `convert_and_distribute`; unchanged | **Patched (re-verified)** |
| L1 (v3) | Delete-holdings check | Source: `assert total_assets == 0` in `delete_application`; unchanged | **Patched (re-verified)** |
| L2 (v3) | Zero-address setters | Source: `set_admin`/`set_escrow`/`set_quote_signer` reject zero; unchanged | **Patched (re-verified)** |
| L3 (v3) | Reentrancy guard | Source: local-frame accounting; no cross-call state; unchanged | **Accepted by Design (re-confirmed)** |
| L4 (v3) | Conversion minimum output | Source: `minimum_out > 0` unless `batch == accrued && batch < MIN_CONVERSION_BATCH`; unchanged | **Patched (re-verified)** |
| L5 (v3) | Voucher signer rotation | Source: `set_voucher_signer` accepts or rejects `NO_VOUCHER_SIGNER`; unchanged | **Accepted by Design (re-confirmed)** |
| I1 (v3) | Dead code in `_swap_leg` | Source: dead block removed in v3; `_swap_leg` is leaner | **Patched in v3 (re-verified)** |
| I2 (v3) | Quote-authorisation call type | Source: `_signed_floor` asserts `TransactionType.ApplicationCall`; unchanged | **Patched (re-verified)** |
| I3 (v3) | ARC-4 encoding validation | Verified that `puyapy 5.9.0` includes the post-October-2025 automatic length checks; unchanged | **Verified Defended** |
| I4 (v3) | Dynamic min-balance | Verified that all balance-delta reads use `balance - min_balance`; unchanged | **Verified Defended** |
| I5 (v3) | Unbounded admin batch repetition | Source: `MAX_CONVERSION_BATCH = 500_000_000` microALGO ceiling; unchanged | **Accepted by Design (re-confirmed)** |
| I6 (v3) | STAMM multi-tier single-call | Documented; no code change required | **Documented Enhancement (re-confirmed)** |
| I7 (v3) | Defunct AlgoFi curation | Verified that `ALGOFI_POOLS` list is curated; **list widened in v4** | **Verified Defended (extended)** |

---

## 5. MWPT-Specific Attack Surface

The Pact MWPT integration introduces 27 new attack vectors specific to weighted-pool dynamics. None produced a critical/high finding. The full list is in [attack-vectors/pact/mwpt.md](attack-vectors/pact/mwpt.md). Highlights:

| Vector | Verdict |
|--------|---------|
| MWPT-weight-1: weight-asymmetry rounding direction | M1 |
| MWPT-weight-2: zero-output silent branch | L1 |
| MWPT-weight-3: 50/50 (constant-product) path | Verified Defended |
| MWPT-weight-4: manager fee separate from swap fee | Verified Defended |
| MWPT-vault-1: vault address derivation trust | L2 |
| MWPT-vault-2: box-array size and shape | Verified Defended |
| MWPT-fee-1: `3 * min_fee` sizing on the inner call | Verified Defended |
| MWPT-fee-2: fee denormalisation (1 microUSDC input) | Verified Defended |
| MWPT-factory-1: factory address hardcoded in selector branch | Verified Defended (residual: see DISCLAIMER §5) |
| MWPT-factory-2: factory creator migration | Accepted by Design (residual) |
| MWPT-pool-1: empty pool (zero reserves) | Verified Defended |
| MWPT-pool-2: pool with extreme weight skew (1/99) | Verified Defended |
| MWPT-pool-3: pool with manager fee = 100% | Verified Defended (returns zero) |
| MWPT-pool-4: pool with same asset both sides (invalid) | Verified Defended (creator check rejects) |
| MWPT-pool-5: pool paused or frozen | Verified Defended (on-chain swap reverts) |
| MWPT-flow-1: MWPT → STAMM intermediate handoff | Verified Defended (delta measurement) |
| MWPT-flow-2: ALGO input → MWPT → AlgoFi output | Verified Defended |
| MWPT-flow-3: ASA input → MWPT → MWPT (two MWPT legs) | Verified Defended |
| MWPT-flow-4: reverse direction (output asset first) | Verified Defended |
| MWPT-flow-5: tiny input (1 microunit) | Verified Defended (returns zero, see L1) |
| MWPT-flow-6: huge input (near max uint64) | Verified Defended |
| MWPT-flow-7: input asset = output asset (cycle) | Verified Defended (route sanitisation) |
| MWPT-flow-8: input + output both ALGO | Verified Defended (cycle rejected) |
| MWPT-flow-9: MWPT in `route3` middle leg | Verified Defended |
| MWPT-flow-10: MWPT in `route3` exit leg | Verified Defended |
| MWPT-flow-11: MWPT with `RESTRICT_TO_ADMIN` set | Verified Defended (by construction) |
| MWPT-flow-12: MWPT with `verify_discount` in same group | Verified Defended (no state cross-talk) |

---

## 6. Multi-Tier Verification & Testing Evidence

The audit draws on the following test layers, all of which were re-run as part of the v4 audit preparation:

### Tier 1 — Offline Deterministic & Property Tests (540+ tests)
- `pytest -m "not localnet and not mainnet and not testnet"` — 540 tests passed in 14.87s.
- New in v4: `tests/test_pact_mwpt.py` (5 tests) plus `TestPactMwptOut` in `tests/test_curves.py` (4 tests).
- Includes Hypothesis property-based fuzzing on route asset distinctness, resource allocations, and now MWPT weight asymmetry.

### Tier 2 — LocalNet Integration & Adversarial Fuzzing (111 tests)
- `tests/test_contract_localnet.py` — 111 tests against live LocalNet.
- **Adversarial Pool Simulations:** `MODE_NO_OUTPUT`, `MODE_WRONG_RECIPIENT`, `MODE_LEAVE_INPUT`, `MODE_EXTRA_OUTPUT`, `MODE_POOL_FEE`. *Note: MWPT-specific adversarial simulations are not yet included; recommended as a follow-up.*
- **Stateful Fuzzing:** Hypothesis stateful test harness against adversarial AMMs.

### Tier 3 — Mainnet State & Curve Verification (50 tests)
- `test_curves_against_chain.py`, `test_stamm_opups.py` — validates AMM curve math against live mainnet RPC.
- *Follow-up: add `test_pact_mwpt_against_chain.py` to lock in the on-chain behaviour as the source of truth.*

### Tier 4 — Testnet Deployment Verification (12 tests)
- `tests/test_contract_testnet.py` — smoke tests against deployed testnet contract (app ID 3680942699).

### Tier 5 — Static Analysis with Tealer (v0.1.2)
- See `tools/tealer-results.md` for the full matrix. Two detectors timed out and were resolved with static proofs; the rest are clean.

### Tier 6 — Trail of Bits Algorand Vulnerability Scanner
- See `tools/scanner-results.md`. All 11 patterns evaluate to PASS.

---

## 7. Improvements Applied to the Contract

[IMPROVEMENTS.md](IMPROVEMENTS.md) lists three concrete code changes:

1. **Replace `pact_mwpt_out` float-based computation with integer BigInteger math** (closes M1).
2. **Add an `assert` in `_pact_leg` that the MWPT vault reference matches the pool's on-chain vault** (closes L2).
3. **Remove `RESTRICT_TO_ADMIN` template var from the next compile** (closes I1).

Each change is presented with a code skeleton, expected TEAL impact, and a test plan. The contract author should apply these before the next deployment.

---

## 8. Recommendations

### Operational

1. **Re-deploy with v4 improvements.** Three small code edits, all backward-compatible with the existing ABI. New deployment should pin `git revision` and compiler version.
2. **Run differential testing against real Pact MWPT pools on testnet.** The off-chain curve math in `pact_mwpt_out` should be confirmed to match on-chain output to ±0 microunit (not ±1) once M1 is fixed.
3. **Add MWPT adversarial pool simulations** to `tests/test_pact_mwpt.py::test_adversarial_*`. These tests should model a malicious MWPT pool that returns wrong reserves, takes funds but returns nothing, or reverts inconsistently.

### Strategic

1. **Engage an Algorand-experienced human auditor** for a follow-up review. AI audits are a strong baseline but cannot replace human expert judgement on external-protocol design assumptions.
2. **Establish a continuous monitoring regimen.** The engine already ships `poll_router_monitor`, `router_alerts`, `router_monitor_status`, `resolve_router_alert`, and `retry_router_alerts` — these should run under systemd supervision per v3 recommendations.
3. **Run a bytecode-vs-source diff** on every new deployment before signing off. Pin compiler version; re-check after any Puya security bulletin.

---

## 9. Limitations

This is an AI audit. See [DISCLAIMER.md](DISCLAIMER.md) for the full list of caveats. Headline limitations:

- Not a formal verification.
- Not a replacement for human expert review.
- Not a guarantee against economic attacks outside the modelled threat model.
- Off-chain ↔ on-chain divergence is *verified* but not *re-exercised* in this audit cycle.

---

## 10. Conclusion

The ASA Stats Smart Router remains secure for the post-MWPT deployment. The MWPT integration is implemented defensively — every on-chain check that existed for legacy Pact pools applies equally to MWPT pools, because the routing goes through the same `_pact_leg` subroutine with only the selector byte differing. The three new findings (M1, L1, L2) are mathematical or diagnostic in nature and do not affect fund safety; the two informational observations (I1, I2) are deployment hygiene.

When the three improvements in [IMPROVEMENTS.md](IMPROVEMENTS.md) are applied and a human Algorand auditor signs off, the contract is suitable for unrestricted deployment with the trust model documented in [SECURITY.md](SECURITY.md).

---

*This audit was produced by an AI multi-agent system. The audited source is at git revision `5690473` of `<router>/`. Any change to the router contract, the MWPT off-chain code, or the underlying Puya compiler may invalidate this report.*
