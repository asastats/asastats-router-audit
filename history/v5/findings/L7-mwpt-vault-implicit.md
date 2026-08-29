# Finding L7: MWPT On-Chain Dynamic Vault Verification

- **Severity:** Low
- **Category:** AMM Integration / Address Resolution
- **Location:** `contracts/router_app.py:_pact_leg`
- **Origin:** v4 Audit (2026-08-22)
- **Status (v5):** **REMEDIATED & VERIFIED**

---

## 1. Description
In v4, the MWPT vault address was determined off-chain. If an off-chain quoter were compromised, it could attempt to point the deposit destination at an unverified account.

---

## 2. Remediation in Code
In v5, `_pact_leg` dynamically queries the pool's global state key `vault` on-chain:
```python
if is_mwpt:
    vault, has_vault = op.AppGlobal.get_ex_uint64(pool_app, Bytes(b"vault"))
    assert has_vault, "an MWPT pool names its vault"
    vault_address, vault_exists = op.AppParamsGet.app_address(
        Application(vault)
    )
    assert vault_exists, "the MWPT vault must be named by the group"
    escrow = vault_address
```
The deposit is dispatched exclusively to `escrow` (the verified vault address).

---

## 3. Verification Evidence
- `TestTheMwptDepositReachesTheVault` suite:
  - `test_an_algo_deposit_is_addressed_to_the_vault` passes.
  - `test_an_asset_deposit_is_addressed_to_the_vault` passes.
  - `test_a_pool_naming_no_vault_is_refused` passes.
  - `test_the_vault_comes_from_the_pool_rather_than_the_leg` passes.
