# Synthesis of Independent Analyses and STAMM Audit Comparison

## 1. Executive Context

To ensure this security audit reaches institutional standards, the evaluation incorporates:
1. **The LiquiHog STAMM AI Audit:** Multi-agent system audit analyzing 121 attack vectors on a stratified constant-product AMM protocol.
2. **Analysis 1 (`analysis1.md`):** Deep review of AVM resource griefing, protocol composability, and asset accounting nuances.
3. **Analysis 2 (`analysis2.md`):** Aggregator-specific threat modeling, formal multi-hop invariant verification (KAVM/Hoare logic), and Trail of Bits hardening.
4. **Analysis 3 (`analysis3.md`):** Advanced cross-protocol failure modes, state desynchronization, reentrancy-like group interactions, and adversarial fuzzing.

---

## 2. Fundamental Architectural Shift: AMM Pool vs. Cross-AMM Router

The key insight that separates the STAMM audit from this router audit is:
$$\text{STAMM Protocol} \implies \text{Proves correctness of a closed, controlled mathematical system}$$
$$\text{Smart Router} \implies \text{Composes and routes through untrusted, heterogeneous external systems}$$

| Vector Dimension | STAMM AMM Pool Model | Cross-AMM Smart Router Model | Router v3 Defense Strategy |
|---|---|---|---|
| **Liquidity & State** | Controls own reserves and $K$-invariant | Reads foreign reserves; no invariant control | Realized balance deltas; signed aggregate output floor |
| **External Calls** | None (self-contained pool) | Issues inner calls to 4+ external AMMs | Pinned creator verification, derived logic sigs, curated whitelists |
| **Asset Custody** | Long-term custody of LP reserves | Transitory custody during multi-hop route | Dynamic zero-balance loans; close-on-success; input conservation checks |
| **Opcode Budgets** | Internal operations sized per method | Multi-hop groups cross application budget limits | Group opcode pooling, bounded STAMM budget calls ($\le 8$ opups) |
| **Reentrancy Risk** | Simple state variable guards | Cross-transaction group manipulation | Group cleanliness scan (`_assert_group_is_clean`), adjacent funding checks |

---

## 3. Analysis Matrix: Gaps, Mitigations, and Verification

### 3.1 AVM Resource & State Griefing (from Analysis 1 & 2)
- **MBR Draining via Junk Assets:**
  - *Risk:* Caller forces router to opt into arbitrary ASAs, locking 0.1 ALGO per asset.
  - *Router Defense:* `opt_in_asset()` requires a matching `route()` in the atomic group (`_routed_in_group`). `route()` immediately closes the holding to the caller upon completion (`_pay_out(close=True)` / `AssetTransfer(asset_close_to=Txn.sender)`), releasing the 0.1 ALGO back to the router.
- **Opcode Budget Exhaustion:**
  - *Risk:* Multi-hop routes exceed 700 opcode units per call.
  - *Router Defense:* Opcode budget pools across the atomic group (700 units per app call). `pool_budget()` adds a zero-cost top-level call when discount verification is present; `_stamm_leg` dynamically requests budget inner txns up to `MAX_STAMM_OPUPS = 8`.

### 3.2 Cross-Protocol State Desynchronization (from Analysis 3)
- **Foreign AMM Output Discrepancies:**
  - *Risk:* External AMMs log incorrect amounts, update reserves post-payout, or deduct unexpected protocol fees.
  - *Router Defense:* The router **never trusts external AMM return values or logs**. Instead, it executes:
    $$\Delta B = \text{Balance}_{\text{after}} - \text{Balance}_{\text{before}}$$
    via `op.AssetHoldingGet.asset_balance()` / `_held(asset_out)`. Only actual physical tokens received are passed to the next leg.

### 3.3 Re-Entrancy & Group Manipulation (from Analysis 1, 2 & 3)
- **Group Smuggling / Hijacking:**
  - *Risk:* Attacker inserts foreign transactions into the group that rekey the user, close account balances, or siphon fees.
  - *Router Defense:*
    1. `_assert_group_is_clean()` verifies every single transaction in `urange(Global.group_size)` has `rekey_to == 0`, `close_remainder_to == 0`, and `asset_close_to == 0`.
    2. `_input_amount()` strictly enforces that the funding payment/transfer immediately precedes the route call: `payment.group_index + 1 == Txn.group_index`.

### 3.4 Application ID Spoofing (from Analysis 1 & 2)
- **Malicious Fake Pool Injection:**
  - *Risk:* Attacker passes a malicious contract ID as a leg pool to steal intermediate tokens.
  - *Router Defense:*
    1. **Tinyman v2:** Pool address is derived deterministically on-chain from the asset pair and template bytecode hash (`_tinyman_v2_pool`).
    2. **Pact:** Creator address is verified on-chain via `_assert_created_by` against pinned creator addresses (`PACT_POOL_CREATORS`).
    3. **STAMM:** Creator address is verified on-chain via `_assert_created_by` against pinned creator address (`STAMM_POOL_CREATORS`).
    4. **AlgoFi:** Pool application ID is checked against a curated whitelist of verified liquid pools (`ALGOFI_POOLS`), and the manager ID is pinned to `ALGOFI_MANAGER_APP_ID`.

### 3.5 Cross-Hop Slippage Drift & Frontrunning (from Analysis 2 & 3)
- **Cumulative Rounding / Multi-Hop Loss:**
  - *Risk:* Enforcing per-hop floors leads to intermediate leg reverts or rounding leakage.
  - *Router Defense:*
    - The contract removes per-leg minimum outputs and enforces **one global floor** on the realized end-to-end output:
      $$\text{Total Paid} = \sum_{i} \text{Output}_i \ge \text{Minimum Received}$$
    - The floor is authenticated via a backend-signed note (`_signed_floor`) carrying the quote signer's signature and the transaction's `lastValid` deadline.

### 3.6 Router Balance Contamination & Residual Dust (from Analysis 1 & 3)
- **Cross-User Balance Bleed:**
  - *Risk:* Leftover dust or pre-held tokens from previous swaps distort accounting or get siphoned.
  - *Router Defense:*
    1. Router holds zero inventory between routes.
    2. All outputs are computed strictly using balance deltas ($\Delta B$).
    3. `_assert_input_spent` verifies that pre-held ASA input is completely consumed: $\text{Balance}_{\text{after}} = \text{Balance}_{\text{before}} - \text{Amount}_{\text{in}}$.
    4. Residual intermediate holdings are asserted empty (`assert self._held(middle) == 0`) and closed out.
