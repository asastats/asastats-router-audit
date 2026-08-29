# Trail of Bits Algorand Vulnerability Scanner Results — v4 Smart Router

The Trail of Bits Algorand vulnerability scanner at `<audit>/router-audit-v3/algorand-vulnerability-scanner/SKILL.md` defines 11 vulnerability patterns. The v4 audit applied each pattern to the compiled TEAL at `router/build/tealer/Router.approval.teal`.

## 11-pattern checklist

| # | Pattern | Status | Verdict | Reference |
|---|---------|:------:|---------|-----------|
| 1 | Rekeying | PASS | `_assert_group_is_clean` checks every outer txn's `RekeyTo == 0`; inner txns never set `RekeyTo`. | `router_app.py:_assert_group_is_clean` |
| 2 | Group-size checks | PASS | All 52 dynamic group accesses use `Txn.group_index` arithmetic. | Manual proof in `tealer-results.md` |
| 3 | Fee pooling | PASS | All inner txns have `fee = 0`; outer route call pools via `route_fee`. | `router_app.py:_swap_leg` |
| 4 | Account closing | PASS | `_assert_group_is_clean` checks `CloseRemainderTo == 0`; inner txns never set it. | `router_app.py:_assert_group_is_clean` |
| 5 | Clear-state handling | PASS | Clear program is `pushint 1; return`; no funds at risk. | `Router.clear.teal` |
| 6 | Asset ID validation | PASS | Asset IDs are validated via `Txn.Assets` array; `_held(asset)` rejects invalid assets. | `router_app.py:_held` |
| 7 | App ID validation | PASS | App IDs are validated via `Txn.Applications` array; `_assert_created_by` and `_assert_listed` authenticate. | `router_app.py:_assert_created_by`, `_assert_listed` |
| 8 | Foreign array abuse | PASS | `foreign_apps` and `foreign_assets` arrays are precisely sized; pool apps and assets are referenced. | All inner txn builders |
| 9 | Box storage | PASS | Router uses no direct box storage; pools read their own boxes. | n/a |
| 10 | Update/Delete authority | PASS | Update blocked (no path); Delete admin-only with assertions. | `router_app.py:_delete_application` |
| 11 | Access control | PASS | Admin-only setters; backend-signed floor; backend-signed voucher. | All `set_*` methods, `_signed_floor`, `verify_discount` |

## Pattern-by-pattern analysis

### Pattern 1: Rekeying

**Threat:** An attacker submits a transaction with `RekeyTo ≠ 0`, transferring the signer's authority to a malicious address.

**Defence:** `_assert_group_is_clean` checks every outer transaction's `RekeyTo == Global.zero_address`. Inner transactions never set `RekeyTo`.

**Status:** PASS.

**Code reference:** `router_app.py:_assert_group_is_clean` lines ~110-150.

### Pattern 2: Group-size checks

**Threat:** An attacker pads the group with extra transactions or reorders them to confuse the contract.

**Defence:** All 52 dynamic group accesses use `Txn.group_index` arithmetic (relative indexing). The router does not assert `Global.group_size == expected_size` because the quote server's authentication transaction and `verify_discount`/`pool_budget` are added externally.

**Status:** PASS (with manual proof; Tealer timed out on `group-size-check`).

**Code reference:** Manual verification of lines 548, 1588, 1942, 2015, 2042, 2170, 2478, 4166.

### Pattern 3: Fee pooling

**Threat:** An attacker adds high-fee transactions to the group, hoping the router pools them.

**Defence:** All inner transactions have `fee = 0`. The outer route call pools fees via `route_fee` (computed off-chain). The router never pays inner-txn fees.

**Status:** PASS.

**Code reference:** All `itxn.*` builders.

### Pattern 4: Account closing

**Threat:** An attacker closes the router's account via `CloseRemainderTo ≠ 0`.

**Defence:** `_assert_group_is_clean` checks every outer transaction's `CloseRemainderTo == 0` and `AssetCloseTo == 0`. Inner transactions never set these fields.

**Status:** PASS.

**Code reference:** `router_app.py:_assert_group_is_clean`.

### Pattern 5: Clear-state handling

**Threat:** The clear-state program mishandles funds or state, allowing an attacker to drain assets during `ClearState`.

**Defence:** The clear-state program is `pushint 1; return` (7 lines). It does not access any assets or state.

**Status:** PASS.

**Code reference:** `Router.clear.teal`.

### Pattern 6: Asset ID validation

**Threat:** An attacker submits a transaction referencing an invalid asset ID, causing the contract to misbehave.

**Defence:** Asset IDs are validated via `Txn.Assets` array; `_held(asset)` rejects invalid assets by reading the router's `asset_holding_get`.

**Status:** PASS.

**Code reference:** `router_app.py:_held`, `_input_amount`, `_assert_input_spent`.

### Pattern 7: App ID validation

**Threat:** An attacker submits a transaction referencing an invalid or malicious app ID.

**Defence:** App IDs are validated via `Txn.Applications` array. External pool apps are authenticated via `_assert_created_by` (Pact, STAMM) or `_assert_listed` (AlgoFi) or on-chain LogicSig hash derivation (Tinyman v2).

**Status:** PASS.

**Code reference:** `router_app.py:_assert_created_by`, `_assert_listed`.

### Pattern 8: Foreign array abuse

**Threat:** An attacker submits a transaction with misconfigured `foreign_apps` or `foreign_assets` arrays.

**Defence:** The router references external pool apps in `foreign_apps` and the pool's two assets in `foreign_assets`. The arrays are precisely sized; no extra references are included.

**Status:** PASS.

**Code reference:** All inner `itxn.ApplicationCall` builders.

### Pattern 9: Box storage

**Threat:** An attacker fills the router's box storage, raising MBR.

**Defence:** The router uses no direct box storage. Pools read their own boxes via the router's `foreign_apps` array (which doesn't allocate router-side storage).

**Status:** PASS (N/A).

**Code reference:** n/a.

### Pattern 10: Update/Delete authority

**Threat:** An attacker calls `UpdateApplication` or `DeleteApplication` to modify or destroy the contract.

**Defence:**
- `UpdateApplication`: no path exists; the ARC-4 dispatcher has no update route. Tealer `unprotected-updatable` shows 9 results, all false positives (by design).
- `DeleteApplication`: `_delete_application` is admin-only, requires `accrued == 0` and `total_assets == 0`. Tealer `unprotected-deletable` shows 9 results, all false positives (by design).

**Status:** PASS.

**Code reference:** `router_app.py:_delete_application`.

### Pattern 11: Access control

**Threat:** An attacker calls a privileged method without authorisation.

**Defence:**
- Admin methods (`set_admin`, `set_fee`, etc.) require `Txn.sender == self.admin`.
- Floor authentication requires the backend-signed note (Ed25519 signature verified).
- Voucher discount requires the backend-signed voucher (Ed25519 signature verified).
- Route and route3 methods check `_signed_floor` (quote-authenticated floor).
- Conversion is admin-only with pre-approved pool.

**Status:** PASS.

**Code reference:** All `set_*` methods, `_signed_floor`, `verify_discount`, `convert_and_distribute`.

## MWPT-specific notes

The 11-pattern checklist applies equally to the MWPT integration:

1. **Rekeying:** MWPT legs go through the same `_pact_leg` subroutine as legacy Pact legs. No new rekey surface.
2. **Group-size checks:** MWPT legs add 1 inner transaction (deposit + pool call). Total group size unchanged.
3. **Fee pooling:** MWPT pool calls have `fee = 0` like legacy Pact calls. No new fee surface.
4. **Account closing:** MWPT pool calls do not set `close_remainder_to`. No new surface.
5. **Clear-state handling:** n/a.
6. **Asset ID validation:** MWPT pool calls reference `asset_a` and `asset_b` in `foreign_assets`. Validated as before.
7. **App ID validation:** MWPT pool calls reference the pool's app ID in `foreign_apps`. Authenticated via creator pin (new selector branch in `_pact_leg`).
8. **Foreign array abuse:** MWPT pool calls reference the pool app and vault app. Both are in `foreign_apps`; the vault reference is the new surface.
9. **Box storage:** MWPT pool calls reference the vault's boxes. Not the router's storage.
10. **Update/Delete authority:** No change.
11. **Access control:** No change. MWPT pool calls follow the same auth path as legacy Pact calls.

## Cross-references

- [`tealer-results.md`](tealer-results.md) — Tealer static analysis sweep
- [`../attack-vectors/pact/mwpt.md`](../attack-vectors/pact/mwpt.md) — 27 MWPT-specific vectors
- [`../DISCLAIMER.md`](../DISCLAIMER.md) — audit limitations
- [`<audit>/router-audit-v3/algorand-vulnerability-scanner/SKILL.md`](../../../audit/router-audit-v3/algorand-vulnerability-scanner/SKILL.md) — scanner skill definition
