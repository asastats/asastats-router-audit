# Audit Coverage — v4 Smart Router

This file documents what was actually checked during the v4 audit cycle: opcode counts, test tier coverage, attack vector statistics, and finding classification.

## Statistics

### On-chain (compiled TEAL at `router/build/tealer/Router.approval.teal`)

- **Lines:** 4,657 (vs. 4,641 in v3 — increase due to MWPT selector branch and supporting asserts)
- **ARC-4 entry points:** 17 (route, route3, convert_and_distribute, set_admin, set_escrow, set_fee, set_quote_signer, set_voucher_signer, set_conversion_pool, verify_discount, pool_budget, opt_in_asset, close_holding, delete_application, batch_update, _signed_floor — baremethods: creation, update (rejected), delete)
- **Subroutines:** ~30 (`_assert_group_is_clean`, `_assert_created_by`, `_assert_listed`, `_assert_input_spent`, `_assert_no_conversion_pool_approval`, `_skim`, `_open_holding`, `_pay_out`, `_held`, `_group_paid`, `_input_amount`, `_swap_leg`, `_tinyman_v2_leg`, `_pact_leg`, `_algofi_leg`, `_stamm_leg`, `_signed_floor`, etc.)
- **Global state keys:** 14 (admin, escrow, fee_bps, conversion_pool, quote_signer, voucher_signer, accrued, total_assets, total_extra_app_pages, _routed_in_group, _opened_in_group, _max_opup, ROUTE_SIGNATURE — wait, the last one is in the Leg struct, not global state)
- **Box storage:** 0 (the router uses no direct box storage; pools read their own boxes)
- **Inner transaction constructions:** 11 (`itxn.Payment`, `itxn.AssetTransfer`, `itxn.ApplicationCall` for Tinyman v2 deposit, Pact CP/MWPT, STAMM opup, AlgoFi, etc.)
- **Assert statements:** ~80 (verified during manual review)
- **Dynamic group accesses:** 52 (verified via Tealer; all use `Txn.group_index` arithmetic)

### Off-chain (Python)

- **Lines:** `router/contracts/router_app.py` 2,359 lines; `router/router/contract.py` 1,279 lines; `router/router/curves.py` ~550 lines; `router/router/venues.py` 1,286 lines; `router/router/legs.py` 842 lines
- **Functions reviewed:** ~80 (every public function in `curves.py`, `venues.py`, `legs.py`, `contract.py`)

## Attack vector statistics

### By source

| Source | Vectors | Notes |
|--------|--------:|-------|
| Inherited from v3 | 134 | Re-verified for v4 |
| New in v4 (MWPT) | 27 | See `attack-vectors/pact/mwpt.md` |
| New in v4 (general) | ~14 | AlgoFi pool list widening, RESTRICT_TO_ADMIN flag, etc. |
| **Total** | **~175** | |

### By verdict

| Verdict | Count | % |
|---------|------:|--:|
| Defended / Verified Defended / Patched (re-verified) | 144 | 82% |
| Not applicable | 8 | 5% |
| By design | 4 | 2% |
| Admin-controlled | 0 | 0% |
| Accepted (residual) | 3 | 2% |
| **Findings** (M/L/I) | **5** | 3% |
| **Total** | **~175** | 100% |

### By category

| Category | Vectors | Findings |
|----------|--------:|---------:|
| Group transactions | 20 | 0 |
| MBR draining | 6 | 0 |
| Reentrancy | 7 | 0 (L3 inherited as accepted-by-design) |
| Resource limits | 8 | 0 |
| Deployment | 6 | 0 (I1 new in v4) |
| Economic | 9 | 0 |
| Path validation | 8 | 0 |
| Conservation | 6 | 0 |
| Slippage | 5 | 0 |
| Multi-hop | 6 | 0 |
| Tinyman v2 | 10 | 0 |
| Pact (CP+SS) | 15 | 0 |
| Pact MWPT | 27 | 1 (M1), 2 (L1, L2) |
| STAMM | 15 | 0 |
| AlgoFi | 10 | 0 |
| AlgoFi list widening | 1 | 1 (I2 new in v4) |

## Test tier coverage

### Tier 1 — Offline deterministic and property tests
- **Tests:** 540+
- **Status:** all pass (offline, no network)
- **Includes:** `tests/test_router_contract.py` (65 focused contract guard tests), `tests/test_curves.py` (~80 curve tests), `tests/test_pact_mwpt.py` (5 new), `tests/test_legs.py` (~30), `tests/test_venues.py` (~40), plus Hypothesis property-based fuzzing on route asset distinctness, resource allocations, and MWPT weight asymmetry.
- **Coverage gaps:** none observed

### Tier 2 — LocalNet integration and adversarial fuzzing
- **Tests:** 111
- **Status:** all pass against live LocalNet
- **Includes:** `tests/test_contract_localnet.py` (live routing across Tinyman v2, Pact, STAMM, AlgoFi stub pools), adversarial pool simulations (`MODE_NO_OUTPUT`, `MODE_WRONG_RECIPIENT`, `MODE_LEAVE_INPUT`, `MODE_EXTRA_OUTPUT`, `MODE_POOL_FEE`), stateful fuzzing.
- **Coverage gaps:** MWPT-specific adversarial simulations are not yet included; recommended as a follow-up.

### Tier 3 — Mainnet state and curve verification
- **Tests:** 50
- **Status:** all pass against live mainnet RPC
- **Includes:** `test_curves_against_chain.py`, `test_stamm_opups.py`.
- **Coverage gaps:** MWPT mainnet-state verification (`test_pact_mwpt_against_chain.py`) is recommended as a follow-up.

### Tier 4 — Testnet deployment verification
- **Tests:** 12
- **Status:** smoke tests against deployed testnet contract (app ID 3680942699)
- **Coverage:** basic routing, fee conversion, voucher discount

### Tier 5 — Static analysis (Tealer)
- **Detectors:** 12
- **Clean:** 9 (can-close-account, can-close-asset, clear-group-size-check, constant-gtxn, self-access, sender-access, group-size-check [covered], is-updatable [covered])
- **False positive by design:** 3 (unprotected-updatable, unprotected-deletable, clear-is-updatable)
- **Timeouts:** 2 (is-updatable, is-deletable, group-size-check — resolved with static-vacuousness proofs)
- See [`../tools/tealer-results.md`](../tools/tealer-results.md) for details.

### Tier 6 — Trail of Bits Algorand vulnerability scanner
- **Patterns:** 11 (rekeying, group-size/index checks, fee pooling, account closing, clear-state, etc.)
- **Status:** all PASS

## Phase-by-phase summary (adapted from v3 plan)

### Phase 0 — Scoping and preparation
- [x] Code frozen at git revision `5690473`
- [x] Scope defined (this file)
- [x] Trust assumptions documented (SECURITY.md)
- [x] Artifacts gathered (TEAL, ARC-56, contract.py, prior audits)

### Phase 1 — Automated static analysis
- [x] Tealer sweep run (results in `../tools/tealer-results.md`)
- [x] Trail of Bits 11-pattern checklist (results in `../tools/scanner-results.md`)
- [x] Compiler version noted (puyapy 5.9.0)
- [x] Findings triaged manually

### Phase 2 — Manual line-by-line review
- [x] RekeyTo, CloseRemainderTo, AssetCloseTo on every entry point — PASS
- [x] GroupSize / GroupIndex assumptions — PASS (all dynamic)
- [x] OnCompletion coverage — PASS
- [x] Inner-transaction fee handling — PASS (`fee=0`)
- [x] MBR accounting — PASS (no permanent drainage)
- [x] Asset / App ID reference validation — PASS
- [x] Box storage — PASS (no direct usage)
- [x] Admin / upgrade authority — PASS (no update path)

### Phase 3 — Router/AMM business-logic review
- [x] Path/pool validation — PASS
- [x] Atomicity of multi-hop swaps — PASS
- [x] Slippage enforcement — PASS (D1–D3 invariants)
- [x] Price/oracle trust — PASS (no oracle usage)
- [x] Quote deadline/expiry — PASS (transaction-level expiry)
- [x] Rounding direction — PASS (one Medium drift: M1)
- [x] Reentrancy-analogue — PASS (L3 accepted by design)

### Phase 4 — Dynamic / simulation testing
- [x] Test suite executed (540+ offline, 111 LocalNet, 50 mainnet-state, 12 testnet)
- [x] Property-based fuzzing — PASS
- [x] Adversarial scenario tests — PASS

### Phase 5 — AI-assisted second pass
- [x] AI review of PuyaPy source + ABI spec
- [x] Cross-check AI findings vs manual/static findings
- [x] Generated 27 MWPT-specific attack vectors

### Phase 6 — Reporting and remediation
- [x] All findings classified
- [x] Findings files written (`../findings/`)
- [x] Improvements documented (`../IMPROVEMENTS.md`)
- [ ] Fix-review pass (not yet done — pending contract author applying improvements)

### Phase 7 — Post-deployment
- [ ] Bug bounty program (not yet established)
- [x] Monitoring (`engine/core/management/commands/poll_router_monitor`, etc.)
- [x] Incident response runbook (SECURITY.md §3)
