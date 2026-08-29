# Finding I3: Dead Code Removal for Non-STAMM Opup Branch

- **Severity:** Informational
- **Category:** Code Hygiene / Optimization
- **Location:** `contracts/router_app.py:_swap_leg`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **REMEDIATED**

---

## 1. Description
Early versions contained dead code attempting to issue opup transactions for non-STAMM providers.

---

## 2. Evaluation & Verification
Removed in v3; `_swap_leg` strictly asserts `assert leg.opups.as_uint64() == 0` for non-STAMM providers, saving 66 TEAL instructions.
