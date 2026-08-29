# Finding M1: Route Path Sanitization (Duplicate / Cycling Assets)

- **Severity:** Medium
- **Category:** Input Validation / Routing Logic
- **Location:** `contracts/router_app.py:route` / `route3`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Routes containing cycles (such as A → B → A) or identical intermediate assets waste execution fees and can cause unexpected state or accounting overlaps.

---

## 2. Remediation in Code
Explicit on-chain assertions enforce pairwise distinctness:
- In `route`:
  ```python
  assert asset_in != middle, "a route cannot cross itself"
  assert middle != asset_out, "a route cannot cross itself"
  assert asset_in != asset_out, "a route cannot swap an asset for itself"
  ```
- In `route3`:
  ```python
  assert asset_in != first_middle and first_middle != second_middle and second_middle != asset_out
  assert asset_in != second_middle and first_middle != asset_out and asset_in != asset_out
  ```

---

## 3. Verification Evidence
- `TestRoute3Guards` tests:
  - `test_route3_rejects_the_same_input_and_output` passes.
  - `test_route3_rejects_first_middle_equal_to_input` passes.
  - `test_route3_rejects_second_middle_equal_to_output` passes.
  - `test_route3_rejects_the_two_middle_assets_crossing` passes.
