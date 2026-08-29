# Audit Plan — v4 Smart Router

The v4 audit follows the 7-phase plan adapted from the v3 audit plan (`../router-audit-v3/algorand-amm-router-audit-plan.md`). The plan is derived from the methodologies used by Runtime Verification (Pact Router), Ulam Labs / Vantage Point (Deflex Order-Router), and Trail of Bits' Algorand vulnerability database.

## Phase 0 — Scoping and Preparation
- [x] **Freeze code.** Audit at git revision `5690473` of `<router>/`.
- [x] **Define scope.** In-scope: router contract (approval + clear-state), off-chain quoters (behaviour-equivalence), tests, deployment configuration. Out-of-scope: external pool contracts, frontend, engine. See [`scope.md`](scope.md).
- [x] **Document trust assumptions.** See [`../SECURITY.md`](../SECURITY.md).
- [x] **Gather artifacts:** TEAL, ARC-56, prior audits (v1, v2, v3), STAMM audit, three independent analyses.

## Phase 1 — Automated Static Analysis
- [x] **Tealer** (`crytic/tealer`) sweep at `router/build/tealer/`. Results: see [`../tools/tealer-results.md`](../tools/tealer-results.md).
- [x] **Trail of Bits Algorand vulnerability checklist** (11 patterns). Results: see [`../tools/scanner-results.md`](../tools/scanner-results.md).
- [x] **Compiler version** noted: puyapy 5.9.0. Puya security bulletin history reviewed.
- [x] **Triage every automated finding.** Manual review of all Tealer detector results; timeout detectors resolved with static-vacuousness proofs.

## Phase 2 — Manual Line-by-Line Review (Algorand/AVM-specific checklist)
- [x] **RekeyTo** — verified zero on every outer and inner transaction path.
- [x] **CloseRemainderTo / AssetCloseTo** — verified zero on every outer and inner transaction path.
- [x] **GroupSize / GroupIndex assumptions** — verified all 52 dynamic accesses use `Txn.group_index` arithmetic.
- [x] **OnCompletion coverage** — verified every OnComplete value explicitly handled.
- [x] **Inner-transaction fee handling** — verified `fee=0` on every inner txn; outer route call pools fees via `route_fee`.
- [x] **MBR accounting** — verified no permanent drainage path.
- [x] **Asset / App ID reference validation** — verified against `Txn.Assets`/`Txn.Applications`/`Txn.Accounts` arrays.
- [x] **Box storage** — verified the router uses no direct box storage.
- [x] **Admin / upgrade authority** — verified no UpdateApplication path; delete guarded.

## Phase 3 — Router/AMM Business-Logic Review
- [x] **Path/pool validation** — verified pairwise distinctness, creator pins, whitelist.
- [x] **Atomicity of multi-hop swaps** — verified single atomic group per route.
- [x] **Slippage/minimum-output enforcement** — verified D1–D3 invariants.
- [x] **Price/oracle trust** — verified no oracle usage.
- [x] **Quote deadline/expiry** — verified transaction-level expiry via Algorand consensus.
- [x] **Rounding direction** — verified one Medium drift (M1 in MWPT weighted-pool path).
- [x] **Reentrancy-analogue via inner transactions** — verified L3 (accepted by design).

## Phase 4 — Dynamic / Simulation Testing
- [x] **LocalNet testing** — 111 tests against live LocalNet (Pact MWPT, Tinyman v2, STAMM, AlgoFi).
- [x] **Property-based / fuzz testing** — Hypothesis on route asset distinctness, MWPT weight asymmetry.
- [x] **Adversarial scenario tests** — adversarial pool simulations (MODE_NO_OUTPUT, etc.).

## Phase 5 — AI-Assisted Second Pass
- [x] **AI review** of PuyaPy source + ABI spec against the Phase 2/3 checklist.
- [x] **Cross-check** AI findings vs manual/static findings; divergences noted.
- [x] **Generated MWPT-specific attack vectors** (27 in `attack-vectors/pact/mwpt.md`).

## Phase 6 — Reporting and Remediation
- [x] **Findings classified:** 1 Medium (M1), 2 Low (L1, L2), 2 Informational (I1, I2).
- [x] **Findings files written:** `findings/M1-mwpt-weight-asymmetry-quoting.md`, etc.
- [x] **Improvements documented:** `IMPROVEMENTS.md`.
- [ ] **Fix-review pass** — pending; the contract author applies the three improvements.

## Phase 7 — Post-Deployment
- [ ] **Bug bounty program** — not yet established.
- [x] **Monitoring** — engine ships `poll_router_monitor`, `router_alerts`, etc.
- [x] **Incident response runbook** — `SECURITY.md §3`.

---

## Reference audits and tools cited above

- **v3 audit plan:** `<audit>/router-audit-v3/algorand-amm-router-audit-plan.md`
- **STAMM audit:** `<audit>/STAMM-AI-AUDIT-main/`
- **Three independent analyses:** `<audit>/analysis{1,2,3}.md`
- **Trail of Bits Algorand vulnerability scanner:** `<audit>/router-audit-v3/algorand-vulnerability-scanner/`
- **Tealer static analyzer:** `https://github.com/crytic/tealer`
- **Trail of Bits "Not So Smart Contracts" (Algorand):** `https://github.com/crytic/building-secure-contracts/tree/master/not-so-smart-contracts/algorand`
- **Puya security bulletin 001-arc4-encoding.md** (October 2025)
