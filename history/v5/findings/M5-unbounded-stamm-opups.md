# Finding M5: Unbounded STAMM Opup Requests

- **Severity:** Medium
- **Category:** Resource Management / Denial-of-Service
- **Location:** `contracts/router_app.py:_swap_leg`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
If `leg.opups` is unconstrained, a caller could request large numbers of inner opup transactions, causing opcode budget distortion or hitting inner transaction execution limits.

---

## 2. Remediation in Code
Enforced in `_swap_leg`:
```python
if provider != PROVIDER_STAMM:
    assert leg.opups.as_uint64() == 0, "opups are only for STAMM"
else:
    assert leg.opups.as_uint64() <= MAX_STAMM_OPUPS, "opups above the supported STAMM maximum"
```
Where `MAX_STAMM_OPUPS = 8`.

---

## 3. Verification Evidence
- `tests/test_stamm_opups.py` suite passes.
- `test_the_deployed_count_clears_the_floor_with_room` passes.
- `test_the_builder_ceiling_matches_the_contract_ceiling` passes.
