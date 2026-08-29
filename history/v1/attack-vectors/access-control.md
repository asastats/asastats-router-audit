# Access Control

| # | Vector | Verdict | Notes |
|---|--------|---------|-------|
| 1 | Non-admin calls `set_admin` | Defended | `assert Txn.sender == self.admin` |
| 2 | Non-admin calls `set_fee` | Defended | `assert Txn.sender == self.admin` |
| 3 | Non-admin calls `set_escrow` | Defended | `assert Txn.sender == self.admin` |
| 4 | Non-admin calls `set_voucher_signer` | Defended | `assert Txn.sender == self.admin` |
| 5 | Non-admin calls `close_holding` | Defended | `assert Txn.sender == self.admin` |
| 6 | Non-admin calls `delete_application` | Defended | `assert Txn.sender == self.admin` |
| 7 | Non-admin calls `convert_and_distribute` | **Patched** | Was permissionless; now admin-only |
| 8 | Admin sets fee above ceiling | Defended | `assert fee_bps <= MAX_FEE_BPS` |
| 9 | Admin sets fee to 100 bps | Admin-controlled | Capped, but still within admin power |
| 10 | Admin sets escrow to attacker | Admin-controlled | Escrow receives platform fees |
| 11 | Admin deletes app while fees accrued | Defended | `assert self.accrued == 0` |
| 12 | Bypass via `RESTRICT_TO_ADMIN` template | By design | Compile-time flag, not runtime |
