# Smart Router Improvements Applied

This file tracks the contract-level changes made as a result of the audit.

## Changes in `router/contracts/router_app.py`

1. **`convert_and_distribute` is now admin-only.**
   - Added `assert Txn.sender == self.admin, "only the admin may convert"`.
   - This closes the critical fee-drainage vector described in `findings/C1-convert-and-distribute-pool-drain.md`.

2. **Route path sanitisation.**
   - `route` now asserts `asset_in != asset_out`, `middle != asset_in`, and `middle != asset_out`.
   - `route3` asserts the same pairwise distinctness for `asset_in`, `first_middle`, `second_middle`, and `asset_out`.
   - Prevents cycles like A → B → A and duplicate-asset paths.

3. **Non-STAMM `opups` are rejected.**
   - Added an assertion that `leg.opups == 0` unless the provider is STAMM.
   - Prevents callers from inflating transaction counts and resource usage for Tinyman/Pact/AlgoFi legs.

4. **Zero-address checks for admin and escrow.**
   - `set_admin` rejects the zero address.
   - `set_escrow` rejects the zero address.

## Changes in `router/tests/test_router_contract.py`

- Added `test_reassigning_administration_rejects_zero`.
- Added `test_the_escrow_cannot_be_set_to_zero`.
- Added `test_a_non_admin_cannot_convert`.

## Changes in `router/SECURITY.md`

- Updated the trust-boundary table to reflect that `convert_and_distribute` is now admin-only.
- Updated the accrued-fees paragraph to note the admin-only change and its rationale.
- Added an accepted risk noting that pool app IDs are still not authenticated.

## Verification

- `pytest tests/test_router_contract.py` — 33 passed.
- `pytest -m 'not mainnet and not testnet and not localnet'` — 489 passed.
- `puyapy contracts/router_app.py --out-dir /tmp/router_compile` — compiles successfully with Puya 5.9.0.

## Proposed improvements not yet implemented

These require ABI changes or additional design work:

1. **Backend-signed floor** (`findings/H1-widget-floor-zero.md`) — the strongest fix for the residual T5 risk.
2. **Deadline parameter** (`findings/M2-no-deadline.md`) — add `deadline_round` to `route`/`route3`.
3. **Approved-pool whitelist** (`findings/M3-unauthenticated-pool-ids.md`) — authenticate Pact/STAMM/AlgoFi app IDs.
4. **Explicit holdings check on deletion** (`findings/L1-delete-holdings-check.md`).
