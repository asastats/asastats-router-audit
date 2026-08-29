# Finding L2: Zero-Address Checks in Administrative Setters

- **Severity:** Low
- **Category:** Access Control / Parameter Validation
- **Location:** `contracts/router_app.py:set_admin, set_escrow, set_quote_signer`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
Setting administrative or escrow accounts to the zero address could brick contract governance or permanently blackhole protocol fee distributions.

---

## 2. Remediation in Code
Explicit zero-address rejection added to `set_admin`, `set_escrow`, and `set_quote_signer`:
```python
assert new_admin != Global.zero_address, "admin cannot be the zero address"
assert new_escrow != Global.zero_address, "escrow cannot be the zero address"
assert new_signer != Global.zero_address, "quote signer cannot be the zero address"
```

---

## 3. Verification Evidence
- `TestAdministration::test_reassigning_administration_rejects_zero` passes.
- `TestEscrow::test_the_escrow_cannot_be_set_to_zero` passes.
