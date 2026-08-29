# Finding L5: Voucher Signer Rotation & Revocation

- **Severity:** Low
- **Category:** Access Control / Governance
- **Location:** `contracts/router_app.py:set_voucher_signer`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **VERIFIED SAFE BY DESIGN**

---

## 1. Description
If the voucher signer key is compromised, attackers could forge fee discount vouchers.

---

## 2. Evaluation & Verification
The admin can instantly revoke the voucher signing mechanism by executing `set_voucher_signer(NO_VOUCHER_SIGNER)`. Discounts only affect platform fee revenues (bounded to at most 1%) and can never touch user swap principals.

---

## 3. Verification Evidence
- `TestVoucherSigner` rotation tests pass.
- Setting `NO_VOUCHER_SIGNER` disables all discount verifications.
