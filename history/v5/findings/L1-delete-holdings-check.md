# Finding L1: Application Deletion Asset Holdings Verification

- **Severity:** Low
- **Category:** Lifecycle / Fund Stranding
- **Location:** `contracts/router_app.py:delete_application`
- **Origin:** v1 Audit (2026-08-11)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
If `delete_application` did not verify that all asset holdings were closed, calling deletion could leave ASA balances permanently stranded in the retired application account.

---

## 2. Remediation in Code
`delete_application` enforces:
1. `assert Txn.sender == self.admin`
2. `assert self.accrued == 0`
3. Verifies `total_assets == 0` (via account asset holding lookup).

---

## 3. Verification Evidence
- `TestDeletion::test_a_held_asset_blocks_deletion` passes.
- `TestDeletion::test_accrued_fees_block_deletion` passes.
