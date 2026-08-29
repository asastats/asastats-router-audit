# Finding L4: Treasury Conversion Floor Zero Exemption Bounding

- **Severity:** Low
- **Category:** Treasury Governance / Slippage
- **Location:** `contracts/router_app.py:convert_and_distribute`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Allowing `minimum_out = 0` on treasury conversions could expose large fee batches to extreme slippage. Conversely, strictly requiring `minimum_out > 0` on sub-floor dust balances prevented contract retirement.

---

## 2. Remediation in Code
Enforced exact bounding:
```python
assert minimum_out > 0 or (
    batch == self.accrued
    and batch < TemplateVar[UInt64]("MIN_CONVERSION_BATCH")
), "a conversion must state a floor unless it is a final sweep"
```
Large conversions must specify a non-zero floor; only sub-floor dust sweeps may pass zero.

---

## 3. Verification Evidence
- `TestTheConversionFloor` suite:
  - `test_a_zero_floor_is_refused` passes.
  - `test_a_final_sweep_may_accept_nothing` passes.
  - `test_a_zero_floor_is_refused_for_a_large_final_sweep` passes.
