# Finding C1: Permissionless `convert_and_distribute` Pool Drain

- **Severity:** Critical
- **Category:** Access Control / Fund Draining
- **Location:** `contracts/router_app.py:convert_and_distribute`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
In initial revisions, `convert_and_distribute` was a permissionless method that accepted a caller-supplied `Leg` struct. A malicious actor could provide the application ID of an attacker-controlled pool contract. The router would transfer accrued treasury ALGO to that pool's escrow; if the pool returned 0 ASASTATS and the caller passed `minimum_out = 0`, the transaction would succeed and the treasury ALGO was stolen.

---

## 2. Remediation in Code
1. Added strict admin access control:
   ```python
   assert Txn.sender == self.admin, "only the admin may convert"
   ```
2. Removed the caller-supplied `Leg` parameter. The approved conversion pool is now stored in global state (`self.conversion_pool`) and set in advance via `set_conversion_pool`.
3. Added `_assert_no_conversion_pool_approval()` to prevent same-group setter and conversion calls.

---

## 3. Verification Evidence
- Unit test: `TestConversionBounds::test_a_non_admin_cannot_convert` passes.
- LocalNet test: `TestTheApprovedConversionPool::test_the_caller_cannot_name_a_pool_at_all` passes.
