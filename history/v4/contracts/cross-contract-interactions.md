# Cross-Contract Interactions — v4 Smart Router

This file documents how the router interacts with external pool contracts, the trust relationships involved, and the security boundaries.

## Call graph

```
                            [ End User / Frontend ]
                                     │
                                     │ (signed group: funding + route + quote-auth + verify_discount + pool_budget)
                                     ▼
                          ┌──────────────────────────┐
                          │   Router Smart Contract  │
                          │   (router_app.py)        │
                          └──────────┬───────────────┘
                                     │
        ┌─────────────────┬──────────┼──────────┬─────────────────┐
        ▼                 ▼          ▼          ▼                 ▼
   ┌─────────┐     ┌─────────┐  ┌─────────┐  ┌─────────┐     ┌─────────┐
   │Tinyman  │     │  Pact   │  │  STAMM  │  │ AlgoFi  │     │ Backend │
   │   v2    │     │CP+SS+MWPT│ │         │  │         │     │ Quote   │
   │         │     │         │  │         │  │         │     │ Signer  │
   │ LogicSig│     │Creator  │  │Creator  │  │Whitelist│     │(off-chain)│
   │ derived │     │ pinned  │  │ pinned  │  │ (23)    │     │         │
   └─────────┘     └────┬────┘  └────┬────┘  └────┬────┘     └─────────┘
                        │            │            │
                        ▼            ▼            ▼
                  ┌──────────┐ ┌──────────┐  ┌──────────┐
                  │MWPT Vault│ │STAMM opup│  │AlgoFi    │
                  │ (box ref)│ │  (app)   │  │ Manager  │
                  └──────────┘ └──────────┘  └──────────┘
```

## Trust relationships

| Caller | Callee | Authentication | Access control | Purpose |
|--------|--------|----------------|----------------|---------|
| User | Router | Ed25519 (outer txn signer) | `Txn.sender == caller` | Submit a route |
| Router | Tinyman v2 pool | `sha512_256(template + assets + fee)` | LogicSig hash matches expected derivation | Deposit + swap |
| Router | Pact CP/SS pool | `AppParamsGet.app_creator ∈ PACT_POOL_CREATORS` | Creator pinned | Deposit + swap |
| Router | Pact MWPT pool | Same creator pin (factory address) | **New in v4** | Deposit + swap (new selector) |
| Router | MWPT vault | `foreign_apps` reference (trusted off-chain discovery) | **Implicit (L2 finding)** | Box reads for reserve data |
| Router | STAMM pool | `AppParamsGet.app_creator ∈ STAMM_POOL_CREATORS` | Creator pinned | Deposit + swap |
| Router | STAMM opup | Trusted app ID (from leg's `apps` field) | n/a | No-op budget provisioning |
| Router | AlgoFi pool | `leg.app ∈ ALGOFI_POOLS` | Whitelist | Deposit + swap |
| Router | AlgoFi manager | Trusted app ID (from leg's `hub` field) | n/a | AlgoFi reserve lookup |
| Backend (quote signer) | Router | Ed25519 signature in transaction note | `_signed_floor` verifies | Sign slippage floor |
| Backend (voucher signer) | Router | Ed25519 signature in transaction note | `verify_discount` verifies | Sign fee discount voucher |
| Admin | Router | `Txn.sender == admin` | Direct | Configure state |

## Security boundaries

The router maintains five distinct security boundaries, each with its own defence:

### 1. Caller input and output
- **Defence:** `_assert_group_is_clean` (no rekey/close), `_signed_floor` (signed floor), `_held(asset_out) - before` (balance delta measurement).
- **Threat:** compromised frontend, malicious user.
- **Outcome:** user funds are protected; payout to `Txn.sender` only.

### 2. External pools
- **Defence:** Pool creator pin (Pact, STAMM), whitelist (AlgoFi), LogicSig hash derivation (Tinyman v2).
- **Threat:** malicious pool deployment, factory migration.
- **Outcome:** the router calls only authenticated pools; pool creator migration is a documented residual risk (DISCLAIMER.md §5.4).

### 3. Operational float
- **Defence:** dynamic opt-in borrowing, immediate close-on-success, no permanent holdings.
- **Threat:** MBR drainage via controlled opt-ins.
- **Outcome:** the router's ALGO float is bounded and recoverable.

### 4. Platform treasury
- **Defence:** admin-only fee conversion, pre-approved pool, hard economic ceilings (`MAX_FEE_BPS = 100`).
- **Threat:** admin compromise.
- **Outcome:** bounded to 1% of routed volume; conversion pool must be pre-approved.

### 5. Quote authentication
- **Defence:** Ed25519 signature with bound (app, caller, output, per-index inputs, asserting index).
- **Threat:** quote signer compromise.
- **Outcome:** slippage protection is bounded to whatever the signer is willing to sign; admin rotation is the mitigation.

## Critical security boundaries

These are the boundaries where a breach would be most damaging:

1. **External pool authenticity.** A malicious pool that authenticates via the creator pin would inherit all properties of a legitimate pool. The factory creator is the trust anchor; if the factory itself is compromised, all pools it deploys are compromised. **Mitigation:** monitor creator address activity; the v4 audit documents the residual risk in DISCLAIMER.md §5.4.

2. **Quote signer integrity.** A compromised quote signer can sign floors that are unfavourable to users. The mitigation is admin rotation; the residual risk is that a single compromise between rotations can extract value.

3. **Admin integrity.** A compromised admin can redirect fees (within `MAX_FEE_BPS`) and set a malicious conversion pool. The mitigation is hardware custody / multisig; the residual risk is bounded by the 1% fee ceiling.

## Emergency capabilities

The router has the following emergency capabilities, each gated by `Txn.sender == admin`:

1. `set_quote_signer(new_signer)` — rotate the floor signer.
2. `set_voucher_signer(NO_VOUCHER_SIGNER)` — disable fee discounts.
3. `set_conversion_pool(safe_pool)` — switch to a different conversion pool.
4. `convert_and_distribute(...)` — sweep accrued fees.
5. `close_holding(asset)` — close an asset holding.
6. `delete_application()` — retire the contract (requires `total_assets == 0` and `accrued == 0`).

For MWPT-specific emergencies, no on-chain action exists; the pool creator is hardcoded, so a malicious MWPT pool would require a router redeploy with an updated creator pin.

## Timelock summary

| Operation | Timelock |
|-----------|----------|
| `set_admin`, `set_escrow`, `set_fee` | None (admin-only) |
| `set_quote_signer`, `set_voucher_signer` | None (admin-only) |
| `set_conversion_pool` | None (admin-only) |
| `convert_and_distribute` | None (admin-only) |
| `delete_application` | None (admin-only, but asserts empty state) |
| `update_application` | Blocked (no path) |

The router has no timelock — all admin actions take effect immediately. This is a documented operational risk; the v4 SECURITY.md §2 recommends hardware/multisig custody rather than on-chain timelock.

## Cross-references

- [`state-keys.md`](state-keys.md) — global state keys inventory
- [`../SECURITY.md`](../SECURITY.md) — threat model
- [`../DISCLAIMER.md`](../DISCLAIMER.md) — residual risks
- [`../attack-vectors/pact/mwpt.md`](../attack-vectors/pact/mwpt.md) — 27 MWPT-specific vectors
