# Router State Keys (v4)

This file inventories the global state keys used by the router. Each key is documented with its type, write/read sites, and purpose.

## Global state keys

| Key | Type | Written by | Read by | Purpose | MWPT impact |
|-----|------|------------|---------|---------|-------------|
| `admin` | `Address` | `set_admin` | all admin methods, `RESTRICT_TO_ADMIN` checks | Administrator's account | None |
| `escrow` | `Address` | `set_escrow` | `convert_and_distribute` (payout target) | Platform escrow address | None |
| `fee_bps` | `UInt64` | `set_fee` | `_skim` | Platform fee in basis points | None |
| `conversion_pool` | `Application` | `set_conversion_pool` | `convert_and_distribute` | Pre-approved AMM pool for fee conversion | None |
| `quote_signer` | `Address` | `set_quote_signer` | `_signed_floor` | Ed25519 public key for floor signatures | None |
| `voucher_signer` | `Address` | `set_voucher_signer` | `verify_discount` | Ed25519 public key for fee discount vouchers | None |
| `accrued` | `UInt64` | `_skim`, `convert_and_distribute` | `convert_and_distribute`, `delete_application` | Accumulated platform fees in microALGO | None |
| `total_assets` | `UInt64` | `_open_holding`, `_pay_out` | `delete_application` | Number of ASA holdings the router maintains | None |
| `total_extra_app_pages` | `UInt64` | (deployment) | n/a | Number of extra app pages (deployment-time) | None |
| `_routed_in_group` | `UInt64` | `route`, `route3` (entry) | `route`, `route3` (exit asserts = 0) | Tracks whether a route has already executed in this group | None |
| `_opened_in_group` | `UInt64` | `route`, `route3` (opt-in) | `route`, `route3` (exit asserts = 0) | Tracks whether an opt-in has occurred in this group | None |
| `_max_opup` | `UInt64` | (deployment) | `_swap_leg` | Maximum STAMM opup count | None |
| `_legacy_pool_creator` (deprecated) | `Address` | n/a | n/a | Retained for ABI compatibility; not used | None |

### Template variables (compile-time, not stored in global state)

| Template variable | Type | Purpose | MWPT impact |
|-------------------|------|---------|-------------|
| `PACT_POOL_CREATORS` | `Bytes` | Concatenation of trusted Pact pool creator addresses | **MWPT factory appended in v4** |
| `STAMM_POOL_CREATORS` | `Bytes` | Concatenation of trusted STAMM pool creator addresses | None |
| `ALGOFI_POOLS` | `Bytes` | Concatenation of 23 trusted AlgoFi pool app IDs | None (list widened in v4; see I2) |
| `RESTRICT_TO_ADMIN` | `UInt64` | 0 = unrestricted, 1 = admin-only | None (recommended removal in I1) |
| `MAX_FEE_BPS` | `UInt64` | Maximum platform fee (100) | None |
| `MAX_DISCOUNT` | `UInt64` | Maximum voucher discount | None |
| `MAX_CONVERSION_BATCH` | `UInt64` | Maximum microALGO per conversion (500M) | None |
| `MIN_CONVERSION_BATCH` | `UInt64` | Minimum microALGO to trigger conversion (10K) | None |
| `MAX_STAMM_OPUPS` | `UInt64` | Maximum STAMM opups per leg (8) | None |
| `MAX_HOPS` | `UInt64` | Maximum hops in a single route (3) | None |
| `NO_VOUCHER_SIGNER` | `Address` | Zero address (used to disable voucher discount) | None |
| `POOL_BUDGET_SIGNATURE` | `Bytes` | Method signature for `pool_budget` no-op call | None |
| `MWPT_FACTORY_CREATOR` | `Address` | MWPT factory creator address (hardcoded in `_pact_leg` selector branch) | **New in v4** |

## State invariants

The router maintains the following invariants on its global state:

1. `admin != Global.zero_address` after first admin is set.
2. `escrow != Global.zero_address` after first escrow is set.
3. `fee_bps <= MAX_FEE_BPS = 100`.
4. `conversion_pool != 0` after first conversion pool is set.
5. `quote_signer != Global.zero_address` (cannot be set to zero, enforced by `set_quote_signer`).
6. `voucher_signer` is either a valid address or `NO_VOUCHER_SIGNER` (zero).
7. `accrued <= MAX_CONVERSION_BATCH` after `convert_and_distribute` (within the loop invariant).
8. `total_assets == 0` requires `accrued == 0` for `delete_application`.

## State keys summary

- **Total global state keys:** 12 (excluding deprecated)
- **Total template variables:** 13 (excluding constants like `MAX_FEE_BPS`)
- **Total box storage:** 0
- **Local state:** 0 (the router does not use local state)

The MWPT integration does not introduce any new global state keys or template variables (the factory creator is hardcoded in the contract rather than as a template variable). The factory address `MWPT_FACTORY_CREATOR = H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM` is encoded in the TEAL.

## Cross-references

- [`cross-contract-interactions.md`](cross-contract-interactions.md) — call graph for the keys above
- [`../methodology/glossary.md`](../methodology/glossary.md) — definitions of each key type
- [`../findings/I1-restrict-to-admin-still-in-source.md`](../findings/I1-restrict-to-admin-still-in-source.md) — I1 finding on `RESTRICT_TO_ADMIN`
- [`../findings/I2-algofi-list-widening-policy.md`](../findings/I2-algofi-list-widening-policy.md) — I2 finding on `ALGOFI_POOLS`
