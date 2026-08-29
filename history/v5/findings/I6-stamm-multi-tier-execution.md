# Finding I6: STAMM Multi-Tier Execution ABI Alignment

- **Severity:** Informational
- **Category:** ABI Compatibility / Integration
- **Location:** `contracts/router_app.py:_stamm_leg`
- **Origin:** v3 Audit (2026-08-15)
- **Status (v5):** **VERIFIED SAFE**

---

## 1. Description
STAMM AMM pools utilize custom ABI selectors and multi-tier deposit arguments.

---

## 2. Evaluation & Verification
`tests/test_stamm_abi.py` confirms that `STAMM_SWAP` selector (`0x90c59a40`) and encoded tier split payloads match deployed STAMM pool contracts exactly.
