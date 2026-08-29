# Glossary — v4 Smart Router

Definitions for protocol-specific terms used in the v4 audit. Inherited from STAMM AMM Audit glossary and v3 router audit glossary, with new terms added for the Pact MWPT integration.

---

## A

**ABI (Application Binary Interface)** — Algorand's standard for encoding arguments and return values of smart contract methods. See [ARC-0004](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0004.md).

**ALGO** — Native Algorand token; asset ID 0 in AVM. The router handles ALGO specially (via `itxn.Payment` rather than `itxn.AssetTransfer`).

**AlgoFi** — Algorand AMM protocol. Defunct since 2024; the router routes through 23 curated pools in `ALGOFI_POOLS`.

**ARC-4** — Algorand standard for application binary interface; defines method selectors, argument encoding, and return value encoding.

**ARC-32** — Standard for application specification (formerly ARC-4 spec); describes the contract's ABI in JSON.

**ARC-56** — Extended application specification that includes ARC-32 + box storage, inner transaction references, etc.

**ASA (Algorand Standard Asset)** — A fungible or non-fungible token on Algorand.

**AssetCloseTo** — Field on an ASA transfer transaction that, if set to a non-zero address, closes the sender's ASA holding and sends the remainder to the specified address. The router never uses this field on inner transactions.

**AVM (Algorand Virtual Machine)** — The execution environment for Algorand smart contracts. TEAL is the bytecode.

---

## B

**Balance delta** — The router's primary input/output measurement technique: `_held(asset_out) - before`, where `_held` reads the router's on-chain balance after the inner transaction. The router never trusts a pool's reported output.

**Backend-signed floor** — A slippage floor signed by the backend quote server. Embedded in the transaction note of the last group transaction; bound to (app_id, caller, output_asset, per-index input amounts, asserting_index).

**BigInteger (128-bit)** — The STAMM pool uses 128-bit internal arithmetic (`mulw`, `divmodw`) to avoid overflow. The MWPT pool uses similar arithmetic.

**Box storage** — Algorand's per-application key-value storage. The router uses no direct box storage; pools read their own boxes.

**Box reference** — A pair (app_id, key) that an inner transaction can read/write. The MWPT pool uses box reads against its vault app.

---

## C

**CloseRemainderTo** — Field on an ALGO payment transaction that, if set to a non-zero address, closes the sender's account and sends the remainder to the specified address. The router never uses this field on inner transactions.

**Constant-product AMM** — Traditional `x * y = k` AMM (e.g., Tinyman v2, Pact CP, STAMM tiers, AlgoFi).

**Conversion pool** — A pre-approved AMM pool used by `convert_and_distribute` to swap accrued ALGO fees into ASASTATS.

---

## D

**Delta (Δ)** — See "balance delta".

**Discount (voucher)** — A signed 80-byte message that authorises a fee discount for the message's signer. Verified once per group via `verify_discount`.

**`_signed_floor`** — The router's on-chain verification of the backend-signed floor. Reads the last transaction in the group as an ApplicationCall with a specific note format.

---

## E

**Ed25519** — Signature algorithm used by Algorand. The quote signer and voucher signer both use Ed25519 keys.

---

## F

**Fee pool** — Algorand's mechanism for a single transaction to cover the fees of all transactions in a group. The router uses this so the outer route call covers all inner transaction fees (which are `0` anyway).

**Floor mechanism** — The router's slippage protection. The contract asserts `actual_output >= _signed_floor`.

**Foreign apps / assets** — Arrays on an ApplicationCall that reference apps and assets outside the current application. The router references external pool apps in its inner transactions' `foreign_apps` array.

---

## G

**GroupSize** — Total number of transactions in the current atomic group. Capped at 16.

**GroupIndex** — The index of the current transaction within the group (0-based).

---

## H

**Hook application (STAMM-specific)** — An optional application that STAMM pools call after each operation. Not relevant to the router audit (the router doesn't interact with the hook).

---

## I

**Inner transaction** — A transaction issued by a smart contract via `itxn.*`. The router issues inner transactions to deposit assets and call external pools.

**Inverse curve** — A curve that computes how much input is needed to produce a given output. Used by the router's quote logic to handle exact-output swaps.

**`itob`** — AVM opcode that converts a uint64 to 8-byte big-endian bytes. Used for encoding amounts in inner transaction arguments.

---

## L

**Last transaction** — The transaction at `Global.group_size - 1` in the current group. The router's `_signed_floor` reads this transaction's note.

**Leg** — A single hop in a multi-hop route. Each leg has an app ID, asset_a, asset_b, provider, hub, opups, and routed fields.

**LogicSig** — A signature-based account that can submit transactions on behalf of a contract. Tinyman v2 pools use LogicSig accounts.

---

## M

**MBR (Minimum Balance Requirement)** — The minimum ALGO balance an account must hold to maintain its on-chain state (assets, apps, boxes). Each ASA opt-in costs 0.1 ALGO.

**MWPT (Managed Weighted Pool)** — Pact's weighted-pool AMM with separate vault reference and manager fee. New in v4.

**MWPT factory creator** — The address `H2XDAFUDTEPTN24HNUAZI6RCKQ2KDIIO45U767FEHGSGSEGCWWOK4QEIXM` that deploys all MWPT pools. Pinned in `_pact_leg`'s selector branch.

**MWPT_SWAP** — The MWPT pool's swap method selector: `0x035942b0`.

**MWPT vault** — A separate application that MWPT pools read reserves from via `app_global_get_ex`. Referenced via the `foreign_apps` array and box reads.

---

## N

**Newton-Raphson** — Iterative method for finding roots. Used by STAMM for 128-bit square root. The off-chain MWPT curve can also use it for the `ratio ** exponent` computation.

---

## O

**Opcode budget** — The maximum number of opcodes a single transaction can execute (700 by default). Multi-hop routes may need extra budget via `pool_budget` calls.

**Opup (STAMM-specific)** — A no-op ApplicationCall that consumes opcode budget. STAMM pools require multiple opups to execute their internal logic.

**Outer transaction** — A transaction submitted by a user; the router's `route`/`route3` methods are outer transactions.

---

## P

**PACT_POOL_CREATORS** — Template variable containing the concatenated addresses of all trusted Pact pool creators. Multi-entry since v3's M3 fix; MWPT factory appended in v4.

**PACT_SWAP** — The Pact pool's swap method selector: `0x6e6f0073` (legacy) or similar.

**Pool address** — The address derived from a pool's parameters. For Tinyman v2, derived from the template LogicSig + assets; for Pact/STAMM/AlgoFi, equal to the pool's app address.

**Pool budget** — A no-op ApplicationCall (`pool_budget` method) that the caller adds to the group to provision extra opcode budget for multi-hop routes.

**Pool creator** — The address that deployed a pool's app. Pinned for Pact and STAMM via `_assert_created_by`; whitelisted for AlgoFi via `_assert_listed`.

**Property-based testing** — Testing strategy where properties (invariants) are defined and inputs are randomly generated to try to violate them. The router uses Hypothesis for this.

---

## Q

**Quote** — An off-chain computation of the expected output for a given input and route. The quote server signs the floor based on this computation.

**Quote signer** — The Ed25519 key that signs floors. Stored on the backend; can be rotated via `set_quote_signer`.

---

## R

**RekeyTo** — Field on a transaction that, if set to a non-zero address, transfers signing authority to that address. The router never uses this field on inner transactions and rejects outer transactions with non-zero RekeyTo.

**RESTRICT_TO_ADMIN** — Template variable that, when `1`, restricts `route` and `route3` to the admin only. Currently `0` on mainnet. Recommended for removal (I1).

**Route** — A multi-hop swap path. Either `route` (2 legs) or `route3` (3 legs).

**Route_fee** — The total fee for the route, computed off-chain by `router.contract.route_fee`. Pooled on the outer route call.

---

## S

**Selector (method)** — The first 4 bytes of `SHA512/256("method_name(arg_types)return_type")`. The router's `_pact_leg` branches between `PACT_SWAP` and `PACT_MWPT_SWAP` based on the pool's creator.

**STAMM** — LiquiHog's stratified constant-product AMM. Audited separately at `<audit>/STAMM-AI-AUDIT-main/`.

**Stableswap** — An AMM designed for pegged assets with a high amplification factor (e.g., Curve). Pact supports stableswap pools.

**Subroutine** — A reusable code block within a smart contract (Algorand Python `@subroutine`).

**SWAP selector** — The selector for the pool's swap method. Different for each pool type:
- Tinyman v2: LogicSig (no selector)
- Pact CP/MWPT: `0x6e6f0073` / `0x035942b0`
- STAMM: `0xbuild_swap_routed` selector (varies)
- AlgoFi: `0x` (sef selector)

---

## T

**Template variable** — A value set at compile time, embedded in the TEAL. Examples: `PACT_POOL_CREATORS`, `STAMM_POOL_CREATORS`, `ALGOFI_POOLS`, `RESTRICT_TO_ADMIN`.

**TEAL** — Algorand's smart-contract bytecode. The compiled form of Puya/Algorand Python.

**Tinyman v2** — Tinyman's AMM v2, using LogicSig accounts. The router derives pool addresses on-chain.

---

## V

**Vault app (MWPT-specific)** — The separate application that MWPT pools read reserves from. Not the pool itself.

**Voucher signer** — The Ed25519 key that signs fee discount vouchers. Can be rotated or disabled via `set_voucher_signer`.

---

## W

**Weighted pool (MWPT-specific)** — An AMM where each asset has a weight (in basis points, summing to 10000). The swap formula is `reserve_out * (1 - (reserve_in / (reserve_in + effective_in))^(weight_in / weight_out))`.

---

## Numbers

**700** — Default opcode budget per Algorand transaction.
**16** — Maximum transactions per Algorand group.
**100** — `MAX_FEE_BPS`, the maximum platform fee the admin can set.
**10000** — `BASIS_POINTS`, the scaling factor for fee calculations.
**500,000,000** — `MAX_CONVERSION_BATCH`, the maximum microALGO that `convert_and_distribute` can convert per call.
