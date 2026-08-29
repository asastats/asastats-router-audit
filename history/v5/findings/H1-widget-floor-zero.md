# Finding H1: Frontend-Controlled Floor Slippage Extraction

- **Severity:** High
- **Category:** Slippage Protection / Economic
- **Location:** `contracts/router_app.py:route` / `route3`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
When `minimum_received` was an argument passed by the caller or frontend widget, a compromised web client or malicious intermediary could set `minimum_received = 0`, executing trades at catastrophic rates and extracting slippage via sandwich bots.

---

## 2. Remediation in Code
1. Completely removed the `minimum_received` argument from public `route` and `route3` method signatures.
2. Implemented the co-signed transaction note architecture (`_signed_floor`):
   - The backend `quote_signer` co-signs a terminating `pool_budget()` transaction.
   - The note binds `(app_id, sender, asset_out, per_index_inputs, asserting_index)`.
   - The router extracts the minimum received floor directly from this authenticated note.

---

## 3. Verification Evidence
- `TestTheAuthorisedFloor` tests:
  - `test_the_floor_the_signer_set_is_the_one_enforced` passes.
  - `test_an_authorisation_bound_to_another_position_is_refused` passes.
  - `test_dropping_a_route_from_a_signed_split_is_refused` passes.
