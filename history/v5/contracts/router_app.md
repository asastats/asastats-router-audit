# Smart Contract Verification: `router_app.py` (v5)

**File:** `router/contracts/router_app.py`  
**Class:** `Router(ARC4Contract)`  
**Language:** Algorand Python / PuyaPy v5.9.0  
**TEAL Bytecode:** 4,681 lines approval (`Router.approval.teal`), 7 lines clear (`Router.clear.teal`)  

---

## 1. Top-Level Methods Analysis

### 1.1 `route` (Two-Leg Swap)
- **Signature:** `route(asset_in, asset_middle, asset_out, payment, first_leg, second_leg) -> uint64`
- **Access:** Public in the source. **Restricted in every mainnet deployment to date**, `3688554446` included: compiled with `RESTRICT_TO_ADMIN`, so the method asserts `Txn.sender == self.admin` and refuses every other caller. Testnet is unrestricted.
- **Flow:**
  1. `_assert_group_is_clean()`: Rejects group if any transaction rekeys or closes accounts.
  2. `_input_amount(payment, asset_in)`: Validates payment comes from `Txn.sender` and is adjacent (`payment.group_index + 1 == Txn.group_index`).
  3. `_signed_floor(asset_out, amount_in)`: Extracts authenticated minimum output from quote signer note.
  4. Pairwise distinct assertion: `assert asset_in != asset_middle and asset_middle != asset_out and asset_in != asset_out`.
  5. Transient holding lifecycle: Opens `asset_out` and `middle` via `_open_holding`.
  6. Swap Leg 1: Calls `_swap_leg(first_leg, asset_in, middle, amount_in)`.
  7. `_assert_input_spent(asset_in, input_before, amount_in)`: Proves input consumed.
  8. Skim fee (if middle is ALGO): `_skim(middle, carried)`.
  9. Swap Leg 2: Calls `_swap_leg(second_leg, middle, asset_out, net_carried)`.
  10. Payout & Group Floor: Calls `_pay_out(Txn.sender, asset_out, produced, opened)` and checks `_group_paid() >= minimum_received`.
  11. Returns realised output `produced`.

### 1.2 `route3` (Three-Leg Swap)
- **Signature:** `route3(asset_in, first_middle, second_middle, asset_out, payment, first_leg, second_leg, third_leg) -> uint64`
- **Access:** Public in the source. **Restricted in every mainnet deployment to date**, `3688554446` included: compiled with `RESTRICT_TO_ADMIN`, so the method asserts `Txn.sender == self.admin` and refuses every other caller. Testnet is unrestricted.
- **Flow:** Same structure as `route`, with three pairwise-distinct intermediate assertions and fee skim executed at most once on whichever intermediate is ALGO.

### 1.3 `opt_in_asset` (Transient Float Opt-In)
- **Signature:** `opt_in_asset(asset) -> void`
- **Access:** Public
- **Flow:** `_assert_group_is_clean()`; verifies `_routed_in_group(asset)` to confirm this opt-in serves an active route in the same group; issues zero-fee inner opt-in transaction.

### 1.4 `verify_discount` (Fee Voucher Verification)
- **Signature:** `verify_discount(voucher) -> void`
- **Access:** Public
- **Flow:** Reconstructs 96-byte payload `(app_id, sender, expiry, discount)` and validates 64-byte Ed25519 signature against `self.voucher_signer`.

### 1.5 `pool_budget` (Opcode Pooling / Signer Target)
- **Signature:** `pool_budget() -> void`
- **Access:** Public (Stateless no-op extending opcode budget by 700 units and hosting quote signer note).

### 1.6 Administrative Setters
- `set_admin(new_admin)`: Bounded to `Txn.sender == self.admin`; rejects zero address.
- `set_fee(fee_bps)`: Bounded to `Txn.sender == self.admin`; enforces `fee_bps <= MAX_FEE_BPS` (100 bps).
- `set_escrow(new_escrow)`: Bounded to `Txn.sender == self.admin`; rejects zero address; verifies escrow can hold ASASTATS.
- `set_quote_signer(new_signer)`: Bounded to `Txn.sender == self.admin`; rejects zero address.
- `set_voucher_signer(new_signer)`: Bounded to `Txn.sender == self.admin`.
- `set_conversion_pool(leg)`: Bounded to `Txn.sender == self.admin`; stores approved Leg struct in global state.

### 1.7 `convert_and_distribute` (Treasury Revenue Conversion)
- **Signature:** `convert_and_distribute(batch, minimum_out) -> void`
- **Access:** Admin Only (`assert Txn.sender == self.admin`)
- **Flow:**
  1. `_assert_group_is_clean()`.
  2. `_assert_no_conversion_pool_approval()`: Rejects if `set_conversion_pool` was called in same group.
  3. Validates `batch <= self.accrued`.
  4. Validates `batch >= MIN_CONVERSION_BATCH or batch == self.accrued`.
  5. Validates `minimum_out > 0 or (batch == self.accrued and batch < MIN_CONVERSION_BATCH)`.
  6. Reads `self.conversion_pool` and executes swap via `_swap_leg`.
  7. Sends conversion proceeds strictly to `self.platform_escrow`.

### 1.8 `delete_application` (Contract Retirement)
- **Signature:** `@arc4.baremethod(allow_actions=["DeleteApplication"])`
- **Access:** Admin Only
- **Flow:** `_assert_group_is_clean()`; asserts `Txn.sender == self.admin`, `self.accrued == 0`, and zero open asset holdings; returns remaining ALGO to admin.
