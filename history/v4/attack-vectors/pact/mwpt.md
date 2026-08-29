# Pact MWPT Attack Vectors (v4 — New)

The Pact **MWPT (Managed Weighted Pool)** integration was added between v3 and v4. This file catalogs 27 attack vectors specific to the MWPT surface. None produced a critical or high-severity finding; one medium (M1), two low (L1, L2), and the rest verified defended.

## Why MWPT needs its own vector list

MWPT pools differ from legacy Pact constant-product and stableswap pools in three ways:

1. **Weighted reserves.** `weight_in` and `weight_out` are not necessarily equal. The swap output formula is `reserve_out * (1 - (reserve_in / (reserve_in + effective_in))^(weight_in / weight_out))`, which is *not* a constant-product swap when weights are asymmetric.
2. **Vault reference.** MWPT pools read reserves from a separate "vault" application via `app_global_get_ex`. The vault app ID is part of the pool's state, not derived from the pool's address.
3. **Manager fee.** A separate fee (`manager_fee_bps`) is taken on top of the swap fee, reducing the output further.

Each of these surfaces introduces a separate set of attack vectors.

## Vector list

### Weights and curve math (`MWPT-WEIGHT-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-WEIGHT-01 | Weight-asymmetry rounding direction (float-based quoter) | M1 | `router/curves.py:234-236` |
| MWPT-WEIGHT-02 | Zero-output silent branch | L1 | `router/curves.py:228-229` |
| MWPT-WEIGHT-03 | 50/50 (constant-product) path | Verified Defended | `router/curves.py:231-232` |
| MWPT-WEIGHT-04 | Manager fee separate from swap fee | Verified Defended | `router/curves.py:238-242` |
| MWPT-WEIGHT-05 | Weight = 0 (invalid pool) | Verified Defended | `_assert_created_by` rejects unrecognised pool |
| MWPT-WEIGHT-06 | Weight sum ≠ 10000 (invalid pool) | Verified Defended | `_assert_created_by` rejects unrecognised pool |
| MWPT-WEIGHT-07 | Extreme weight skew (1/99) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-WEIGHT-08 | Weight asymmetry + tiny input (1 microunit) | Verified Defended | Floor protects user |
| MWPT-WEIGHT-09 | Weight asymmetry + huge input (near max uint64) | Verified Defended | Test passes |

### Vault and box references (`MWPT-VAULT-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-VAULT-01 | Vault address derivation trust | L2 | `router/legs.py:259-264` |
| MWPT-VAULT-02 | Vault reference is replaced by malicious vault app ID | Verified Defended (residual) | Off-chain only; pool creator check still authenticates pool |
| MWPT-VAULT-03 | Vault app deleted but referenced | Verified Defended | On-chain `app_global_get_ex` fails; route reverts |
| MWPT-VAULT-04 | Box-array size and shape | Verified Defended | `router/legs.py:262-263` |
| MWPT-VAULT-05 | Box-read returns wrong reserve data | Verified Defended | Balance delta measurement ignores reserve data |
| MWPT-VAULT-06 | Vault app is same as pool app (self-reference) | Verified Defended | Pool creator check still authenticates |
| MWPT-VAULT-07 | Vault reference missing entirely | Verified Defended | `foreign_apps` array empty; `box_read` reverts |

### Fee sizing (`MWPT-FEE-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-FEE-01 | `3 * min_fee` sizing on the inner call | Verified Defended | `router/legs.py:281` |
| MWPT-FEE-02 | Fee denormalisation (1 microUSDC input) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-FEE-03 | Manager fee + swap fee compound | Verified Defended | `router/curves.py:238-242` |
| MWPT-FEE-04 | Fee = 100% | Verified Defended | Returns zero; floor rejects |
| MWPT-FEE-05 | Fee = 0 (free swap) | Verified Defended | Test in `tests/test_pact_mwpt.py` |

### Factory and pool authentication (`MWPT-FACTORY-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-FACTORY-01 | Factory address hardcoded in selector branch | Verified Defended (residual) | `router/contracts/router_app.py:1489-1491` |
| MWPT-FACTORY-02 | Factory creator migration | Accepted by Design (residual) | See DISCLAIMER.md §5.4 |
| MWPT-FACTORY-03 | Pool deployed by wrong factory (not the official one) | Verified Defended | `_assert_created_by` rejects |
| MWPT-FACTORY-04 | Pool's global state lies about its creator | Verified Defended | On-chain `AppParamsGet.app_creator` is authoritative |

### Pool state and dynamics (`MWPT-POOL-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-POOL-01 | Empty pool (zero reserves) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-POOL-02 | Pool with extreme weight skew (1/99) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-POOL-03 | Pool with manager fee = 100% | Verified Defended (returns zero) | `router/curves.py:240` |
| MWPT-POOL-04 | Pool with same asset both sides (invalid) | Verified Defended | Creator check rejects |
| MWPT-POOL-05 | Pool paused or frozen | Verified Defended | On-chain swap reverts |
| MWPT-POOL-06 | Pool reserves manipulable within group | Verified Defended | Algorand has no public mempool |
| MWPT-POOL-07 | Pool reserves change between quote and execution | Verified Defended | Floor protects user |

### Flow composition (`MWPT-FLOW-*`)

| ID | Title | Verdict | Code reference |
|----|-------|---------|----------------|
| MWPT-FLOW-01 | MWPT → STAMM intermediate handoff | Verified Defended | Delta measurement |
| MWPT-FLOW-02 | ALGO input → MWPT → AlgoFi output | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-FLOW-03 | ASA input → MWPT → MWPT (two MWPT legs) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-FLOW-04 | Reverse direction (output asset first) | Verified Defended | Route sanitisation |
| MWPT-FLOW-05 | Tiny input (1 microunit) | Verified Defended (returns zero) | `router/curves.py:228-229` |
| MWPT-FLOW-06 | Huge input (near max uint64) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-FLOW-07 | Input asset = output asset (cycle) | Verified Defended | Route sanitisation |
| MWPT-FLOW-08 | Input + output both ALGO | Verified Defended | Cycle rejected |
| MWPT-FLOW-09 | MWPT in `route3` middle leg | Verified Defended | `route3` parity test |
| MWPT-FLOW-10 | MWPT in `route3` exit leg | Verified Defended | `route3` parity test |
| MWPT-FLOW-11 | MWPT with `RESTRICT_TO_ADMIN` set | Verified Defended | By construction |
| MWPT-FLOW-12 | MWPT with `verify_discount` in same group | Verified Defended | No state cross-talk |
| MWPT-FLOW-13 | MWPT in 4-hop route (route + route3 combined) | Verified Defended | Test in `tests/test_pact_mwpt.py` |
| MWPT-FLOW-14 | MWPT pool with paused liquidity | Verified Defended | On-chain swap reverts |

---

## Vector resolution summary

| Verdict | Count |
|---------|------:|
| **Critical** | 0 |
| **High** | 0 |
| **Medium (finding)** | 1 (M1) |
| **Low (finding)** | 2 (L1, L2) |
| **Verified Defended** | 21 |
| **Accepted (residual)** | 2 (MWPT-FACTORY-02, MWPT-VAULT-02) |
| **Total** | **27** |

## Detailed write-ups

Each vector's specific details are recorded in the corresponding finding file (if the vector produced a finding) or in the test that exercises it (if the vector is verified defended). See:

- [`../../findings/M1-mwpt-weight-asymmetry-quoting.md`](../../findings/M1-mwpt-weight-asymmetry-quoting.md) — MWPT-WEIGHT-01
- [`../../findings/L1-mwpt-zero-output-branch.md`](../../findings/L1-mwpt-zero-output-branch.md) — MWPT-WEIGHT-02
- [`../../findings/L2-mwpt-vault-implicit.md`](../../findings/L2-mwpt-vault-implicit.md) — MWPT-VAULT-01

For vectors that are Verified Defended, the defence is in either:

- `_pact_leg` selector branch (`router/contracts/router_app.py:1486-1523`).
- The on-chain pool creator check (`_assert_created_by`).
- The route sanitisation (pairwise distinct asset checks).
- The balance-delta measurement (`_held(asset_out) - before`).

For vectors that are Accepted (residual):

- MWPT-FACTORY-02: see [DISCLAIMER.md §5.4](../../DISCLAIMER.md).
- MWPT-VAULT-02: see [findings/L2-mwpt-vault-implicit.md](../../findings/L2-mwpt-vault-implicit.md).
