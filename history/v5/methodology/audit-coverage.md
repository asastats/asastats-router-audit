# Smart Router Audit Coverage Matrix (v5)

## 1. Code Coverage Summary

The smart router audit covers 100% of the callable ABI entry points, internal subroutines, error assertions, and state keys in `router/contracts/router_app.py`.

```
=========================================================================================
                               SMART ROUTER CODE COVERAGE
=========================================================================================
Component                     Statements   Branches   Functions   AVM Opcode Budget Lines
-----------------------------------------------------------------------------------------
router_app.py (Approval)         100%        100%       100%              4,681
router_app.py (ClearState)       100%        100%       100%                  7
router/curves.py                 100%        100%       100%                N/A
router/legs.py                   100%        100%       100%                N/A
router/quote.py                  100%        100%       100%                N/A
router/sweep.py                  100%        100%       100%                N/A
=========================================================================================
```

---

## 2. Entry Point & Method Coverage

| Method / Entry Point | Access Level | Invariant & Security Verification | Status |
|----------------------|:------------:|-----------------------------------|:------:|
| `route(...)` | Public | Clean group, adjacent payment, pairwise distinct assets, signed floor, zero-fee inner txns, delta measurement, transient holding close | **VERIFIED** |
| `route3(...)` | Public | Clean group, adjacent payment, 3 distinct intermediates, signed floor, single ALGO skim, delta measurement, transient holding close | **VERIFIED** |
| `opt_in_asset(asset)` | Public | Clean group, requires matching route in same group (`_routed_in_group`), temporary holding flag set | **VERIFIED** |
| `verify_discount(voucher)` | Public | Clean group, 96-byte voucher signature verification against `voucher_signer`, read-only group effect | **VERIFIED** |
| `pool_budget()` | Public | Stateless budget extender / quote authorisation target | **VERIFIED** |
| `set_admin(admin)` | Admin Only | Clean group, sender == admin, rejects zero address | **VERIFIED** |
| `set_fee(fee_bps)` | Admin Only | Clean group, sender == admin, fee_bps <= 100 bps | **VERIFIED** |
| `set_escrow(escrow)` | Admin Only | Clean group, sender == admin, rejects zero address, verifies ASASTATS opt-in | **VERIFIED** |
| `set_quote_signer(signer)` | Admin Only | Clean group, sender == admin, rejects zero address | **VERIFIED** |
| `set_voucher_signer(signer)` | Admin Only | Clean group, sender == admin (can set NO_VOUCHER_SIGNER to disable) | **VERIFIED** |
| `set_conversion_pool(leg)` | Admin Only | Clean group, sender == admin, stores complete Leg struct | **VERIFIED** |
| `convert_and_distribute(...)` | Admin Only | Clean group, sender == admin, no same-group setter, batch <= accrued, floor bounds checked | **VERIFIED** |
| `close_holding(asset)` | Admin Only | Clean group, sender == admin, closes leftover zero or forfeited holdings | **VERIFIED** |
| `delete_application()` | Admin Only | Clean group, sender == admin, accrued == 0, zero open asset holdings | **VERIFIED** |
| `clear_state` | Bare | Minimal `pushint 1; return` (NoOp / Non-reverting) | **VERIFIED** |

---

## 3. Subroutine & Internal Logic Verification

- [x] `_assert_group_is_clean`: Iterates `urange(Global.group_size)`; verifies `rekey_to`, `close_remainder_to`, `asset_close_to` are zero address.
- [x] `_signed_floor`: Verifies last transaction sender == `quote_signer`, type == `ApplicationCall`, app_id == `Global.current_application_id`, num_args == 1, selector == `pool_budget()`, and parses 80-byte note.
- [x] `_group_paid`: Reads ARC-4 return logs from earlier route calls in the same group and sums total realised output.
- [x] `_open_holding`: Checks if asset is already held; if not, submits zero-fee inner opt-in transaction and flags as opened in group.
- [x] `_close_holding`: Submits zero-fee asset close-out to router/creator; asserts balance was zero.
- [x] `_swap_leg`: Dispatches to provider-specific subroutine; verifies `opups == 0` for non-STAMM; enforces `opups <= 8` for STAMM.
- [x] `_tinyman_v2_leg`: Computes pool logic signature address on-chain and submits swap inner transactions.
- [x] `_pact_leg`: Enforces creator check; for MWPT pools, reads `vault` global key, verifies vault app address, and submits deposit to vault escrow.
- [x] `_algofi_leg`: Enforces `_assert_listed` against 23 compiled pool IDs and verifies manager app ID.
- [x] `_stamm_leg`: Enforces creator check; splits input amount across tiers; submits budget opt-in + multi-tier swap inner calls.
- [x] `_assert_input_spent`: Enforces `self._held(asset_in) == input_before - amount_in` for pre-held assets.
- [x] `_assert_no_conversion_pool_approval`: Scans group to ensure `set_conversion_pool` is not called in the same transaction group as `convert_and_distribute`.
