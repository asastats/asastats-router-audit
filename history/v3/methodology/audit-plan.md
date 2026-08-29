# Smart Router Security Audit Plan (v3)

## 1. Overview and Methodology

This audit plan integrates real-world methodologies from leading smart contract security firms (Runtime Verification's Pact Router formal audit, Ulam Labs' Deflex Order-Router audit, Trail of Bits' Algorand Vulnerability database) with state-of-the-art multi-agent AI verification techniques.

```
+-------------------------------------------------------------------------------+
|                        8-PHASE AUDIT METHODOLOGY                              |
+-------------------------------------------------------------------------------+
|  Phase 0: Scope, Threat Modeling & Trust Boundaries                           |
|  Phase 1: Automated Static Analysis (Tealer + Trail of Bits Scanner)          |
|  Phase 2: Manual Line-by-Line Algorand / AVM Security Review                  |
|  Phase 3: Cross-AMM Composability & Business Logic Analysis                   |
|  Phase 4: Mathematical Invariant Modeling & Semi-Formal Proofs                |
|  Phase 5: Dynamic Testing, LocalNet Simulation & Hypothesis Fuzzing          |
|  Phase 6: Multi-Agent AI Verification & Cross-Analysis Synthesis              |
|  Phase 7: Reporting, Remediation Verification & Code Improvement              |
+-------------------------------------------------------------------------------+
```

---

## 2. Phase-by-Phase Execution

### Phase 0: Scoping & Trust Boundary Establishment
- **Code Freeze:** Source pinned at the current worktree revision of `router/contracts/router_app.py`.
- **Trust Hierarchy Definition:**
  - *Caller / User:* Untrusted. May submit arbitrary parameters, rekey transactions, or crafted groups.
  - *Admin:* Privileged operator. Trusted for deployment, treasury setup, and signer rotation; untrusted for public user trade diversion.
  - *Quote Signer:* Backend microservice key. Trusted to enforce output floors; cannot administer contract or move user funds.
  - *Voucher Signer:* Web backend key. Trusted for fee discounts; cannot touch funds or bypass minimum outputs.
  - *External AMMs:* Untrusted / black box. Must be authenticated via creator/whitelist/derivation before invocation; output measured exclusively via balance deltas.

### Phase 1: Automated Static Analysis
- **Tealer 0.1.2 Suite:** Execute static CFG detectors on compiled TEAL:
  - `unprotected-updatable`, `unprotected-deletable`
  - `can-close-account`, `can-close-asset`
  - `constant-gtxn`, `self-access`, `sender-access`
  - `group-size-check`, `is-updatable`, `is-deletable` (via covered proofs to prevent memory exhaustion)
  - Clear state detectors (`clear-is-updatable`, `clear-missing-fee-check`, `clear-rekey-to`, `clear-group-size-check`)
- **Trail of Bits 11-Pattern Scanner:** Automated and manual checks against the 11 Algorand vulnerability patterns.

### Phase 2: Manual Algorand / AVM Security Review
- **Rekey & Close-Out Hygiene:** Line-by-line verification of `_assert_group_is_clean()` across all entry points.
- **Inner Transaction Fee Draining:** Verification that all inner transactions set `fee=0` and rely on caller fee pooling.
- **MBR & Opt-In Griefing:** Verification of temporary holding allocation and deallocation lifecycle (`_open_holding`, `_pay_out`, `opt_in_asset`).
- **OnComplete Handling:** Explicit validation of `NoOp`, `DeleteApplication`, and absence of `UpdateApplication`.
- **Foreign Array Validation:** Validation of `apps`, `assets`, `accounts` references in inner calls.

### Phase 3: Cross-AMM Business Logic Review
- **Pool Authentication:**
  - Tinyman v2: Logic signature template hash derivation.
  - Pact: Creator address matching against pinned creators.
  - STAMM: Creator address matching against pinned creator.
  - AlgoFi: Whitelist check against curated liquid pool list.
- **Slippage & Output Floor:**
  - Validation of `_signed_floor()` note layout, caller binding, output asset binding, per-position input binding, and asserting route index.
  - Validation of `_group_paid()` multi-split aggregation via ARC-4 return logs.
- **Path Sanitization:** Assertions against cycles, self-swaps, and repeated intermediate assets.
- **Accrued Fee Conversion:** Admin-only restriction, separation from pool approval, batch ceilings, and dust-only zero floor.

### Phase 4: Mathematical Invariant Modeling & Semi-Formal Proofs
- Formulation of multi-hop conservation of value equations.
- Proof of balance neutrality (router retains 0 net user assets).
- Slippage bounding theorem: realized output $\ge$ quoted floor.
- Arithmetic safety and overflow prevention in 64-bit AVM math.

### Phase 5: Dynamic Testing & Fuzzing
- **Unit & Contract Guard Tests:** `test_router_contract.py` (65 test cases).
- **Offline & Simulation Tests:** `pytest -m "not localnet and not mainnet and not testnet"` (540 test cases).
- **Hypothesis Property-Based Fuzzing:** Testing input bounds, STAMM opup ceilings, and resource allocation.
- **LocalNet Integration Tests:** Multi-hop live execution against mock and simulated AMM pools.

### Phase 6: Multi-Agent AI Verification & Independent Analyses Synthesis
- Comprehensive cross-evaluation against `analysis1.md`, `analysis2.md`, `analysis3.md`, and the LiquiHog STAMM AI Audit.
- Triage of divergences and verification of edge cases.

### Phase 7: Reporting, Remediation & Contract Improvement
- Synthesis of all findings into a structured, navigable audit repository.
- Direct source code cleanup (removal of dead code / unreachable budget logic).
- Bytecode verification and line count validation.
