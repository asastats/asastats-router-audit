# Trail of Bits Algorand Vulnerability Scanner Audit (v5)

**Framework:** Trail of Bits Algorand "Not So Smart Contracts" Security Checklist  
**Target:** ASA Stats Smart Router (`router/contracts/router_app.py`, App ID `3688554446`)  
**Overall Result:** **11 / 11 PATTERNS EVALUATE PASS**

---

## 1. Vulnerability Checklist Results

### Pattern 1: Unchecked `RekeyTo` Field
- **Check:** Does the contract verify `rekey_to == zero_address` across all transaction paths?
- **Result:** **PASS**
- **Evidence:** `_assert_group_is_clean` inspects every transaction in `urange(Global.group_size)` and asserts `gtxn.Transaction(i).rekey_to == Global.zero_address`.

### Pattern 2: Unchecked `CloseRemainderTo` Field
- **Check:** Does the contract prevent unexpected ALGO account draining via `close_remainder_to`?
- **Result:** **PASS**
- **Evidence:** `_assert_group_is_clean` verifies `close_remainder_to == Global.zero_address` for all outer transactions.

### Pattern 3: Unchecked `AssetCloseTo` Field
- **Check:** Does the contract verify `asset_close_to` on relevant transactions?
- **Result:** **PASS**
- **Evidence:** `_assert_group_is_clean` asserts `asset_close_to == Global.zero_address`. Router inner close-outs only close transient assets to caller/creator.

### Pattern 4: Missing Group Size Checks
- **Check:** Does the contract protect against unexpected transaction group sizes?
- **Result:** **PASS**
- **Evidence:** The contract dynamically iterates over `Global.group_size` and strictly validates adjacent transactions.

### Pattern 5: Missing Group Index Checks
- **Check:** Does the contract validate relative group positions?
- **Result:** **PASS**
- **Evidence:** `_input_amount` strictly asserts `payment.group_index + 1 == Txn.group_index`. `_signed_floor` binds the exact asserting index.

### Pattern 6: Missing Transaction Type Validation
- **Check:** Does the contract enforce expected transaction types?
- **Result:** **PASS**
- **Evidence:** ARC-4 typed parameters and explicit assertions (`authorisation.type == TransactionType.ApplicationCall`, `payment.type == TransactionType.Payment`).

### Pattern 7: Fee Pooling Exploitation
- **Check:** Can an attacker exploit fee pooling to force the contract to pay external transaction fees?
- **Result:** **PASS**
- **Evidence:** All router inner transactions specify `fee = 0`. Outer caller transaction pools all necessary network fees.

### Pattern 8: Missing Field Validation
- **Check:** Are all critical transaction fields (sender, receiver, amount, asset ID) validated?
- **Result:** **PASS**
- **Evidence:** `_input_amount` validates `sender == Txn.sender`, `xfer_asset.id == asset_in`, and amount matching. `_pay_out` sets `receiver = Txn.sender`.

### Pattern 9: Broken Access Control
- **Check:** Are privileged methods restricted to authorized accounts?
- **Result:** **PASS**
- **Evidence:** All administrative setters and `convert_and_distribute` enforce `assert Txn.sender == self.admin`.

### Pattern 10: Unsafe ClearState Handling
- **Check:** Does `ClearState` leak assets or leave state vulnerable?
- **Result:** **PASS**
- **Evidence:** The contract maintains no local state; `ClearState` is minimal `pushint 1; return`.

### Pattern 11: Unchecked Asset / App Configuration
- **Check:** Are foreign assets and applications validated before interaction?
- **Result:** **PASS**
- **Evidence:** External pool apps are derived or verified against pinned creator lists (`PACT_POOL_CREATORS`, `STAMM_POOL_CREATORS`, `ALGOFI_POOLS`).
