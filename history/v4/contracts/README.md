# Contracts — v4 Smart Router

This directory contains per-component analysis for the v4 router audit.

## Files

- [`state-keys.md`](state-keys.md) — Global state keys inventory for the router.
- [`cross-contract-interactions.md`](cross-contract-interactions.md) — Router ↔ external pool call graph and trust relationships.

## Components

The v4 audit covers a single smart contract (`router/contracts/router_app.py`) that interacts with multiple external pool contracts. The "components" in this context are:

| Component | Role | File |
|-----------|------|------|
| Router | Cross-pool aggregator | `router/contracts/router_app.py` |
| Tinyman v2 pool | External AMM (LogicSig) | (out of scope; referenced via hash) |
| Pact constant-product pool | External AMM (Application) | (out of scope; referenced via creator) |
| Pact stableswap pool | External AMM (Application) | (out of scope; referenced via creator) |
| Pact MWPT pool | External AMM (Application) | (out of scope; referenced via creator) |
| Pact MWPT vault | Reference storage for MWPT pool | (out of scope; referenced via app ID) |
| STAMM pool | External AMM (Application) | (out of scope; referenced via creator) |
| STAMM opup | STAMM's no-op ApplicationCall | (out of scope; referenced via app ID) |
| AlgoFi pool | External AMM (Application) | (out of scope; referenced via whitelist) |
| AlgoFi manager | AlgoFi's reference application | (out of scope; referenced via `leg.hub`) |
| Quote signer | Backend Ed25519 key (off-chain) | (out of scope) |
| Voucher signer | Backend Ed25519 key (off-chain) | (out of scope) |
| Platform escrow | ALGO address (set by admin) | (out of scope) |
| Conversion pool | Pre-approved AMM pool (admin-only) | (out of scope; admin-set) |

The two state-keys / cross-contract-interactions files focus on the router's own state and its interactions with the external pools.
