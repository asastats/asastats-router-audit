# Finding I4: Dynamic Minimum Balance Handling

- **Severity:** Informational
- **Category:** AVM Mechanics / MBR
- **Location:** `contracts/router_app.py`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **VERIFIED SAFE**

---

## 1. Description
Analysis 2 recommended verifying dynamic minimum balance calculations (`app.minBalance`).

---

## 2. Evaluation & Verification
Because the router does not maintain long-term asset holdings or dynamic box storage, its base MBR is fixed at deployment. Transient holdings recover their MBR in the same transaction group.
