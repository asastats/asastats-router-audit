# Router Application Deep-Dive

## Overview

The `Router` contract is a Puya / Algorand Python ARC-4 application. It exists to execute multi-hop routes where the second (or third) hop's input depends on the previous hop's realised output.

## Global State

| Key | Type | Purpose |
|-----|------|---------|
| `admin` | Account | Can set fee, escrow, voucher signer, close holdings, delete app |
| `platform_escrow` | Account | Receives converted ASASTATS fees |
| `fee_bps` | UInt64 | Platform fee in basis points, capped at 100 |
| `accrued` | UInt64 | ALGO fees collected and awaiting conversion |
| `voucher_signer` | Bytes (32) | ed25519 public key whose signatures grant fee discounts |

## Public Methods

### `route` / `route3`

- Receive caller's input via a referenced payment/asset-transfer.
- Open opt-ins for intermediate and output assets.
- Execute one or two fixed-input legs.
- Skim fee if an intermediate is ALGO.
- Assert global `minimum_received` across the group.
- Pay caller and close opened holdings.

**Trust assumptions:**
- `payment` comes from `Txn.sender` and is addressed to the router.
- `Leg` structs describe legitimate pools (Pact/STAMM/AlgoFi app IDs are not verified).
- `minimum_received` is honest (residual T5 risk).

**Recent changes:**
- Path sanitisation (no duplicate assets).

### `opt_in_asset`

- Opens an ASA holding for the router.
- Only allowed if a matching `route`/`route3` is in the same group.
- Prevents MBR-draining griefing.

### `verify_discount` / `pool_budget`

- `verify_discount` checks an ed25519 signature over a domain, app ID, sender, expiry, and discount.
- `pool_budget` is a no-op outer call that adds opcode budget to the group.
- Both are permissionless and stateless.

### Admin methods

- `set_admin`, `set_escrow`, `set_fee`, `set_voucher_signer`: admin-only, with group-hygiene check.
- `close_holding`: admin closes an empty holding.
- `delete_application`: admin retires app and recovers ALGO; blocked while fees are accrued.
- `convert_and_distribute`: **now admin-only** to prevent fee drainage.

## Key Subroutines

### `_assert_group_is_clean`

Scans every transaction in the group and rejects any with `rekey_to`, `close_remainder_to`, or `asset_close_to` set. Protects the caller, not the contract.

### `_swap_leg`

Dispatches to provider-specific leg builders and measures output by the router's own balance delta.

### `_input_amount`

Validates that the referenced payment/asset transfer comes from `Txn.sender` and is addressed to the router.

### `_pay_out`

Sends output to `Txn.sender` and closes the holding if it was opened for this route.

### `_skim`

Takes the platform fee from an ALGO-denominated amount and adds it to `accrued`.

## Template Variables

| Variable | Purpose |
|----------|---------|
| `TINYMAN_V2_APP_ID` | Validator used to derive Tinyman v2 pool addresses |
| `STAMM_BUDGET_APP_ID` | Budget application for STAMM / extra opcode budget |
| `STAMM_OPUP_APP_ID` | No-op application spawned by the budget app |
| `STAMM_OPUP_COUNT` | Default no-op count compiled into the deployment |
| `FEE_ASSET_ID` | Asset fees are converted into (ASASTATS on mainnet) |
| `MIN_CONVERSION_BATCH` | Economic floor for fee conversion |
| `RESTRICT_TO_ADMIN` | Compile-time flag restricting `route`/`route3` to admin |

## Open Design Questions

1. Should the signed-floor mechanism (H1) reuse the voucher signer or a separate quote signer?
2. Should approved conversion pools be whitelisted if permissionless conversion is desired later?
3. Should Pact/STAMM/AlgoFi pools be authenticated via a registry or a simple admin whitelist?
