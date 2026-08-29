# Comprehensive Security Audit Report — Smart Router (v5)

**Target Contract:** `router/contracts/router_app.py` (ASA Stats Smart Router)  
**Compiler:** PuyaPy v5.9.0 (Algorand Python → TEAL v11, **4,681 lines** in compiled approval program)  
**Swept program digest:** `1761d970954e4d7e` — first 16 hex of SHA-256 of the **swept** `Router.approval.teal`, which is compiled with `RESTRICT_TO_ADMIN = 0` for analysis. It is **not** the deployed program's hash: mainnet `3688554446` has approval bytecode SHA-256 `15a465c8494479932cc28a3580062af1db325a4c8570699c17e421970cbe6beb` and approval TEAL SHA-256 `351e5a3dd0e754aca9f86b03061cf72bda233287ced25314ad71f4f4969abb31` (4,681 TEAL lines)  
**Target Deployments:** Mainnet App ID **3688554446** | Testnet App ID **770123816**  
**Audit Framework:** Multi-agent AI security system synthesizing Runtime Verification methodologies, Ulam Labs / Vantage Point case studies, Trail of Bits Algorand security guidelines, the LiquiHog STAMM AMM Audit (121 attack vectors), and independent meta-analyses (`analysis1.md`, `analysis2.md`, `analysis3.md`).  
**Audit Date:** 2026-08-29  

---

## 1. Executive Summary & Audit Scorecard

A full-scope security audit was conducted on the ASA Stats Smart Router codebase at git revision `ca58dd6` / `04c999a` following the deployment of mainnet application **3688554446**. The v5 audit evaluates the production-ready router application, the on-chain dynamic vault resolution for Pact MWPT pools, the liquid staking rate oracle pricing subsystem, the complete dust sweep engine, and the 934-test verification suite.

### Headline Verdict
> **NO CRITICAL OR HIGH SEVERITY VULNERABILITY WAS FOUND IN THE CONTRACT.**
> All historical findings from v1 through v4 (C1, H1, M1–M6, L1–L5, I1–I7) are verified as patched, structurally defended, or proven safe, and each mitigation was read in `contracts/router_app.py` rather than taken from the previous report.
>
> **This is not a clearance for unrestricted deployment.** Mainnet `3688554446` is compiled with `RESTRICT_TO_ADMIN` and stays that way until an Algorand-experienced *human* has reviewed this work. Every audit in this series, this one included, was produced by an AI system — and this one initially recorded the restriction as already removed. See [CORRECTIONS.md](CORRECTIONS.md).
>
> **One v5 finding was wrong.** `I2` was issued VERIFIED SAFE; the sweep's unpriced-forfeit branch had no value test. Fixed in `1c128f2`.

### Findings Summary Matrix

| Category | Total | Open | Remediated / Verified Defended | Accepted by Design |
|----------|:-----:|:----:|:------------------------------:|:-------------------:|
| **Critical (C)** | 1 | 0 | 1 (`C1`) | 0 |
| **High (H)** | 1 | 0 | 1 (`H1`) | 0 |
| **Medium (M)** | 7 | 0 | 7 (`M1`–`M7`) | 0 |
| **Low (L)** | 7 | 0 | 7 (`L1`–`L7`) | 0 |
| **Informational (I)** | 7 | 0 | 7 (`I1`–`I7`), one of them (`I2`) only after this report was corrected | 0 |
| **Total** | **23** | **0** | **23** | **0** |

---

## 2. Protocol Architecture & Multi-Hop Execution

The ASA Stats Smart Router enables optimal atomic execution of multi-hop asset swaps across heterogeneous Algorand decentralized exchanges:
- **Tinyman v2** (Constant-product with logic signature pool accounts)
- **Pact** (Constant-product, Stableswap, and Managed Weighted Pools / MWPT)
- **STAMM** (Stratified multi-tier constant-product AMM)
- **AlgoFi** (Defunct constant-product pools with active liquidity)

```
                            [ User Wallet / Caller ]
                                       │
                         Funds (T_in)  │  Signed Quote Note
                                       ▼
                     ┌────────────────────────────────────┐
                     │    ASA Stats Smart Router App      │ ◄── [ Admin ]
                     │        (App ID: 3688554446)        │     (set_fee, set_conversion_pool,
                     │                                    │      set_quote_signer, etc.)
                     │  - Zero-fee inner transactions     │
                     │  - Holding delta output accounting │
                     │  - On-chain provider validation    │
                     └─────────────────┬──────────────────┘
                                       │
        ┌──────────────┬───────────────┼───────────────┬──────────────┐
        ▼              ▼               ▼               ▼              ▼
   ┌─────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐  ┌───────────┐
   │ Tinyman │   │ Pact Std  │   │ Pact MWPT │   │   STAMM   │  │  AlgoFi   │
   │   v2    │   │ & Stable  │   │ Weighted  │   │Multi-Tier │  │ Whitelist │
   │LogicSig │   │  Creator  │   │Vault Exch │   │  Creator  │  │ 23 Pools  │
   │ Derived │   │  Pinned   │   │  Pinned   │   │  Pinned   │  │  Pinned   │
   └─────────┘   └───────────┘   └───────────┘   └───────────┘  └───────────┘
```

### Key Architectural Invariants

1. **Balance-Delta Output Measurement:** The router never relies on pool-logged return values or off-chain guesses. It measures `before = self._held(asset_out)` and `after = self._held(asset_out)` directly via `asset_holding_get` opcodes. The exact realised delta is forwarded to the next leg.
2. **Zero-Fee Inner Transactions:** Every inner transaction (`itxn`) submitted by the router specifies `fee = 0`. The entire transaction group fee is pooled and covered by the outer caller transaction. This prevents operational float drainage and eliminates ALGO balance distortions during multi-hop ALGO routes.
3. **Transient Inventory Lifecycle:** The router carries no permanent ASA inventory. Holdings are opened (`_open_holding`) and closed (`_pay_out` / `_close_holding`) within the exact transaction group that uses them, returning the 0.1 ALGO Minimum Balance Requirement (MBR) to the contract immediately.
4. **Backend Co-Signed Slippage Floor:** The slippage floor is not an argument passed by the caller or widget. It is authenticated via the transaction note of a co-signed `pool_budget()` call from the designated `quote_signer`.

---

## 3. Comprehensive Findings & Verification Registry

### Critical Findings

#### `C1` — Permissionless `convert_and_distribute` Pool Drain
- **Severity:** Critical
- **Location:** `contracts/router_app.py:convert_and_distribute`
- **Description:** In early revisions, `convert_and_distribute` was permissionless and accepted an unauthenticated caller-supplied `Leg`, allowing an attacker to drain accumulated platform fees into an attacker-controlled pool.
- **Verification Status:** **REMEDIATED.** Method is strictly restricted to `assert Txn.sender == self.admin`, the pool parameter is eliminated and read from state (`self.conversion_pool`), and `_assert_no_conversion_pool_approval` prevents same-group manipulation.

### High Findings

#### `H1` — Widget-Controlled Floor Slippage Extraction
- **Severity:** High
- **Location:** `contracts/router_app.py:route` / `route3`
- **Description:** If a frontend or widget passes `minimum_received = 0`, an attacker or rogue client could execute trades through pools at unfavorable prices, extracting value.
- **Verification Status:** **REMEDIATED.** Removed `minimum_received` parameter from public route entry points. All floors are enforced via `_signed_floor` from the co-signed `quote_signer` transaction note.

### Medium Findings

#### `M1` — Route Path Sanitization (Duplicate / Cycling Assets)
- **Severity:** Medium
- **Location:** `contracts/router_app.py:route` / `route3`
- **Description:** Routes containing cycles (e.g., A → B → A) waste fees and could distort intermediary accounting.
- **Verification Status:** **REMEDIATED.** On-chain assertions enforce that all route assets (`asset_in`, intermediates, `asset_out`) are pairwise distinct.

#### `M2` — Funding Transaction Adjacency
- **Severity:** Medium
- **Location:** `contracts/router_app.py:_input_amount`
- **Description:** Without strict adjacency checks, an attacker could separate the funding payment from the route call in a group, complicating group validation.
- **Verification Status:** **REMEDIATED.** Strict assert `payment.group_index + 1 == Txn.group_index` enforced on all route calls.

#### `M3` — Pre-Held Input Asset Conservation
- **Severity:** Medium
- **Location:** `contracts/router_app.py:_assert_input_spent`
- **Description:** If the router already held a balance in an asset before a route, an external pool that consumed only part of the caller's input could leave residual caller funds stranded in the router.
- **Verification Status:** **REMEDIATED.** `_assert_input_spent` records `input_before` and strictly asserts `self._held(asset_in) == input_before - amount_in`.

#### `M4` — Provider Pool Authentication
- **Severity:** Medium
- **Location:** `contracts/router_app.py:_swap_leg`
- **Description:** External pool application IDs must be strictly verified to prevent routing into attacker-deployed fake pools.
- **Verification Status:** **REMEDIATED.**
  - Tinyman v2: Derived via SHA512/256 logic signature template.
  - Pact: Verified against pinned `PACT_POOL_CREATORS`.
  - Pact MWPT: Verified against MWPT factory creator + dynamic vault resolution.
  - STAMM: Verified against pinned `STAMM_POOL_CREATORS`.
  - AlgoFi: Verified against compiled `ALGOFI_POOLS` whitelist.

#### `M5` — Unbounded STAMM Opup Requests
- **Severity:** Medium
- **Location:** `contracts/router_app.py:_swap_leg`
- **Description:** Unbounded `opups` argument could allow callers to trigger excessive inner transactions.
- **Verification Status:** **REMEDIATED.** Enforced `assert leg.opups.as_uint64() <= MAX_STAMM_OPUPS` (where `MAX_STAMM_OPUPS = 8`) and `assert leg.opups.as_uint64() == 0` for non-STAMM providers.

#### `M6` — Same-Group Conversion Pool Approval Separation
- **Severity:** Medium
- **Location:** `contracts/router_app.py:_assert_no_conversion_pool_approval`
- **Description:** Submitting `set_conversion_pool` and `convert_and_distribute` in the same atomic group could allow atomic pool reassignment.
- **Verification Status:** **REMEDIATED.** `_assert_no_conversion_pool_approval` scans the outer transaction group and asserts no `set_conversion_pool` call is present.

#### `M7` — Pact MWPT Weight Asymmetry Quoting Precision
- **Severity:** Medium
- **Location:** `router/curves.py:pact_mwpt_out`
- **Description:** Off-chain float math on weighted pools could drift by 1 microunit from on-chain integer math.
- **Verification Status:** **REMEDIATED.** Refactored off-chain curve math to high-precision calculation with strict bound verification matching on-chain behavior.

### Low & Informational Findings

| ID | Title | Status | Resolution / Verification |
|----|-------|--------|---------------------------|
| `L1` | Delete Application Asset Check | **Remediated** | `delete_application` verifies zero open asset holdings and zero accrued fees. |
| `L2` | Zero Address Rejection in Setters | **Remediated** | `set_admin`, `set_escrow`, `set_quote_signer`, `set_voucher_signer` reject zero address. |
| `L3` | Reentrancy Guarding via AVM Structure | **Verified** | Group hygiene + balance deltas + caller validation eliminate reentrancy surfaces. |
| `L4` | Conversion Floor Zero Exemption Bounding | **Remediated** | `minimum_out == 0` only allowed when `batch == accrued && batch < MIN_CONVERSION_BATCH`. |
| `L5` | Voucher Key Rotation | **Verified** | Admin can rotate or revoke voucher key at any time via `set_voucher_signer`. |
| `L6` | MWPT Zero Output Branch Handling | **Verified** | Verified that empty/zero swaps fail closed and revert cleanly. |
| `L7` | On-Chain MWPT Dynamic Vault Assertion | **Remediated** | Router reads `vault` global state key from pool and dispatches deposit to vault address. |
| `I1` | Liquid Staking Pricing Rate Oracle Boundary | **Verified** | **Real pools first**; the protocol rate answers only where the cache holds no reserve pool. Quoter-side only — the contract reads no price. Rewritten 2026-08-29. |
| `I2` | Dust Sweep Classification Policy | **Gap found, remediated `1c128f2`** | Issued VERIFIED SAFE in error. `closeable` had no value test on the unpriced branch: any asset the router failed to price, with a creator, was forfeited in full on a tick. Now vetoed by `priced_by_evaluation`. Router `tests/test_sweep.py` collects 111 at the audited revision, not the 982 first reported. |
| `I3` | Dead Code Removal in Non-STAMM Opup Branch | **Remediated** | Dead code removed; opups strictly disallowed for non-STAMM. |
| `I4` | Dynamic Minimum Balance Handling | **Verified** | Dynamic balance checks ensure the contract never falls below MBR. |
| `I5` | Unbound Admin Batch Repetition | **Verified** | Documented as acceptable administrative operational capability. |
| `I6` | STAMM Multi-Tier Execution ABI Alignment | **Verified** | Bytecode matches deployed STAMM ABI specifications. |
| `I7` | AlgoFi Defunct Pool Whitelist Curation | **Verified** | 23 curated pools pinned at compile time. |

---

## 4. Algorand Platform & AVM Hardening Verification

The codebase was audited against the Trail of Bits "Not So Smart Contracts" 11-pattern Algorand security framework:

```
+-----------------------------------------------------------------------------------------+
|                    TRAIL OF BITS ALGORAND SECURITY COMPLIANCE (v5)                     |
+----+--------------------------------+--------+------------------------------------------+
| #  | Vulnerability Pattern          | Result | Contract Defense & Location              |
+----+--------------------------------+--------+------------------------------------------+
| 1  | Unchecked RekeyTo              | PASS   | _assert_group_is_clean scans all txns    |
| 2  | Unchecked CloseRemainderTo     | PASS   | _assert_group_is_clean scans all txns    |
| 3  | Unchecked AssetCloseTo         | PASS   | _assert_group_is_clean scans all txns    |
| 4  | Missing Group Size Checks      | PASS   | GroupSize scanned; dynamic bounds check  |
| 5  | Missing Group Index Checks     | PASS   | Strict relative & adjacent index checks  |
| 6  | Missing Type Validation        | PASS   | Strict ARC-4 typing & gtxn type asserts  |
| 7  | Fee Pooling Exploitation       | PASS   | Inner txns fee=0; caller pools fee       |
| 8  | Missing Field Validation       | PASS   | Input assets, senders, receivers checked |
| 9  | Broken Access Control          | PASS   | Admin asserts on all privileged methods  |
| 10 | Unsafe ClearState Program      | PASS   | Minimal pushint 1; return (no state lock)|
| 11 | Unchecked Asset Configuration  | PASS   | On-chain creator pins & derivation       |
+----+--------------------------------+--------+------------------------------------------+
```

---

## 5. Formal Invariant Verification Matrix

The smart router satisfies the complete suite of multi-hop formal invariants:

| Invariant | Formal Statement | Enforcement Mechanism | Status |
|-----------|------------------|-----------------------|:------:|
| **A1. Clean Group** | $\forall i \in [0, \text{GroupSize}), \text{RekeyTo}_i = \text{CloseTo}_i = 0$ | `_assert_group_is_clean` | **PASS** |
| **A2. Final Auth** | $\text{Txn}_{\text{last}} = \text{QuoteAuth}(\text{quote\_signer})$ | `_signed_floor` | **PASS** |
| **B1. No Mid-Hop Spend** | $\text{Fee}_{\text{inner}} = 0 \implies \Delta \text{Balance} = \text{SwapOutput}$ | Construction (`fee=0`) | **PASS** |
| **B2. Delta Forwarding** | $\text{Input}_{k+1} = \Delta \text{Held}_k - \text{Skim}$ | Balance delta wiring | **PASS** |
| **B3. Router Measurement** | $\text{Output} = \text{Held}_{\text{after}} - \text{Held}_{\text{before}}$ | Direct `_held` calls | **PASS** |
| **C1. ALGO Skim Conservation** | $\Delta \text{ALGO}_{\text{net}} = \text{Skim}_{\text{fee}}$ | `_skim` & `accrued` accounting | **PASS** |
| **C2. Transient Inventory** | $\text{Holdings}_{\text{surviving}} = \text{Holdings}_{\text{initial}}$ | Same-group close-outs | **PASS** |
| **C3. Float Recovery** | $\text{MBR}_{\text{returned}} = 0.1 \text{ ALGO} \times N_{\text{optins}}$ | Same-group opt-in/close | **PASS** |
| **D1. Floor Satisfaction** | $\sum \text{Output}_{\text{routes}} \ge \text{Floor}_{\text{signed}}$ | `_group_paid` assertion | **PASS** |

---

## 6. Static Analysis & Dynamic Test Suite Results

### Tealer Static Analysis Sweep
- **Tool:** Crytic Tealer v0.1.2
- **Approval Program:** 4,681 TEAL lines
- **Swept TEAL digest:** `1761d970954e4d7e` — first 16 hex of SHA-256 of the **swept** `Router.approval.teal`, which is compiled with `RESTRICT_TO_ADMIN = 0` for analysis. It is **not** the deployed program's hash: mainnet `3688554446` has approval bytecode SHA-256 `15a465c8494479932cc28a3580062af1db325a4c8570699c17e421970cbe6beb` and approval TEAL SHA-256 `351e5a3dd0e754aca9f86b03061cf72bda233287ced25314ad71f4f4969abb31`
- **Results:**
  - `can-close-account`: 0 findings (Clean)
  - `can-close-asset`: 0 findings (Clean)
  - `constant-gtxn`: 0 findings (Clean)
  - `self-access`: 0 findings (Clean)
  - `sender-access`: 0 findings (Clean)
  - `unprotected-updatable`: 0 executable paths (ARC-4 dispatcher contains 0 update routes; confirmed false positive)
  - `unprotected-deletable`: Deliberate admin-guarded `delete_application` bare method
  - `group-size-check`, `is-updatable`, `is-deletable`: Formally verified via dataflow proof in `detect-*.covered`

### Dynamic Test Suite
- **Total Tests:** 934 passed, 2 skipped
- **Execution Time:** ~67 seconds
- **Suites Included:**
  - Unit tests for all mathematical curves and stableswap invariants
  - Integration tests against LocalNet and simulated AMM networks
  - Adversarial tests with `contracts/malicious_pool.py`
  - Real opcode fuzzing across STAMM and multi-hop paths
  - Complete dust sweep portfolio lifecycle tests (323 tests across the four suites (router 111, engine 61, widget jest 121, browser 30) as of the audited revision)

---

## 7. Conclusion & Sign-Off

The ASA Stats Smart Router (App ID `3688554446`) has undergone a multi-layered
security evaluation. No critical or high-severity vulnerability was found in the
contract, and every mitigation claimed above was read in the source rather than
carried over from the previous report.

**Final Status: SOUND, AND DEPLOYED RESTRICTED — WHICH IS WHERE IT SHOULD STAY
FOR NOW.**

`3688554446` is compiled with `RESTRICT_TO_ADMIN`; `route` and `route3` refuse
every caller but the admin. Two conditions were once listed as gating removal
of that restriction, and one has genuinely closed — no provider's pool
application is caller-chosen any more (`M4`). The other has not moved:

> **This audit series is AI-produced. No Algorand-experienced human has
> reviewed it.**

That is not a formality. This report initially recorded the restriction as
already removed and recommended unrestricted use on that basis; v4 made the
same recommendation citing a testnet application id as if it were mainnet. A
further AI pass does not discharge the condition — a human reviewer does. Until
then the contract holds a caller's whole input mid-route, and only the admin's
funds are exposed to that.

See [CORRECTIONS.md](CORRECTIONS.md) for everything amended on 2026-08-29.
