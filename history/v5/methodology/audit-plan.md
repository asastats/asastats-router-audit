# Comprehensive Algorand AMM Router Security Audit Plan (v5)

Adapted from the proven real-world methodologies established by **Runtime Verification** (Pact Router & AMM Audits), **Ulam Labs / Vantage Point** (Deflex Order-Router Case Studies), **Trail of Bits** ("Not So Smart Contracts" Algorand Security Suite), and modern AI/agentic security frameworks.

---

## Phase 0 — Scoping & Architectural Trust Modeling
- [x] **Freeze Codebase & Target Revision:** Git revision `ca58dd6` / `04c999a` locked for audit; mainnet application `3688554446` verified byte-for-byte.
- [x] **Define Audit Scope:**
  - *In Scope:* Smart contract (`contracts/router_app.py`), compiled TEAL (`Router.approval.teal`, `Router.clear.teal`), quoter curves (`router/curves.py`), group assembly (`router/legs.py`, `router/contract.py`), dust sweep subsystem (`router/sweep.py`).
  - *Out of Scope:* Internal implementation of external DEX pools (Tinyman, Pact, STAMM, AlgoFi) and host-level key custody infrastructure.
- [x] **Map Trust Boundaries:** Formally delineate caller, widget, admin, quote signer, and external pool trust boundaries.

---

## Phase 1 — Automated Static Analysis & Tooling
- [x] **Tealer Static Analysis:** Execute Crytic Tealer v0.1.2 across all detectors on compiled TEAL bytecode.
- [x] **Dataflow & Coverage Proofs:** Formally prove vacuousness or deliberate design for path-enumerated detectors (`is-updatable`, `is-deletable`, `group-size-check`).
- [x] **Trail of Bits Vulnerability Scanner:** Audit all 11 Algorand vulnerability patterns (rekeying, fee pooling, MBR exhaustion, close-out safety, etc.).
- [x] **Compiler & Toolchain Verification:** Pin PuyaPy v5.9.0 with enabled ARC-4 encoding validation.

---

## Phase 2 — Manual Line-by-Line AVM Review
- [x] **RekeyTo / CloseRemainderTo / AssetCloseTo:** Verify complete group inspection via `_assert_group_is_clean`.
- [x] **GroupSize / Relative Indexing:** Audit dynamic transaction referencing and adjacent payment verification (`payment.group_index + 1 == Txn.group_index`).
- [x] **OnCompletion Handling:** Verify explicit ARC-4 dispatcher handling (NoOp required for methods, DeleteApplication restricted to admin with zero assets/accrued).
- [x] **Inner Transaction Construction:** Confirm all inner transaction fees are hardcoded to `fee=0`, eliminating float drain.
- [x] **MBR Lifecycle:** Verify transient holding open/close lifecycle (`_open_holding` / `_pay_out` / `_close_holding`).
- [x] **Array & Reference Validation:** Verify on-chain asset and application array lookups and creator checks.

---

## Phase 3 — AMM Aggregator & Business-Logic Review
- [x] **Provider Authentication:** Trace pool validation for Tinyman v2 (LogicSig hash), Pact (creator pin), Pact MWPT (creator pin + dynamic vault resolution), STAMM (creator pin), and AlgoFi (compiled whitelist).
- [x] **Multi-Hop Atomicity & Balance Deltas:** Validate that swap outputs are measured strictly via on-chain balance deltas (`_held(asset_out) - before`).
- [x] **Slippage & Floor Enforcement:** Validate backend co-signed quote note authentication (`_signed_floor`) and aggregate group output verification (`_group_paid`).
- [x] **Route Sanitization:** Verify pairwise distinct asset checks preventing circular value bleed.
- [x] **Rounding & Precision:** Audit integer division order across all off-chain curve models.
- [x] **Reentrancy-Analogue Defenses:** Confirm execution phase isolation and group-level non-reentrancy.

---

## Phase 4 — Dynamic Simulation & Adversarial Testing
- [x] **LocalNet Integration Suite:** Execute complete multi-hop routes against local Algorand node environment.
- [x] **Adversarial Pool Simulations:** Test against `contracts/malicious_pool.py` (stealing inputs, zero output, reentrancy attempts).
- [x] **Fuzz Testing:** Property-based fuzzing of group structures, resource allocations, and real opcode budgets.
- [x] **Differential Curve Testing:** Test curve implementations against reference AMM contracts on-chain.

---

## Phase 5 — Multi-Agent Cross-Verification
- [x] **Independent Review Passes:** Execute independent multi-agent security scans synthesizing `analysis1.md`, `analysis2.md`, and `analysis3.md`.
- [x] **Discrepancy Triage:** Re-evaluate all divergences and edge cases against source TEAL.

---

## Phase 6 — Reporting, Findings & Remediation Tracking
- [x] **Classify Findings:** Maintain structured findings catalog (C1, H1, M1–M7, L1–L7, I1–I7) with full verification statuses.
- [x] **Regression Prevention:** Confirm zero regressions from previous audit rounds (v1–v4).

---

## Phase 7 — Post-Deployment & Operational Verification
- [x] **On-Chain Bytecode Verification:** Confirm deployed application `3688554446` matches compiled source.
- [x] **Monitoring & Incident Runbook:** Provide real-time monitoring and key rotation runbooks.
