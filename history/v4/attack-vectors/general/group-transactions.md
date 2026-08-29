# Group Transaction Attack Vectors

These vectors analyze attacks that exploit the structure of Algorand atomic transaction groups: rekeying, closing accounts/ASAs, padding the group with extra transactions, reordering transactions, and using group indices to confuse the contract.

The router's defence is `_assert_group_is_clean`, which scans every outer transaction for `RekeyTo`, `CloseRemainderTo`, `AssetCloseTo` ≠ zero. This is called from every value-moving entry point (`route`, `route3`, `convert_and_distribute`, `close_holding`, `delete_application`, `opt_in_asset`, `pool_budget`).

## Vectors

### GENERAL-GRP-01: RekeyTo ≠ 0 on outer transactions
- **Verdict:** Defended.
- **Code:** `_assert_group_is_clean` checks `gtxn.rekey_to(idx) == Global.zero_address`.
- **Test:** `tests/test_router_contract.py::test_the_group_is_clean`.

### GENERAL-GRP-02: CloseRemainderTo ≠ 0 on outer ALGO payments
- **Verdict:** Defended.
- **Code:** `_assert_group_is_clean` checks `gtxn.close_remainder_to(idx) == Global.zero_address` for TypeEnum = 1.
- **Test:** `tests/test_router_contract.py::test_close_remainder_to_rejected`.

### GENERAL-GRP-03: AssetCloseTo ≠ 0 on outer ASA transfers
- **Verdict:** Defended.
- **Code:** `_assert_group_is_clean` checks `gtxn.asset_close_to(idx) == Global.zero_address` for TypeEnum = 4.
- **Test:** `tests/test_router_contract.py::test_asset_close_to_rejected`.

### GENERAL-GRP-04: RekeyTo ≠ 0 on inner transactions
- **Verdict:** Defended.
- **Code:** All inner transactions use `fee=0` and do not set `rekey_to`.
- **Test:** All inner-txn-building tests.

### GENERAL-GRP-05: CloseRemainderTo ≠ 0 on inner ALGO transfers
- **Verdict:** Defended.
- **Code:** Inner `itxn.Payment(receiver=..., amount=..., fee=0)` does not set `close_remainder_to`.
- **Test:** Adversarial pool tests.

### GENERAL-GRP-06: AssetCloseTo ≠ 0 on inner ASA transfers
- **Verdict:** Defended.
- **Code:** Inner `itxn.AssetTransfer(...)` does not set `asset_close_to`.
- **Test:** Adversarial pool tests.

### GENERAL-GRP-07: Group padding with extra transactions
- **Verdict:** Defended.
- **Code:** Every group tx is scanned by `_assert_group_is_clean`; any unexpected tx is rejected only if it has a malicious field set. Otherwise, extra tx is allowed (e.g., fee pool).
- **Note:** The router does not assert `Global.group_size == expected_size`; this is intentional so the quote server's authentication transaction and `verify_discount`/`pool_budget` can be added.
- **Test:** Manual test in `tests/test_router_contract.py`.

### GENERAL-GRP-08: Group reordering to confuse index references
- **Verdict:** Defended.
- **Code:** All group references use relative indexing (`Txn.group_index`, `payment.group_index + 1`, etc.), not absolute indices. The quote server's transaction is identified by `Global.group_size - 1` (last transaction).
- **Test:** `tests/test_router_contract.py::test_route_with_reordered_group` (manual).

### GENERAL-GRP-09: Quote server's transaction placed in middle of group
- **Verdict:** Defended.
- **Code:** `_signed_floor` reads `gtxn.ApplicationCall(Global.group_size - 1)`.
- **Test:** `tests/test_router_contract.py::test_quote_at_last_position`.

### GENERAL-GRP-10: Multiple quote server transactions
- **Verdict:** Defended.
- **Code:** `_signed_floor` only reads the last one; earlier ones are ignored.
- **Note:** A malicious frontend could add a fake quote tx before the real one; the real one (last) wins.
- **Test:** Manual.

### GENERAL-GRP-11: Funding transaction not adjacent to route
- **Verdict:** Defended (M2 v3).
- **Code:** `_input_amount` asserts `payment.group_index + 1 == Txn.group_index`.
- **Test:** `tests/test_router_contract.py::test_funding_must_be_adjacent`.

### GENERAL-GRP-12: Funding transaction has wrong sender
- **Verdict:** Defended.
- **Code:** `_input_amount` asserts `gtxn.Sender(idx) == Txn.sender`.
- **Test:** `tests/test_router_contract.py::test_funding_sender_must_match`.

### GENERAL-GRP-13: Funding transaction has wrong amount
- **Verdict:** Defended (M3 v3).
- **Code:** `_assert_input_spent` checks `_held(asset_in) - before_held == amount`.
- **Test:** `tests/test_router_contract.py::test_input_conservation`.

### GENERAL-GRP-14: Funding transaction has wrong asset
- **Verdict:** Defended.
- **Code:** `_input_amount` asserts `gtxn.XferAsset(idx) == asset_in` for ASA.
- **Test:** Manual.

### GENERAL-GRP-15: Funding transaction uses wrong receiver
- **Verdict:** Defended.
- **Code:** `_input_amount` asserts `gtxn.AssetReceiver(idx) == Global.current_application_address` for ASA, or `gtxn.Receiver(idx) == Global.current_application_address` for ALGO.
- **Test:** Manual.

### GENERAL-GRP-16: Application args not properly typed
- **Verdict:** Not applicable.
- **Code:** ARC-4 dispatcher handles typing; puyapy 5.9.0 inserts automatic length checks.
- **Test:** Verified at compile time.

### GENERAL-GRP-17: Application call type confusion
- **Verdict:** Defended (I2 v3).
- **Code:** `_signed_floor` asserts `TransactionType.ApplicationCall` on the quote server's transaction.
- **Test:** Manual.

### GENERAL-GRP-18: Quote server's transaction has wrong application ID
- **Verdict:** Defended.
- **Code:** `_signed_floor` asserts `gtxn.ApplicationID(idx) == Global.current_application_id`.
- **Test:** Manual.

### GENERAL-GRP-19: Quote server's transaction has wrong number of args
- **Verdict:** Defended.
- **Code:** `_signed_floor` asserts `Len(gtxn.ApplicationArgs(idx)) == 1` and the arg is `POOL_BUDGET_SIGNATURE`.
- **Test:** Manual.

### GENERAL-GRP-20: Group with concurrent rekeying + asset close + AlgoFi swap
- **Verdict:** Defended.
- **Code:** `_assert_group_is_clean` scans every transaction; one bad transaction blocks all.
- **Test:** Adversarial group test.
